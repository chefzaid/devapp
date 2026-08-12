#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_NAMESPACE="${INFRA_NAMESPACE:-infra}"
GITHUB_USERNAME="${GITHUB_USERNAME:-chefzaid}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

info() { printf '[INFO] %s\n' "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

for command_name in kubectl git base64; do
    command -v "$command_name" >/dev/null || fail "$command_name is required"
done
kubectl cluster-info >/dev/null 2>&1 || fail "Cannot reach the Kubernetes cluster"
kubectl get namespace "$INFRA_NAMESPACE" >/dev/null 2>&1 || fail "Namespace '$INFRA_NAMESPACE' does not exist"
kubectl get deploy jenkins -n "$INFRA_NAMESPACE" >/dev/null 2>&1 || fail "Jenkins is not installed"
kubectl get crd applications.argoproj.io >/dev/null 2>&1 || fail "Argo CD is not installed"
kubectl get pod vault-0 -n "$INFRA_NAMESPACE" >/dev/null 2>&1 || fail "Vault pod vault-0 is not installed"

git -C "$SCRIPT_DIR" fetch origin main
git -C "$SCRIPT_DIR" show origin/main:deployments/kustomization.yaml >/dev/null 2>&1 ||
    fail "Push this DevApp CI/CD wiring to origin/main before running the bootstrap"

if [[ -z "$GITHUB_TOKEN" ]]; then
    [[ -t 0 ]] || fail "Set GITHUB_TOKEN to a fine-grained GitHub personal access token"
    printf '%s\n' "GitHub token required: fine-grained personal access token for chefzaid/devapp"
    printf '%s\n' "Repository permission: Contents = Read and write (no account-wide token needed)."
    read -rp "GitHub username [$GITHUB_USERNAME]: " entered_username
    GITHUB_USERNAME="${entered_username:-$GITHUB_USERNAME}"
    read -rsp "Fine-grained GitHub personal access token: " GITHUB_TOKEN
    printf '\n'
fi
[[ "$GITHUB_TOKEN" == github_pat_* ]] ||
    fail "Expected a fine-grained GitHub token (the value normally starts with github_pat_)"
[[ "$GITHUB_USERNAME" =~ ^[A-Za-z0-9-]+$ ]] || fail "Invalid GitHub username"
[[ "$GITHUB_TOKEN" =~ ^github_pat_[A-Za-z0-9_]+$ ]] || fail "Invalid fine-grained GitHub token format"

info "Storing the GitHub credential in Vault at secret/devapp/ci"
vault_token=$(kubectl get secret vault-init -n "$INFRA_NAMESPACE" -o jsonpath='{.data.root_token}' | base64 -d)
{
    printf '%s\n' "$vault_token"
    printf '%s\n' "$GITHUB_USERNAME"
    printf '%s\n' "$GITHUB_TOKEN"
} | kubectl exec -i -n "$INFRA_NAMESPACE" vault-0 -- /bin/sh -ceu '
    IFS= read -r VAULT_TOKEN
    IFS= read -r github_username
    IFS= read -r github_token
    export VAULT_TOKEN
    printf '"'"'{"data":{"github_username":"%s","github_token":"%s"}}'"'"' \
      "$github_username" "$github_token" | vault write secret/data/devapp/ci - >/dev/null
'
unset vault_token GITHUB_TOKEN

info "Creating the Vault-backed Jenkins agent credential"
kubectl apply -f "$SCRIPT_DIR/deployments/jenkins-credentials.yaml"
kubectl wait --for=condition=Ready externalsecret/devapp-ci-credentials \
    -n "$INFRA_NAMESPACE" --timeout=180s

info "Installing the Jenkins Pipeline, Git, Kubernetes-agent, JUnit, and workspace-cleanup plugins"
kubectl delete job devapp-jenkins-plugin-install -n "$INFRA_NAMESPACE" --ignore-not-found >/dev/null
kubectl apply -f "$SCRIPT_DIR/deployments/jenkins-plugins.yaml"
if ! kubectl wait --for=condition=complete job/devapp-jenkins-plugin-install \
    -n "$INFRA_NAMESPACE" --timeout=15m; then
    kubectl logs -n "$INFRA_NAMESPACE" job/devapp-jenkins-plugin-install --tail=100 || true
    fail "Jenkins plugin installation failed"
fi

info "Restarting Jenkins so the installed plugins are loaded"
kubectl rollout restart deployment/jenkins -n "$INFRA_NAMESPACE"
kubectl rollout status deployment/jenkins -n "$INFRA_NAMESPACE" --timeout=10m

info "Configuring the in-cluster Kubernetes cloud and the DevApp Pipeline job"
kubectl delete job devapp-jenkins-configure -n "$INFRA_NAMESPACE" --ignore-not-found >/dev/null
kubectl apply -f "$SCRIPT_DIR/deployments/jenkins-job.yaml"
if ! kubectl wait --for=condition=complete job/devapp-jenkins-configure \
    -n "$INFRA_NAMESPACE" --timeout=5m; then
    kubectl logs -n "$INFRA_NAMESPACE" job/devapp-jenkins-configure --tail=100 || true
    fail "Jenkins job configuration failed"
fi

info "Creating the Argo CD Application"
kubectl apply -f "$SCRIPT_DIR/deployments/argocd-apps.yaml"
kubectl annotate application devapp -n "$INFRA_NAMESPACE" \
    argocd.argoproj.io/refresh=hard --overwrite >/dev/null

for attempt in $(seq 1 90); do
    sync_status=$(kubectl get application devapp -n "$INFRA_NAMESPACE" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
    health_status=$(kubectl get application devapp -n "$INFRA_NAMESPACE" -o jsonpath='{.status.health.status}' 2>/dev/null || true)
    if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]]; then
        info "Starting the first Jenkins build if this is a new job"
        kubectl exec -n "$INFRA_NAMESPACE" deployment/jenkins -- /bin/sh -ceu '
          password=$(cat /var/jenkins_home/secrets/initialAdminPassword)
          url=http://127.0.0.1:8080
          job_state=$(curl -fsS -u "admin:$password" "$url/job/devapp/api/json?tree=lastBuild%5Bnumber%5D")
          if printf "%s" "$job_state" | grep -q '"'"'"lastBuild"'"'":null'; then
            cookies=$(mktemp)
            trap 'rm -f "$cookies"' EXIT
            crumb=$(curl -fsS -u "admin:$password" \
              -c "$cookies" \
              "$url/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)")
            curl -fsS -u "admin:$password" -b "$cookies" -H "$crumb" \
              -X POST "$url/job/devapp/build" >/dev/null
          fi
        '
        info "CI/CD is ready: Jenkins builds DevApp and Argo CD owns deployment"
        info "Jenkins: https://jenkins.swirlit.dev/job/devapp/"
        info "Argo CD: https://argocd.swirlit.dev/applications/devapp"
        exit 0
    fi
    sleep 10
done

kubectl get application devapp -n "$INFRA_NAMESPACE" || true
fail "Argo CD did not become Synced and Healthy within 15 minutes"
