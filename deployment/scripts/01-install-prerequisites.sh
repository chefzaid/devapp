#!/bin/bash
# ==============================================================================
# 01-install-prerequisites.sh
# Installs system dependencies, K3s, Helm, and Longhorn on a bare Ubuntu server.
# Tested on Ubuntu 24.04 LTS.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/../.."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

ask() {
    local prompt="$1"
    read -rp "$(echo -e "${YELLOW}$prompt [y/N]${NC} ")" answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ---------- Pre-flight checks ------------------------------------------------
[[ $EUID -eq 0 ]] && error "Do not run as root. The script uses sudo when needed."

info "============================================="
info " DevApp Prerequisites Installer"
info "============================================="
echo ""
echo "This script will install:"
echo "  - Java 21 (OpenJDK)"
echo "  - Maven"
echo "  - Node.js 24"
echo "  - Docker"
echo "  - Ansible"
echo "  - K3s (lightweight Kubernetes)"
echo "  - Helm 3"
echo "  - Longhorn (distributed storage)"
echo ""

ask "Proceed with installation?" || { info "Aborted."; exit 0; }

# ---------- System dependencies -----------------------------------------------
info "Updating apt cache..."
sudo apt-get update -qq

info "Installing system packages..."
sudo apt-get install -y -qq \
    openjdk-21-jdk \
    maven \
    docker.io \
    ansible \
    open-iscsi \
    nfs-common \
    curl \
    jq \
    git \
    > /dev/null

# Node.js 24
if ! command -v node &>/dev/null || [[ "$(node -v)" != v24* ]]; then
    info "Installing Node.js 24..."
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - > /dev/null 2>&1
    sudo apt-get install -y -qq nodejs > /dev/null
fi

# Docker group
if ! groups "$USER" | grep -q docker; then
    info "Adding $USER to docker group (re-login required for non-sudo docker)..."
    sudo usermod -aG docker "$USER"
fi

# iSCSI (required by Longhorn)
sudo systemctl enable --now iscsid > /dev/null 2>&1

# Fix Ubuntu 24.04 Maven proxy ghost
export MAVEN_OPTS="-Dhttp.proxyHost= -Dhttps.proxyHost="
grep -q "MAVEN_OPTS" ~/.bashrc 2>/dev/null || \
    echo 'export MAVEN_OPTS="-Dhttp.proxyHost= -Dhttps.proxyHost="' >> ~/.bashrc

info "System dependencies installed."
echo "  Java: $(java -version 2>&1 | head -1)"
echo "  Maven: $(mvn -version 2>&1 | head -1)"
echo "  Node: $(node -v)"
echo "  Docker: $(docker --version)"

# ---------- K3s ---------------------------------------------------------------
if command -v k3s &>/dev/null; then
    warn "K3s already installed: $(k3s --version | head -1)"
    ask "Reinstall K3s?" && INSTALL_K3S=true || INSTALL_K3S=false
else
    INSTALL_K3S=true
fi

if [[ "$INSTALL_K3S" == "true" ]]; then
    info "Installing K3s (disabling Traefik, using Nginx Ingress instead)..."
    curl -sfL https://get.k3s.io | sh -s - \
        --disable traefik \
        --write-kubeconfig-mode 644

    # Configure kubectl for current user
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown "$USER":"$USER" ~/.kube/config
    export KUBECONFIG=~/.kube/config
    grep -q "KUBECONFIG" ~/.bashrc 2>/dev/null || \
        echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc

    info "K3s installed. Waiting for node to be Ready..."
    kubectl wait --for=condition=Ready node --all --timeout=120s
fi

export KUBECONFIG=~/.kube/config

# ---------- Helm --------------------------------------------------------------
if command -v helm &>/dev/null; then
    info "Helm already installed: $(helm version --short)"
else
    info "Installing Helm 3..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash > /dev/null 2>&1
    info "Helm installed: $(helm version --short)"
fi

# ---------- Longhorn ----------------------------------------------------------
if helm list -n longhorn-system 2>/dev/null | grep -q longhorn; then
    warn "Longhorn already installed."
else
    info "Installing Longhorn (distributed storage)..."
    helm repo add longhorn https://charts.longhorn.io 2>/dev/null || true
    helm repo update > /dev/null 2>&1

    helm install longhorn longhorn/longhorn \
        --namespace longhorn-system \
        --create-namespace \
        --set defaultSettings.defaultReplicaCount=1 \
        --wait --timeout 300s

    # Set Longhorn as default StorageClass
    kubectl patch storageclass longhorn -p \
        '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    kubectl patch storageclass local-path -p \
        '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' 2>/dev/null || true

    info "Longhorn installed. Waiting for pods..."
    kubectl wait --for=condition=ready pod -l app=longhorn-manager \
        -n longhorn-system --timeout=180s
fi

# ---------- Port forwarding (optional) ----------------------------------------
info ""
info "============================================="
info " Prerequisites installation complete!"
info "============================================="
echo ""
echo "Installed:"
echo "  K3s:      $(k3s --version 2>&1 | head -1)"
echo "  Helm:     $(helm version --short)"
echo "  Longhorn: $(helm list -n longhorn-system -o json | jq -r '.[0].app_version')"
echo ""
echo "Next step: run ./02-install-infrastructure.sh"
