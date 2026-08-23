#!/bin/bash
# ==============================================================================
# install-devapp.sh
# Builds and deploys the DevApp application (user-app, order-app, devapp-web)
# into the 'devapp' K8s namespace.
#
# Prerequisites: Infrastructure must already be installed.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
DEPLOY_DIR="$SCRIPT_DIR/deployments"
AUTO_APPROVE=false
VERSION="latest"
SERVER_IP="${SERVER_IP:-51.68.232.240}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes|--auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --version)
            [[ $# -lt 2 ]] && { echo "Missing value for --version"; exit 1; }
            VERSION="$2"
            shift 2
            ;;
        --version=*)
            VERSION="${1#*=}"
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: $0 [--yes] [--version <tag>] [tag]"
            exit 1
            ;;
        *)
            VERSION="$1"
            shift
            ;;
    esac
done

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()  { echo -e "${BLUE}[STEP]${NC}  $*"; }

ask() {
    local prompt="$1"
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        info "Auto-approve enabled: $prompt"
        return 0
    fi
    read -rp "$(echo -e "${YELLOW}$prompt [y/N]${NC} ")" answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ---------- Pre-flight checks ------------------------------------------------
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
export MAVEN_OPTS="-Dhttp.proxyHost= -Dhttps.proxyHost="

command -v kubectl &>/dev/null || error "kubectl not found."
command -v mvn &>/dev/null     || error "Maven not found."
command -v npm &>/dev/null     || error "npm not found."
command -v docker &>/dev/null  || error "Docker not found."
command -v openssl &>/dev/null || error "openssl not found."
kubectl cluster-info &>/dev/null || error "Cannot reach K8s cluster."

# Check infrastructure is running
INFRA_PODS=$(kubectl get pods -n infra --no-headers 2>/dev/null | grep -c Running || true)
[[ "$INFRA_PODS" -lt 5 ]] && error "Infrastructure not ready ($INFRA_PODS running pods). Deploy the bm-cluster repository first."

info "============================================="
info " DevApp Application Installer"
info "============================================="
echo ""
echo "This script will:"
echo "  1. Build Java backend (Maven)"
echo "  2. Build Angular frontend (npm)"
echo "  3. Build Docker images"
echo "  4. Import images into K3s"
echo "  5. Deploy to 'devapp' namespace"
echo ""
echo "Image tag: $VERSION"
echo ""

ask "Proceed with build and deploy?" || { info "Aborted."; exit 0; }

ensure_tls_secret() {
    local namespace="$1"
    local secret_name="$2"
    shift 2
    local domains=("$@")

    if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
        warn "TLS secret '$secret_name' already exists in namespace '$namespace', reusing it."
        return 0
    fi

    local tmpdir openssl_config cert key
    tmpdir="$(mktemp -d)"
    openssl_config="$tmpdir/openssl.cnf"
    cert="$tmpdir/tls.crt"
    key="$tmpdir/tls.key"

    {
        echo "[req]"
        echo "distinguished_name = req_distinguished_name"
        echo "x509_extensions = v3_req"
        echo "prompt = no"
        echo ""
        echo "[req_distinguished_name]"
        echo "CN = ${domains[0]}"
        echo ""
        echo "[v3_req]"
        echo "subjectAltName = @alt_names"
        echo ""
        echo "[alt_names]"
        local i=1
        for domain in "${domains[@]}"; do
            echo "DNS.$i = $domain"
            i=$((i + 1))
        done
    } > "$openssl_config"

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$key" \
        -out "$cert" \
        -config "$openssl_config" >/dev/null 2>&1

    kubectl create secret tls "$secret_name" \
        --cert="$cert" \
        --key="$key" \
        -n "$namespace" >/dev/null

    rm -rf "$tmpdir"
    info "Created TLS secret '$secret_name' in namespace '$namespace'."
}

check_dns_record() {
    local host="$1"
    local resolved
    resolved="$(getent hosts "$host" 2>/dev/null | awk '{print $1}' | head -1 || true)"
    if [[ "$resolved" != "$SERVER_IP" ]]; then
        warn "DNS check: $host -> ${resolved:-<missing>} (expected $SERVER_IP)"
    fi
}

# ---------- Build backend -----------------------------------------------------
step "Building Java applications (mvn clean package)..."
cd "$ROOT_DIR"
mvn clean package -DskipTests -q

info "Backend build complete."

# ---------- Build frontend ----------------------------------------------------
step "Building Angular application..."
cd "$ROOT_DIR/devapp-web"
npm install --silent 2>/dev/null
npm run build-prod --silent

info "Frontend build complete."
cd "$ROOT_DIR"

# ---------- Build Docker images -----------------------------------------------
step "Building Docker images (tag: $VERSION)..."

# Use sudo for docker if current user is not in docker group or socket not accessible
DOCKER_CMD="docker"
if ! docker info &>/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
    warn "Using sudo for Docker commands."
fi

$DOCKER_CMD build -t "devapp/user-app:$VERSION"  -f user-app/Dockerfile  .
$DOCKER_CMD build -t "devapp/order-app:$VERSION"  -f order-app/Dockerfile  .
$DOCKER_CMD build -t "devapp/devapp-web:$VERSION" -f devapp-web/Dockerfile devapp-web/

info "Docker images built."

# ---------- Import into K3s ---------------------------------------------------
step "Importing images into K3s containerd..."

$DOCKER_CMD save "devapp/user-app:$VERSION"  | sudo k3s ctr images import -
$DOCKER_CMD save "devapp/order-app:$VERSION"  | sudo k3s ctr images import -
$DOCKER_CMD save "devapp/devapp-web:$VERSION" | sudo k3s ctr images import -

info "Images imported into K3s."

# ---------- Deploy to K8s -----------------------------------------------------
step "Creating devapp namespace..."
kubectl create namespace devapp 2>/dev/null || true

step "Ensuring HTTPS TLS secret for app ingress..."
ensure_tls_secret devapp swirlit-dev-tls \
    devapp.swirlit.dev

step "Deploying application manifests..."

info "Setting the Kustomize image tag to: $VERSION"
"$ROOT_DIR/scripts/set-image-tags.sh" "$VERSION"

kubectl delete job devapp-kibana-bootstrap-v5 -n devapp --ignore-not-found >/dev/null

kubectl apply -k "$DEPLOY_DIR"

kubectl wait --for=condition=Ready externalsecret/devapp-db-credentials -n devapp --timeout=180s 2>/dev/null || warn "devapp-db-credentials ExternalSecret still reconciling..."

info "Waiting for application pods to start..."
kubectl wait --for=condition=ready pod -l app=user-app   -n devapp --timeout=180s 2>/dev/null || warn "user-app still starting..."
kubectl wait --for=condition=ready pod -l app=order-app  -n devapp --timeout=180s 2>/dev/null || warn "order-app still starting..."
kubectl wait --for=condition=ready pod -l app=devapp-web -n devapp --timeout=120s 2>/dev/null || warn "devapp-web still starting..."
kubectl wait --for=condition=complete job/devapp-kibana-bootstrap-v5 -n devapp --timeout=180s 2>/dev/null || warn "Kibana saved-object bootstrap is still running..."

# ---------- Smoke tests -------------------------------------------------------
step "Running smoke tests..."
FAILURES=0

check_endpoint() {
    local name="$1" url="$2" expected="$3"
    shift 3
    local code
    code=$(curl -so /dev/null -w "%{http_code}" --max-time 10 "$@" "$url" 2>/dev/null || echo "000")
    if [[ "$code" == "$expected" ]]; then
        echo -e "  ${GREEN}✓${NC} $name ($code)"
    else
        echo -e "  ${RED}✗${NC} $name (got $code, expected $expected)"
        FAILURES=$((FAILURES + 1))
    fi
}

# Port-forward to test backend health
kubectl port-forward -n devapp svc/user-app 18080:8080 &>/dev/null &
PF_PID1=$!
kubectl port-forward -n devapp svc/order-app 18081:8081 &>/dev/null &
PF_PID2=$!
sleep 3

check_endpoint "Frontend (HTTPS)"         "https://devapp.swirlit.dev" "200" --resolve devapp.swirlit.dev:443:127.0.0.1 -k
check_endpoint "User API (health)"       "http://localhost:18080/actuator/health" "200"
check_endpoint "Order API (health)"      "http://localhost:18081/actuator/health" "200"
check_endpoint "User API (auth required)" "https://devapp.swirlit.dev/api/users" "401" --resolve devapp.swirlit.dev:443:127.0.0.1 -k
check_endpoint "Swagger UI (user-app)"   "https://devapp.swirlit.dev/api/docs" "200" --resolve devapp.swirlit.dev:443:127.0.0.1 -k -L

kill $PF_PID1 $PF_PID2 2>/dev/null || true

if [[ $FAILURES -eq 0 ]]; then
    info "All smoke tests passed!"
else
    warn "$FAILURES smoke test(s) failed."
fi

# ---------- Summary -----------------------------------------------------------
info ""
info "============================================="
info " DevApp deployment complete!"
info "============================================="
echo ""
echo "Access the application:"
echo "  Frontend:        https://devapp.swirlit.dev"
echo "  User API:        https://devapp.swirlit.dev/api/users  (JWT required)"
echo "  Order API:       https://devapp.swirlit.dev/api/orders (JWT required)"
echo "  OpenAPI UI:      https://devapp.swirlit.dev/api/docs"
echo "  Metrics:         https://grafana.swirlit.dev/d/devapp-overview"
echo "  Logs:            https://kibana.swirlit.dev/app/dashboards#/view/devapp-logs"
echo "  Ingress IP:      $SERVER_IP"
echo ""
check_dns_record "devapp.swirlit.dev"
echo ""
echo "Pod status:"
kubectl get pods -n devapp --no-headers 2>&1 | awk '{printf "  %-50s %s\n", $1, $2}'
echo ""
echo "See README.md for Keycloak setup (required for authentication)."
