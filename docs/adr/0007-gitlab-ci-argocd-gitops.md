# ADR 0007: Deliver Through GitLab CI, Immutable Images, And Argo CD

> ADR 0009 supersedes this ADR's job topology. The GitOps, daemonless Kaniko, immutable-tag, and exact-revision decisions below remain active.

- Status: Accepted
- Date: 2026-08-28

## Context

The platform provides GitLab CI Kubernetes agents, GitLab Container Registry, GitLab, Argo CD, K3s, Vault, and External Secrets. DevApp needs reproducible verification, artifact publication, desired-state updates, reconciliation, and post-rollout checks.

Allowing GitLab CI to mutate Deployments directly would make the cluster differ from Git and blur build versus runtime ownership.

## Decision

Use this delivery split:

- GitLab `main` is CI/CD source of truth
- GitLab CI tests and builds applications
- runtime images package already-verified artifacts
- Kaniko pushes immutable `build-shortCommit` tags to GitLab Container Registry
- Kaniko reuses registry-backed build layers for 30 days
- CI retains downloadable job artifacts for seven days and publishes immutable JAR/SPA archives plus checksums to GitLab's Generic Package Registry
- the repository keeps a stable Argo CD bootstrap path at `infra/argocd/application.yaml`
- GitLab CI changes only Kustomize image tags after confirming `main` did not advance
- the desired-version commit includes `[skip ci]`
- Argo CD owns namespace creation, reconciliation, pruning, self-healing, and retry
- GitLab CI waits for the exact GitOps commit to be synced/healthy
- internal smoke checks finish deploy; real Keycloak browser acceptance remains an explicit optional E2E job
- GitHub is reconciled as a public mirror without force pushing

## Rationale

Git remains the auditable desired state. GitLab CI owns build-time work; Argo CD owns runtime convergence.

Immutable tags and runtime Dockerfiles link deployed images to verified source/artifacts.

The advanced-main check prevents a stale pipeline from overwriting a newer desired version.

Exact-revision waiting avoids declaring success for an unrelated healthy revision.

Optional post-rollout browser tests verify ingress, Keycloak, both APIs, Kafka, persistence, and UI as one system without becoming a delivery gate.

## Consequences

Every normal release produces a second GitOps commit.

Manual Kubernetes changes are temporary because self-healing is enabled.

GitLab CI, registry, and Git credentials are critical and must remain Vault-backed/minimally scoped.

GitHub can briefly lag GitLab CI-originated GitLab commits until reconciliation runs.

Rollbacks should be desired-state commits/reverts, not imperative image changes.

The pipeline currently lacks several supply-chain gates such as SBOM signing, SAST/DAST, and policy-as-code.
