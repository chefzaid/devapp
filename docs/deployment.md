# Deployment Guide

DevApp is deployed to the K3s platform managed by [`bm-cluster`](https://github.com/chefzaid/bm-cluster). The platform repository provides shared, application-neutral GitLab runner, Argo CD, Vault, External Secrets, registry, ingress, database, messaging, identity, and observability services. This repository owns every DevApp-specific delivery and runtime resource.

## Ownership And Topology

| Concern | Owner |
|---|---|
| GitLab project and pipeline | this repository |
| container images and immutable tags | this repository |
| Argo CD `Application` | `infra/k8s/argocd-apps.yaml` |
| Kubernetes workloads, ingress, policies, and observability | `infra/k8s/` |
| DevApp registry pull credential contract | `infra/k8s/registry-secret.yaml` and Vault `apps/devapp/registry` |
| public DNS record | `infra/scripts/configure-cloudflare.sh` |
| generic cluster services | `bm-cluster` |

Runtime namespaces:

- application workloads: `apps`
- shared services and Argo CD: `infra`
- disposable GitLab CI jobs: `gitlab-runners`

The public endpoint is `https://devapp.swirlit.dev`. Ingress routes `/api/users` to `user-app`, `/api/orders` to `order-app`, the API documentation paths to the user service, and `/` to `devapp-web`. The backends use the shared PostgreSQL, Redis, Kafka, and Keycloak endpoints supplied by the cluster.

## Kubernetes Desired State

`infra/k8s/kustomization.yaml` composes:

- the user, order, and web Deployments and Services
- ingress and network policy
- Vault-backed database and private-registry pull secrets
- dashboards and log-view bootstrap resources

Render and validate it without changing the cluster:

```bash
kubectl kustomize infra/k8s >/dev/null
kubectl apply --dry-run=client --validate=false -k infra/k8s >/dev/null
kubectl apply --dry-run=client --validate=false -f infra/k8s/argocd-apps.yaml >/dev/null
```

Workload manifests use non-root users, read-only root filesystems, dropped Linux capabilities, runtime-default seccomp, explicit resources, health probes, and immutable application image tags. Application pods pull through the `devapp-registry-auth` Secret produced by External Secrets.

## Images

The pipeline publishes:

```text
registry.swirlit.dev/root/devapp/user-app:<pipeline>-<commit>
registry.swirlit.dev/root/devapp/order-app:<pipeline>-<commit>
registry.swirlit.dev/root/devapp/devapp-web:<pipeline>-<commit>
```

GitLab CI verifies the Maven and Angular artifacts first. Kaniko then packages those artifacts with each component's `Dockerfile.runtime`, so no Docker daemon is needed in the runner pod.

## One-Time GitLab Bootstrap

Prerequisites:

- the generic `bm-cluster` GitLab instance runner is online with tag `bm-cluster`
- GitLab, Argo CD, Vault, External Secrets, and the registry are healthy
- the repository contains `.gitlab-ci.yml` in its current commit
- `kubectl`, `curl`, `git`, `jq`, and `sudo` are available on the control-plane host
- `GITLAB_ADMIN_TOKEN` can manage the `root/devapp` project

Run from the repository root:

```bash
GITLAB_ADMIN_TOKEN=<api-token> ./infra/scripts/configure-gitlab.sh
```

The app-owned script:

1. creates or updates `root/devapp` without adding application knowledge to `bm-cluster`;
2. enables the instance runner and CI job-token pushes;
3. creates a read-only registry deploy token;
4. writes that pull credential to Vault at `apps/devapp/registry`;
5. applies the repository-owned Argo CD `Application`; and
6. requests an External Secrets refresh when the resource already exists.

The GitLab project is public for source browsing, while its container registry and package registry remain private. The registry deploy token is never committed to Git.

The database Secret is projected by `infra/k8s/devapp-secrets.yaml` from the cluster's PostgreSQL credential contract. Kubernetes Secret base64 values are encoding, not encryption; do not replace the Vault flows with committed values.

## Delivery Flow

For merge requests and branches, `.gitlab-ci.yml` validates manifests and runs backend and frontend quality gates. A successful default-branch pipeline additionally:

1. publishes three immutable images with Kaniko;
2. verifies that `main` has not advanced since the pipeline started;
3. updates only the three Kustomize image tags;
4. pushes a `deploy: <version> [skip ci]` desired-state commit with `CI_JOB_TOKEN`;
5. applies and refreshes the DevApp Argo CD `Application`;
6. waits for that exact Git commit to become `Synced` and `Healthy`;
7. performs in-cluster HTTP smoke tests; and
8. runs the Keycloak/API browser acceptance suite.

The deployment job is serialized through the `devapp-production` resource group. If `main` has moved, the stale pipeline fails instead of overwriting newer desired state. Argo CD, rather than CI, owns workload reconciliation, pruning, and self-healing.

## Public DNS

After the shared ingress has a public address, reconcile only DevApp's record:

```bash
CLOUDFLARE_API_TOKEN=<zone-token> ./infra/scripts/configure-cloudflare.sh
```

The token needs `Zone:Read` and `DNS:Edit` for `swirlit.dev`. Generic zone, wildcard TLS, proxy, and ingress configuration remains in the platform.

## Verification And Rollback

```bash
kubectl get application devapp -n infra
kubectl get deployment,pod,service,ingress -n apps
kubectl get externalsecret devapp-db-credentials devapp-registry-auth -n apps
kubectl rollout status deployment/user-app -n apps
kubectl rollout status deployment/order-app -n apps
kubectl rollout status deployment/devapp-web -n apps
```

A release is complete only when Argo CD reports the expected revision as `Synced` and `Healthy` and both smoke and acceptance jobs pass.

Rollback by reverting or changing the image-tag commit on `main`. Do not patch live Deployments: Argo CD self-healing will restore the Git state.

## Local And Manual Paths

The local stack remains available through Compose:

```bash
docker compose -f infra/compose/compose.yaml up --build -d
```

The Ansible playbook is an optional manual application of committed desired state, not the normal production delivery path:

```bash
ansible-playbook -i infra/ansible/inventory infra/ansible/deploy.yml
```
