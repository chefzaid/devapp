# Deployment Guide

DevApp is deployed to the K3s platform managed by [`bm-cluster`](https://github.com/chefzaid/bm-cluster). The platform repository provides shared, application-neutral GitLab runner, Argo CD, Vault, External Secrets, registry, ingress, database, messaging, identity, and observability services. This repository owns every DevApp-specific delivery and runtime resource.

## Infrastructure Layout

DevApp follows the shared application-repository convention used by Thoughty and Indezy:

| Directory | Responsibility |
|---|---|
| `infra/ansible/` | optional manual reconciliation of committed GitOps state |
| `infra/argocd/` | the single Argo CD `Application` bootstrap at `application.yaml` |
| `infra/compose/` | local Compose base and purpose-specific overrides |
| `infra/keycloak/` | disposable local identity configuration |
| `infra/k8s/` | application-owned Kubernetes desired state |
| `infra/scripts/` | idempotent configuration and repository helpers |

Names use lowercase kebab-case. YAML files use `.yaml`; the Compose base is `compose.yaml`, overrides are `compose.<purpose>.yaml`, and Kubernetes workload files use the logical component name because each may contain more than one resource kind. Shared platform resources remain in `bm-cluster`.

Production entry points:

- Argo CD: `infra/argocd/application.yaml`
- Kubernetes: `infra/k8s/kustomization.yaml`
- GitLab bootstrap: `infra/scripts/configure-gitlab.sh`
- immutable image-tag update: `infra/scripts/set-image-tags.sh`

Local and manual entry points:

- Compose: `infra/compose/compose.yaml`
- full-stack test override: `infra/compose/compose.test.yaml`
- Ansible: `infra/ansible/site.yaml` with `infra/ansible/inventory.ini`
- Keycloak import: `infra/keycloak/realm.json`

## Ownership And Topology

| Concern | Owner |
|---|---|
| GitLab project and pipeline | this repository |
| container images and immutable tags | this repository |
| Argo CD `Application` | `infra/argocd/application.yaml` |
| Kubernetes workloads, ingress, policies, and observability | `infra/k8s/` |
| DevApp registry pull credential contract | `infra/k8s/registry-credentials.yaml` and Vault `apps/devapp/registry` |
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
kubectl apply --dry-run=client --validate=false -f infra/argocd/application.yaml >/dev/null
```

Workload manifests use non-root users, read-only root filesystems, dropped Linux capabilities, runtime-default seccomp, explicit resources, health probes, and immutable application image tags. Application pods pull through the `devapp-registry-auth` Secret produced by External Secrets.

## Images

The pipeline publishes:

```text
registry.swirlit.dev/swirlit/devapp/user-app:<semantic-version>
registry.swirlit.dev/swirlit/devapp/order-app:<semantic-version>
registry.swirlit.dev/swirlit/devapp/devapp-web:<semantic-version>
```

`01-build` compiles Maven and Angular outputs, optional `02-test` publishes unit and coverage results, and required `03-package` performs daemonless image validation. Combined coverage below 80 percent fails only the optional test job. Standard mode leaves `02-quality` manual; full mode runs that non-blocking quality branch automatically. Optional manual `01-e2e` remains independent. `01-release` publishes versioned artifacts and images; `02-deploy` runs only after release succeeds.

## One-Time GitLab Bootstrap

Prerequisites:

- the generic `bm-cluster` GitLab instance runner is online with tag `bm-cluster`
- GitLab, Argo CD, Vault, External Secrets, and the registry are healthy
- the repository contains `.gitlab-ci.yml` in its current commit
- `kubectl`, `curl`, `git`, `jq`, `python3`, `libsodium`, and `sudo` are available on the control-plane host
- `GITLAB_ADMIN_TOKEN` can manage the `swirlit/devapp` project
- `GITHUB_ADMIN_TOKEN` can manage Actions secrets and dispatch workflows for `chefzaid/devapp`
- Vault `infra/sonarqube:admin_token` contains the SonarQube automation token

Run from the repository root:

```bash
GITLAB_ADMIN_TOKEN=<gitlab-token> \
GITHUB_ADMIN_TOKEN=<github-token> \
  ./infra/scripts/configure-gitlab.sh
```

The app-owned scripts:

1. creates or updates `swirlit/devapp` without adding application knowledge to `bm-cluster`;
2. configure descriptions, topics, protected `main`, merge gates, retention, scoped feature visibility, labels, issue/MR templates, and pipeline, coverage, and Sonar badges;
3. bind the GitLab repository to the public `swirlit:devapp` SonarQube project, select the standard `Sonar way` gate, create a project-scoped analysis token, and install it as a masked CI variable;
4. install a least-privilege GitLab push credential as encrypted GitHub Actions secrets and register the GitLab push/tag webhook that dispatches the same repository reconciler;
5. enable the instance runner and CI job-token pushes;
6. create a read-only registry deploy token and write it to Vault at `apps/devapp/registry`;
7. apply the repository-owned Argo CD `Application`; and
8. request an External Secrets refresh when the resource already exists.

Every GitHub push starts `.github/workflows/sync-gitlab.yml` directly. Every GitLab branch or tag push calls GitHub's repository-dispatch endpoint and starts that same workflow, including commits marked `[skip ci]`. The reconciler fast-forwards whichever side is behind, merges divergent branches without force pushing, and refuses to rewrite a conflicting tag. A monthly schedule checks the managed GitLab token and self-rotates it into the encrypted GitHub secret before the mandatory expiry window.

The GitLab project is public for source browsing, while its container registry and package registry remain private. The registry deploy token is never committed to Git.

The database Secret is projected by `infra/k8s/external-secrets.yaml` from the cluster's PostgreSQL credential contract. Kubernetes Secret base64 values are encoding, not encryption; do not replace the Vault flows with committed values.

## Delivery Flow

The dashboard exposes explicit jobs with these dependencies:

1. `01-build → 02-test (optional) → 03-package` is the automatic build path.
2. `01-e2e` is optional/manual; `02-quality` consumes test reports independently, manually in standard mode and automatically in full mode. Neither gates release.
3. `01-release → 02-deploy` requires the successful build path and a successful release.
4. `set-major-version` is an independent manual job on `main`. Supply `NEW_MAJOR_VERSION` when starting the pipeline; the job prepares `<major>.0.0` and synchronizes Maven and npm manifests.

Select `PIPELINE_MODE=full` from **Run pipeline** on `main` to run non-blocking quality reporting and `01-build → 01-release → 02-deploy` automatically. E2E remains an optional manual branch and cannot suppress delivery.

Release and major-version changes are serialized through the `devapp-production` resource group. If `main` has moved, a stale action fails instead of overwriting newer desired state. Argo CD, rather than CI, owns workload reconciliation, pruning, and self-healing.

## Version Lifecycle

`VERSION` establishes the current `major.minor.patch` baseline. The build version adds one patch step for each new first-parent commit since that baseline. A release tags and deploys the computed version, then commits the next minor baseline with patch reset to zero. For example, commits in the `1.0` cycle produce `1.0.0`, `1.0.1`, and so on; releasing `1.0.3` prepares `1.1.0`. Major changes are deliberate and only occur through `set-major-version`.

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

A release is complete only when the required build and publication jobs passed, GitLab recorded the release and production deployment, and Argo CD reports the expected revision as `Synced` and `Healthy` after the smoke checks. Optional test, E2E, and quality reports do not lock release.

Rollback by reverting or changing the image-tag commit on `main`. Do not patch live Deployments: Argo CD self-healing will restore the Git state.

## Local And Manual Paths

The local stack remains available through Compose:

```bash
docker compose -f infra/compose/compose.yaml up --build -d
```

The Ansible playbook is an optional manual reconciliation of committed and pushed `main` through Argo CD, not a direct local-manifest deployment or the normal production delivery path:

```bash
ansible-playbook -i infra/ansible/inventory.ini infra/ansible/site.yaml
```
