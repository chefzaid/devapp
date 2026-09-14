# Deployment Guide

DevApp is deployed to the K3s platform managed by [`bm-cluster`](https://github.com/chefzaid/bm-cluster). The platform repository provides shared, application-neutral GitLab runner, Argo CD, Vault, External Secrets, registry, ingress, database, messaging, identity, and observability services. This repository owns every DevApp-specific delivery and runtime resource.

## Infrastructure Layout

DevApp follows the shared application-repository convention used by Thoughty and Indezy:

| Directory | Responsibility |
|---|---|
| `infra/ansible/` | optional manual reconciliation of committed GitOps state |
| `infra/argocd/` | the single Argo CD `Application` bootstrap at `application.yaml` |
| `infra/compose/` | local Compose base and purpose-specific overrides |
| `infra/keycloak/` | production browser client and disposable local realm |
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
| production OIDC client | `infra/keycloak/production-client.json` and `infra/scripts/configure-keycloak.py` |
| generic cluster services | `bm-cluster` |

Runtime namespaces:

- application workloads: `apps`
- shared services and Argo CD: `infra`
- disposable GitLab CI jobs: `gitlab-runners`

The public endpoint is `https://devapp.swirlit.dev`. Ingress routes `/api/users` to `user-app`, `/api/orders` to `order-app`, the API documentation paths to the user service, and `/` to `devapp-web`. The backends use the shared PostgreSQL, Redis, Kafka, and Keycloak endpoints supplied by the cluster.

Traefik serves the native Ingress and the platform redirects HTTP to HTTPS.
The app-owned Middleware in `infra/k8s/ingress.yaml` limits requests to 10 MiB;
its ServersTransport gives backends 60 seconds to return response headers.
Traefik's platform entrypoint controls connection timeouts. NetworkPolicy permits
the platform's Traefik pods. Database setup uses the public PostgreSQL 18.6
client image pinned by digest in Kustomize, without platform registry credentials.
Both API Deployments also trust the configured ingress pod CIDR for anonymous
rate limiting; onboarding adjusts it through `TRUSTED_PROXY_CIDRS`. See the
[client IP contract](security.md#rate-limiting) before changing proxy topology.

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

`01-build` compiles Maven and Angular outputs, optional `02-test` publishes unit and coverage results, and required `03-package` performs daemonless image validation. Combined coverage below 80 percent fails only the optional test job. Default-branch quality runs automatically. Standard mode leaves `03-security` manual; full mode runs both non-blocking report branches automatically. Trivy security is ordered after quality but has no dependency on it. Optional manual `01-e2e` remains independent. `01-release` publishes versioned artifacts and images; `02-deploy` runs only after release succeeds.

## Add or reconfigure this repository

Run `./add-repos.sh` from the platform checkout and select this repository.
The platform reads [infra/onboarding.json](../infra/onboarding.json), prompts
for the public subdomain (`@` selects the zone apex), and applies the declared
service requests. It does not execute this repository's administrator scripts.

The declaration owns the exact public configuration files, image locations,
Keycloak client, registry credential path, DNS hostname and readiness checks.
Selected settings are committed in `infra/onboarding-values.json` along with
the rendered application files, so subsequent GitOps reconciliations and image
releases keep them. Rerun the entry point to change a hostname; the Kubernetes
names, database name, identity client ID and Vault paths remain stable.

The platform provisions registry access and the declared identity/DNS settings,
then starts an API pipeline for that exact pushed commit. `APP_ONBOARDING=true`
allows its release job to run automatically. `ONBOARDING_EXPECTED_SHA` is checked
before building or publishing; deployment also checks the generated release is
a descendant of that commit and still the default branch tip. Ordinary release
jobs remain manual unless the existing full-mode web pipeline is selected.
Sonar scan-only pipelines cannot release or deploy. The first Argo CD apply
happens after images are published.

The final onboarding publication records `Onboarding-Pipeline` and
`Onboarding-Source` commit trailers so a repeat run can identify the existing
release. A failed deployment can retry that pipeline's deploy job. If publication
fails after its Git push, repair the failed publication step before retrying:
the guard refuses to publish another release from the old checkout.

The app-owned `devapp-db-setup` sync hook runs before the APIs. It creates
`devappdb` only when absent, using the existing `devapp-db-credentials` contract
from `infra/postgres`. A PostgreSQL advisory lock serializes concurrent runs;
existing owners, schemas and data are preserved. Flyway continues to own schema
migrations. Registry and database ExternalSecrets reconcile in the preceding
sync wave.

Local checks for this contract:

```sh
python3 infra/scripts/test-onboarding.py
docker pull postgres:18-alpine
python3 infra/scripts/test-database-bootstrap.py
```

The first command needs Python with PyYAML, Git and kubectl and checks rendered
custom domains, project paths, root/subdomain changes, image releases and stale
pipeline refusal. The database test uses only its own temporary Docker container
and removes that container and its data when finished.

## Individual GitLab bootstrap

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
7. reconcile the production Keycloak browser client, then apply the repository-owned Argo CD `Application`; and
8. request an External Secrets refresh when the resource already exists.

Every GitHub push starts `.github/workflows/sync-gitlab.yml` directly. Every GitLab branch or tag push calls GitHub's repository-dispatch endpoint and starts that same workflow, including commits marked `[skip ci]`. The reconciler fast-forwards whichever side is behind, merges divergent branches without force pushing, and refuses to rewrite a conflicting tag. A monthly schedule checks the managed GitLab token and self-rotates it into the encrypted GitHub secret before the mandatory expiry window.

The GitLab project is public for source browsing, while its container registry and package registry remain private. The registry deploy token is never committed to Git.

The database Secret is projected by `infra/k8s/external-secrets.yaml` from the cluster's PostgreSQL credential contract. Kubernetes Secret base64 values are encoding, not encryption; do not replace the Vault flows with committed values.

## Production Identity

This repository owns the `devapp-web` public client in the existing `swirlit`
realm. The platform manages the realm and its users. The production client
requires Authorization Code with PKCE `S256`, restricts redirects and origins
to this application's host, and disables password and implicit grants.
`infra/keycloak/realm.json` is a separate disposable local realm; never import
its demonstration users or secrets into production.

The GitLab bootstrap above reconciles the production client before deploying.
For direct Argo CD onboarding or a changed client configuration, run:

```sh
python3 infra/scripts/configure-keycloak.py --render
python3 infra/scripts/configure-keycloak.py
```

The second command requires `kubectl` access to `infra/keycloak-admin-secret`
and permission to port-forward the Keycloak Service. It authenticates through
a temporary loopback-only Kubernetes port-forward, keeps credentials in memory,
and updates only this client, its scope assignments and managed claim mappers. An existing client
keeps its UUID. No administrator credential is copied into `apps` or CI.
Rerun it after editing `infra/keycloak/production-client.json`; keep frontend
issuer/realm configuration, ingress hosts and allowed origins aligned when
adapting the template. Use `--realm` and `--namespace` for a different existing
realm or platform namespace. The realm and shared scopes must exist first.
Scope assignments are checked after reconciliation: `groups` is optional and
the default `roles` scope is removed to keep realm management roles out of
browser tokens. Unrelated optional scopes are preserved.

Removing the application does not delete shared identities. Retire its client
explicitly in Keycloak when the application is permanently decommissioned.
The reconciler uses the [Keycloak Admin REST API](https://www.keycloak.org/docs-api/latest/rest-api/index.html).

## Delivery Flow

The dashboard exposes explicit jobs with these dependencies:

1. `01-build → 02-test (optional) → 03-package` is the automatic build path.
2. `01-e2e` is optional/manual; `02-quality` consumes test reports and `03-security` scans the repository independently, with quality automatic on the default branch and security automatic in full mode. None gates release.
3. `01-release → 02-deploy` requires the successful build path and a successful release.
4. `set-major-version` is an independent manual job on `main`. Supply `NEW_MAJOR_VERSION` when starting the pipeline; the job prepares `<major>.0.0` and synchronizes Maven and npm manifests.

Select `PIPELINE_MODE=full` from **Run pipeline** on `main` to run non-blocking quality/security reporting and `01-build → 01-release → 02-deploy` automatically. E2E remains an optional manual branch and cannot suppress delivery.

Release and major-version changes are serialized through the `devapp-production` resource group. If `main` has moved, a stale action fails instead of overwriting newer desired state. Argo CD, rather than CI, owns workload reconciliation, pruning, and self-healing.

## Version Lifecycle

`VERSION` establishes the current `major.minor.patch` baseline. The build version adds one patch step for each new first-parent commit since that baseline. A release tags and deploys the computed version, then commits the next minor baseline with patch reset to zero. For example, commits in the `1.0` cycle produce `1.0.0`, `1.0.1`, and so on; releasing `1.0.3` prepares `1.1.0`. Major changes are deliberate and only occur through `set-major-version`.

## Public DNS

After the shared ingress has a public address, reconcile only DevApp's record:

```bash
CLOUDFLARE_API_TOKEN=<zone-token> ./infra/scripts/configure-cloudflare.sh
```

The token needs `Zone:Read` and `DNS:Edit` for `swirlit.dev`. Generic zone, wildcard TLS, proxy, and ingress configuration remains in the platform.

See [application-owned DNS](dns.md) for direct ingress and HA Tunnel setup.
The helper uses an HA Tunnel only after the platform's published checkpoint
confirms that the ingress path is ready.

## Verification And Rollback

```bash
kubectl get application devapp -n infra
kubectl get deployment,pod,service,ingress -n apps
kubectl get externalsecret devapp-db-credentials devapp-registry-auth -n apps
kubectl rollout status deployment/user-app -n apps
kubectl rollout status deployment/order-app -n apps
kubectl rollout status deployment/devapp-web -n apps
```

A release is complete only when the required build and publication jobs passed, GitLab recorded the release and production deployment, and Argo CD reports the expected revision as `Synced` and `Healthy` after the smoke checks. Optional test, E2E, quality, and security reports do not lock release.

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

## Automatic Sonar coverage

The platform discovers this repository through its Argo CD workloads in `apps`
every 15 minutes. One Sonar project includes the shared Java module, both backend
services and the Angular frontend, as declared in `sonar-project.properties`.
`.sonar-auto.json` declares the CI contract. `SONAR_SCAN_ONLY=true` on the default
branch runs only compilation, tests/coverage and `02-quality`; it excludes image
packaging, browser/security jobs, release, deployment and version changes.
The platform provisions the Sonar project and masked analysis token, and requests
a scan when analysis is missing or more than 24 hours old. Normal default-branch
pipelines also run quality automatically. Submission failures fail the quality
job visibly; quality findings remain independent of deployment permission.

The quality job uses the shared slim Node scanner image; browser images are only
needed for explicitly requested E2E jobs.

The [code-quality guide](code-quality.md) documents source and coverage inputs,
[the contract to preserve when copying DevApp](code-quality.md#adapting-the-template),
credentials, scheduling and troubleshooting.

## Future multi-node HA profile

`infra/overlays/ha` composes the normal Kubernetes resources and runs two copies
of each API and the web frontend. It requires at least two eligible hosts,
spreads matching Pods across hostnames, and adds a disruption budget per
Deployment. Rolling updates keep an available replica while starting its
replacement. Leave `infra/k8s` selected on a single host.

To opt in, persist `spec.source.path: infra/overlays/ha` in this repository's
`infra/argocd/application.yaml` before reconciling that Application. Bootstrap
and release helpers can reapply the file, so a live-only path override is not
durable. Image release scripts continue updating `infra/k8s/kustomization.yaml`;
the HA overlay inherits those exact image tags.

Render both profiles before changing selection:

```sh
kubectl kustomize infra/k8s >/dev/null
kubectl kustomize infra/overlays/ha >/dev/null
```

This is application redundancy, with shared-service availability still required:
PostgreSQL needs a replicated primary service, Redis needs failover, Kafka needs
replicated brokers/topics, and Keycloak/ingress must remain reachable after a
node fails. Use the same JWT issuer and shared consumer group per service on
every replica; sticky sessions are unnecessary. Flyway coordinates each
service's schema history, and schema changes must remain compatible with the
previous application revision during a rollout.

Rate limits remain per API process. The current database commit and Kafka
publish are also separate operations, so interruption between them can leave
an order pending; an outbox is needed for durable publication. Additional
replicas do not resolve those limits. Before enabling this profile, verify
JWT requests across replicas, shared-cache invalidation, Kafka rebalance and
duplicate handling, then drain one eligible node while exercising both APIs.
A PDB governs voluntary eviction; it cannot prevent hardware failures.
