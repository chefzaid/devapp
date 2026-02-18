#!/bin/bash

# CI/CD Infrastructure Setup Script
# Deploys Jenkins, SonarQube, GitLab, and ArgoCD

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 Setting up CI/CD Infrastructure...${NC}"

if command -v ansible-playbook >/dev/null 2>&1; then
    ansible-playbook "$SCRIPT_DIR/ansible/deploy-cicd.yml"
else
    echo -e "${RED}❌ Ansible not found! Cannot deploy.${NC}"
    echo "Please install ansible or run the playbook manually:"
    echo "ansible-playbook deployment/ansible/deploy-cicd.yml"
    exit 1
fi

echo -e "${GREEN}✅ CI/CD Setup Complete!${NC}"
