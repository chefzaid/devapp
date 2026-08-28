# ADR 0007: Deliver Through Jenkins, Immutable Images, And Argo CD

- Status: Accepted
- Date: 2026-08-28

## Context

The platform provides Jenkins Kubernetes agents, Nexus, GitLab, Argo CD, K3s, Vault, and External Secrets. DevApp needs reproducible quality gates, artifact publication, desired-state updates, reconciliation, and post-rollout verification.

Allowing Jenkins to mutate Deployments directly would make the cluster differ from Git and blur build versus runtime ownership.

## Decision

Use this delivery split:

- GitLab `main` is CI/CD source of truth
- Jenkins tests and builds applications
- runtime images package already-verified artifacts
- Kaniko pushes immutable `build-shortCommit` tags to Nexus
- Jenkins reconciles the Argo CD Application source path before quality/build stages so repository layout changes do not strand the existing Application
- Jenkins changes only Kustomize image tags after confirming `main` did not advance
- the desired-version commit includes `[skip ci]`
- Argo CD owns namespace creation, reconciliation, pruning, self-healing, and retry
- Jenkins waits for the exact GitOps commit to be synced/healthy
- internal smoke tests and real Keycloak browser acceptance finish the release
- GitHub is reconciled as a public mirror without force pushing

## Rationale

Git remains the auditable desired state. Jenkins owns build-time work; Argo CD owns runtime convergence.

Immutable tags and runtime Dockerfiles link deployed images to verified source/artifacts.

The advanced-main check prevents a stale pipeline from overwriting a newer desired version.

Exact-revision waiting avoids declaring success for an unrelated healthy revision.

Post-rollout browser tests verify ingress, Keycloak, both APIs, Kafka, persistence, and UI as one system.

## Consequences

Every normal release produces a second GitOps commit.

Manual Kubernetes changes are temporary because self-healing is enabled.

Jenkins, registry, and Git credentials are critical and must remain Vault-backed/minimally scoped.

GitHub can briefly lag Jenkins-originated GitLab commits until reconciliation runs.

Rollbacks should be desired-state commits/reverts, not imperative image changes.

The pipeline currently lacks several supply-chain gates such as SBOM signing, SAST/DAST, and policy-as-code.
