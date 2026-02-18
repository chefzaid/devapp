#!/bin/bash

# DevApp One-Click Deployment Script
# Builds artifacts and deploys via Ansible

set -e

# Determine script directory and root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="$SCRIPT_DIR/.."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default Parameters
VERSION="latest"
REGISTRY="local"
NAMESPACE="devapp"
DEPLOY_ONLY=false
MONITORING=false

# Help Function
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -v <version>     App version (default: latest)"
    echo "  -r <registry>    Docker registry (default: local)"
    echo "  -n <namespace>   K8s namespace (default: devapp)"
    echo "  -d               Deploy only (skip build)"
    echo "  -m               Include monitoring (ELK, Grafana)"
    echo "  -h               Show help"
    exit 1
}

# Parse Arguments
while getopts "v:r:n:dmh" opt; do
    case $opt in
        v) VERSION="$OPTARG" ;;
        r) REGISTRY="$OPTARG" ;;
        n) NAMESPACE="$OPTARG" ;;
        d) DEPLOY_ONLY=true ;;
        m) MONITORING=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

echo -e "${GREEN}🚀 Starting DevApp Deployment Process${NC}"
echo "Version: $VERSION"
echo "Registry: $REGISTRY"
echo "Namespace: $NAMESPACE"

if [ "$DEPLOY_ONLY" = false ]; then
    # 1. Build Backend
    echo -e "${YELLOW}🔨 Building Java Applications...${NC}"
    mvn clean package -DskipTests -f "$ROOT_DIR/pom.xml"

    # 2. Build Frontend
    echo -e "${YELLOW}🔨 Building Angular Application...${NC}"
    cd "$ROOT_DIR/devapp-web"
    if command -v npm >/dev/null 2>&1; then
        npm install
        npm run build-prod
    else
        echo "⚠️  npm not found. Assuming build will happen in Docker or artifacts exist."
    fi
    # Change back to project root for docker builds
    cd "$ROOT_DIR"

    # 3. Build Docker Images
    echo -e "${YELLOW}🐳 Building Docker Images...${NC}"
    docker build -t "$REGISTRY/user-app:$VERSION" user-app
    docker build -t "$REGISTRY/order-app:$VERSION" order-app
    docker build -t "$REGISTRY/devapp-web:$VERSION" devapp-web

    # Tag 'latest' as well for convenience
    if [ "$VERSION" != "latest" ]; then
        docker tag "$REGISTRY/user-app:$VERSION" "$REGISTRY/user-app:latest"
        docker tag "$REGISTRY/order-app:$VERSION" "$REGISTRY/order-app:latest"
        docker tag "$REGISTRY/devapp-web:$VERSION" "$REGISTRY/devapp-web:latest"
    fi

    # Push if registry is not local
    if [ "$REGISTRY" != "local" ]; then
        echo -e "${YELLOW}⬆️  Pushing Docker Images...${NC}"
        docker push "$REGISTRY/user-app:$VERSION"
        docker push "$REGISTRY/order-app:$VERSION"
        docker push "$REGISTRY/devapp-web:$VERSION"
    fi
else
    echo -e "${YELLOW}⏩ Skipping build steps (Deploy Only mode)${NC}"
fi

# 4. Deploy with Ansible
echo -e "${YELLOW}📜 Running Ansible Playbook for Deployment...${NC}"
if command -v ansible-playbook >/dev/null 2>&1; then
    ansible-playbook "$SCRIPT_DIR/ansible/deploy.yml" \
        -i "$SCRIPT_DIR/ansible/inventory" \
        -e "namespace=$NAMESPACE" \
        -e "version=$VERSION" \
        -e "registry=$REGISTRY" \
        -e "monitoring=$MONITORING"
else
    echo -e "${RED}❌ Ansible not found! Cannot deploy.${NC}"
    echo "Please install ansible or run the playbook manually:"
    echo "ansible-playbook deployment/ansible/deploy.yml -e ..."
    exit 1
fi

echo -e "${GREEN}✅ Deployment Process Complete!${NC}"
echo "Check status: kubectl get pods -n $NAMESPACE"
