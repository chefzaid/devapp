# DevApp

DevApp is the application layer for the `bm-cluster`: two Java 25/Spring Boot services, an Angular frontend, PostgreSQL, Kafka, Redis, and Keycloak integration. Cluster infrastructure belongs in the separate [`bm-cluster`](https://github.com/chefzaid/bm-cluster) repository; all DevApp deployment and CI/CD configuration stays here.

## Services

| Component | URL |
|---|---|
| Application | https://devapp.swirlit.dev |
| User API | https://devapp.swirlit.dev/api/users |
| Order API | https://devapp.swirlit.dev/api/orders |
| Metrics | https://grafana.swirlit.dev/d/devapp-overview |
| Logs | https://kibana.swirlit.dev/app/dashboards#/view/devapp-logs |
| Jenkins job | https://jenkins.swirlit.dev/job/devapp/ |
| Argo CD app | https://argocd.swirlit.dev/applications/devapp |

Internal service discovery uses Kubernetes DNS (`user-app.devapp.svc`, `postgres.infra.svc`, and so on); ClusterIP addresses are intentionally not documented because they are not stable.

## Deployment

The production path is GitOps:

1. Jenkins polls `main`, runs backend/frontend tests, and builds all three images.
2. Because this is a single-node K3s cluster, Jenkins imports immutable image tags into the node's containerd rather than using a remote image registry.
3. Jenkins updates only `deployments/kustomization.yaml` and pushes a `[skip ci]` deployment commit.
4. Argo CD detects that commit, synchronizes the complete application set, self-heals drift, and prunes resources removed from Git.
5. Jenkins waits for the exact Argo CD revision to become `Synced` and `Healthy`, then runs smoke tests.

Jenkins never runs `kubectl set image`; Argo CD is the only owner of workload rollout state.

### One-time CI/CD bootstrap

First push this repository state to `main`, then run:

```bash
./configure-cicd.sh
```

The script asks for a **fine-grained GitHub personal access token** restricted to `chefzaid/devapp` with repository permission **Contents: Read and write**. It stores the token in Vault, creates the ExternalSecret used by Jenkins agents, installs the required Jenkins plugins, creates the Pipeline job and Kubernetes cloud, and creates the Argo CD Application. No token is stored in Git.

The application manifests rendered by Argo CD can be checked locally with:

```bash
kubectl kustomize deployments
```

`install-devapp.sh` remains available for a manual first deployment, but routine releases should go through Jenkins and Argo CD.

## Development

The default Spring profile uses local H2 and optional local dependencies. The UAT/production configuration can be overridden with `DB_HOST`, `KAFKA_BOOTSTRAP_SERVERS`, `REDIS_HOST`, `JWT_ISSUER_URI`, and related environment variables.

```bash
# Backend build and tests
mvn clean verify

# Frontend
cd devapp-web
npm ci
npm run test:ci
npm run build-prod
```

For the prepared VS Code environment, reopen the project in its dev container. Optional local PostgreSQL/Kafka/Redis/Keycloak services can be started with:

```bash
cd .devcontainer
docker compose --profile local-infra up -d
```

Repository layout:

- `user-app/`, `order-app/`: Spring Boot services
- `devapp-web/`: Angular frontend and Nginx image
- `devapp-common/`: shared Java module
- `deployments/`: Kustomize resources plus Argo/Jenkins bootstrap manifests
- `Jenkinsfile`: build-to-GitOps delivery pipeline
- `configure-cicd.sh`: idempotent cluster bootstrap for DevApp CI/CD

## Observability and security

The backend pods expose Prometheus metrics. Production logs are JSON on stdout; the cluster log collector adds Kubernetes metadata and sends them to Elasticsearch. `deployments/observability.yaml` provisions the DevApp Grafana dashboard and Kibana saved objects.

API routes require Keycloak JWTs. Public operational endpoints are limited to health, Swagger UI, and OpenAPI documentation.

## License

GPL 3.0
