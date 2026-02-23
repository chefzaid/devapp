#!/bin/bash
# ==============================================================================
# 02-install-infrastructure.sh
# Deploys all infrastructure components into the 'infrastructure' K8s namespace.
# Includes: Nginx Ingress, PostgreSQL, Kafka, Zookeeper, Redis, Keycloak,
#           Prometheus, Grafana, ELK, Jenkins, SonarQube, Nexus, ArgoCD.
#
# Prerequisites: Run 01-install-prerequisites.sh first.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
command -v kubectl &>/dev/null || error "kubectl not found. Run 01-install-prerequisites.sh first."
command -v helm &>/dev/null    || error "helm not found. Run 01-install-prerequisites.sh first."
kubectl cluster-info &>/dev/null || error "Cannot reach K8s cluster. Is K3s running?"

info "============================================="
info " DevApp Infrastructure Installer"
info "============================================="
echo ""
echo "This script will deploy to the 'infrastructure' namespace:"
echo "  - Nginx Ingress Controller (Helm)"
echo "  - PostgreSQL, Kafka, Zookeeper, Redis"
echo "  - Keycloak (IAM)"
echo "  - Prometheus, Grafana (monitoring)"
echo "  - Elasticsearch, Logstash, Kibana (logging)"
echo "  - Jenkins (CI/CD)"
echo "  - SonarQube (code quality)"
echo "  - Nexus (artifact repository)"
echo "  - ArgoCD (GitOps)"
echo ""

ask "Proceed with infrastructure installation?" || { info "Aborted."; exit 0; }

# ---------- Create namespace --------------------------------------------------
step "Creating infrastructure namespace..."
kubectl create namespace infrastructure 2>/dev/null || true

# ---------- Nginx Ingress (Helm) ----------------------------------------------
step "Installing Nginx Ingress Controller..."
if helm list -n infrastructure 2>/dev/null | grep -q ingress-nginx; then
    warn "Nginx Ingress already installed, skipping."
else
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
    helm repo update > /dev/null 2>&1
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace infrastructure \
        --set controller.service.type=NodePort \
        --set controller.service.nodePorts.http=30090 \
        --set controller.service.nodePorts.https=30443 \
        --wait --timeout 120s
    info "Nginx Ingress installed (HTTP :30090, HTTPS :30443)."
fi

# ---------- Core data stores --------------------------------------------------
step "Deploying PostgreSQL..."
kubectl apply -f "$K8S_DIR/postgres.yaml"

step "Deploying Kafka & Zookeeper..."
kubectl apply -f "$K8S_DIR/kafka.yaml"

step "Deploying Redis..."
kubectl apply -f "$K8S_DIR/redis.yaml"

# Wait for data stores before proceeding
info "Waiting for data stores to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres  -n infrastructure --timeout=180s
kubectl wait --for=condition=ready pod -l app=redis     -n infrastructure --timeout=120s
kubectl wait --for=condition=ready pod -l app=zookeeper -n infrastructure --timeout=180s
kubectl wait --for=condition=ready pod -l app=kafka     -n infrastructure --timeout=180s

# ---------- Keycloak ----------------------------------------------------------
step "Deploying Keycloak..."
kubectl apply -f "$K8S_DIR/keycloak.yaml"

# ---------- Monitoring (Prometheus + Grafana) ---------------------------------
step "Deploying Prometheus & Grafana..."
kubectl apply -f "$K8S_DIR/monitoring.yaml"

# ---------- ELK Stack ---------------------------------------------------------
step "Deploying ELK Stack (Elasticsearch, Logstash, Kibana)..."
kubectl apply -f "$K8S_DIR/elk.yaml"

# ---------- CI/CD: Jenkins ----------------------------------------------------
step "Deploying Jenkins..."
kubectl apply -f "$K8S_DIR/jenkins.yaml"
kubectl apply -f "$K8S_DIR/jenkins-config.yaml"

# ---------- Code Quality: SonarQube -------------------------------------------
step "Deploying SonarQube..."
kubectl apply -f "$K8S_DIR/sonarqube.yaml"

# ---------- Artifacts: Nexus --------------------------------------------------
step "Deploying Nexus..."
kubectl apply -f "$K8S_DIR/nexus.yaml"

# ---------- ArgoCD (Helm) -----------------------------------------------------
step "Installing ArgoCD..."
if helm list -n infrastructure 2>/dev/null | grep -q argocd; then
    warn "ArgoCD already installed, skipping."
else
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
    helm repo update > /dev/null 2>&1
    helm install argocd argo/argo-cd \
        --namespace infrastructure \
        --set server.service.type=NodePort \
        --set server.service.nodePortHttp=30007 \
        --set server.service.nodePortHttps=30008 \
        --set configs.params."server\.insecure"=true \
        --set redis.enabled=true \
        --wait --timeout 300s
    info "ArgoCD installed."
fi

# ---------- ArgoCD Applications -----------------------------------------------
step "Creating ArgoCD Application definitions..."
kubectl apply -f "$K8S_DIR/argocd-apps.yaml"

# ---------- Wait for everything -----------------------------------------------
info "Waiting for remaining pods to become ready (up to 5 min)..."
# Best-effort wait; some pods (ES, Logstash) take longer
kubectl wait --for=condition=ready pod -l app=keycloak      -n infrastructure --timeout=180s 2>/dev/null || warn "Keycloak still starting..."
kubectl wait --for=condition=ready pod -l app=jenkins        -n infrastructure --timeout=180s 2>/dev/null || warn "Jenkins still starting..."
kubectl wait --for=condition=ready pod -l app=elasticsearch  -n infrastructure --timeout=180s 2>/dev/null || warn "Elasticsearch still starting..."
kubectl wait --for=condition=ready pod -l app=kibana         -n infrastructure --timeout=180s 2>/dev/null || warn "Kibana still starting..."
kubectl wait --for=condition=ready pod -l app=logstash       -n infrastructure --timeout=180s 2>/dev/null || warn "Logstash still starting..."

# ---------- Summary -----------------------------------------------------------
info ""
info "============================================="
info " Infrastructure installation complete!"
info "============================================="
echo ""
echo "Service access (replace <IP> with your server IP):"
echo ""
echo "  Nginx Ingress (HTTP)  http://<IP>:30090"
echo "  Jenkins               http://<IP>:30000"
echo "  SonarQube             http://<IP>:30002"
echo "  Prometheus            http://<IP>:30003"
echo "  Grafana               http://<IP>:30004   (admin / admin)"
echo "  Nexus                 http://<IP>:30005"
echo "  ArgoCD                http://<IP>:30007"
echo "  Kibana                http://<IP>:30009"
echo ""
echo "Retrieve credentials:"
echo "  Jenkins:  kubectl exec -n infrastructure deployment/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword"
echo "  ArgoCD:   kubectl -n infrastructure get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "  Nexus:    kubectl exec -n infrastructure deployment/nexus -- cat /nexus-data/admin.password"
echo ""

# Pod overview
echo "Pod status:"
kubectl get pods -n infrastructure --no-headers 2>&1 | awk '{printf "  %-50s %s\n", $1, $2}'
echo ""
echo "Next step: run ./03-install-devapp.sh"
