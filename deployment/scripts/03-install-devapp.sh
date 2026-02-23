#!/bin/bash
# ==============================================================================
# 03-install-devapp.sh
# Builds and deploys the DevApp application (user-app, order-app, devapp-web)
# into the 'devapp' K8s namespace.
#
# Prerequisites: Run 01 and 02 scripts first.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/../.."
K8S_DIR="$SCRIPT_DIR/../k8s"

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
kubectl cluster-info &>/dev/null || error "Cannot reach K8s cluster."

# Check infrastructure is running
INFRA_PODS=$(kubectl get pods -n infrastructure --no-headers 2>/dev/null | grep -c Running || true)
[[ "$INFRA_PODS" -lt 5 ]] && error "Infrastructure not ready ($INFRA_PODS running pods). Run 02-install-infrastructure.sh first."

# ---------- Configuration -----------------------------------------------------
VERSION="${1:-latest}"

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

$DOCKER_CMD build -t "devapp/user-app:$VERSION"  -f user-app/Dockerfile  user-app/
$DOCKER_CMD build -t "devapp/order-app:$VERSION"  -f order-app/Dockerfile  order-app/
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

step "Deploying application manifests..."

# Update image tags in manifests if version != latest
if [[ "$VERSION" != "latest" ]]; then
    info "Patching manifests with image tag: $VERSION"
    for f in "$K8S_DIR"/app/01-user-app.yaml "$K8S_DIR"/app/02-order-app.yaml "$K8S_DIR"/app/03-devapp-web.yaml; do
        sed -i "s|image: devapp/.*:.*|image: devapp/$(basename "$f" .yaml | sed 's/^[0-9]*-//'):"$VERSION"|" "$f" 2>/dev/null || true
    done
fi

kubectl apply -f "$K8S_DIR/app/"

info "Waiting for application pods to start..."
kubectl wait --for=condition=ready pod -l app=user-app   -n devapp --timeout=180s 2>/dev/null || warn "user-app still starting..."
kubectl wait --for=condition=ready pod -l app=order-app  -n devapp --timeout=180s 2>/dev/null || warn "order-app still starting..."
kubectl wait --for=condition=ready pod -l app=devapp-web -n devapp --timeout=120s 2>/dev/null || warn "devapp-web still starting..."

# ---------- Smoke tests -------------------------------------------------------
step "Running smoke tests..."
FAILURES=0

check_endpoint() {
    local name="$1" url="$2" expected="$3"
    local code
    code=$(curl -so /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
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

check_endpoint "Frontend (devapp-web)"   "http://localhost:30080" "200"
check_endpoint "User API (health)"       "http://localhost:18080/actuator/health" "200"
check_endpoint "Order API (health)"      "http://localhost:18081/actuator/health" "200"
check_endpoint "User API (auth required)" "http://localhost:18080/api/users" "401"
check_endpoint "Swagger UI (user-app)"   "http://localhost:18080/swagger-ui/index.html" "200"

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
echo "  Frontend:      http://<SERVER_IP>:30080"
echo "  Via Ingress:   http://<SERVER_IP>:30090"
echo "  User API:      http://<SERVER_IP>:30090/api/users  (JWT required)"
echo "  Order API:     http://<SERVER_IP>:30090/api/orders (JWT required)"
echo "  Swagger (user):  http://<SERVER_IP>:30090/actuator/swagger-ui/index.html"
echo ""
echo "Pod status:"
kubectl get pods -n devapp --no-headers 2>&1 | awk '{printf "  %-50s %s\n", $1, $2}'
echo ""
echo "See README.md for Keycloak setup (required for authentication)."
