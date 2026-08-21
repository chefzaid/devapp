# DevApp

DevApp is a deliberately small, production-shaped full-stack demo. It has two Java 25 / Spring Boot 4 microservices and an Angular 22 SPA, while exercising the platform services supplied by [`bm-cluster`](https://github.com/chefzaid/bm-cluster).

## Quick start

The complete local demo is self-contained; Docker builds the applications, so host Java and Node installations are not required.

```bash
docker compose up --build -d
docker compose ps
```

Open <http://localhost:4200> and sign in with `user` / `password`. The Keycloak admin console is at <http://localhost:8180/auth/admin> with `admin` / `admin`.

Useful local endpoints:

| Endpoint | Purpose |
|---|---|
| <http://localhost:4200> | Angular application |
| <http://localhost:4200/api/docs> | Aggregated OpenAPI UI |
| <http://localhost:4200/api/users/openapi> | User OpenAPI document |
| <http://localhost:4200/api/orders/openapi> | Order OpenAPI document |
| `localhost:29092` | Kafka developer listener |

Follow the application path with `docker compose logs -f user-app order-app`. To stop it, run `docker compose down`. `docker compose down -v` also deletes all local demo data.

## What it demonstrates

The business flow is intentionally simple: users are stored by `user-app`; `order-app` creates a pending order and publishes it to Kafka; `user-app` validates the referenced user and publishes a result; `order-app` then marks the order approved or rejected.

| Technology | Demo usage |
|---|---|
| Java 25, Spring Boot 4.1 | Virtual-threaded REST services, validation, Problem Details, Actuator |
| Angular 22 | Standalone, lazy-loaded, signal-based UI with Vitest tests |
| PostgreSQL 18 | Persistent user and order tables through Spring Data JPA |
| Redis 8.8 | Distributed Spring Cache for API reads |
| Kafka 4.3 KRaft | Asynchronous order validation and result events |
| Keycloak 26.7 | OAuth 2.0 Authorization Code + PKCE and JWT resource servers |
| Prometheus / Grafana | Actuator metrics and the provisioned DevApp dashboard |
| Elasticsearch / Kibana | Structured JSON application logs and saved log views |
| Vault / External Secrets | Database and Nexus pull credentials injected into Kubernetes |
| Nexus | Maven/npm proxying and the private application image registry |
| Jenkins / Argo CD | Tested image build followed by a GitOps manifest update and rollout |
| K3s / Kubernetes / NGINX Ingress | Hardened workloads, probes, policies, services, TLS ingress |

The local Compose stack covers the application-facing runtime services. Observability, secrets, registry, CI/CD, and GitOps integrations are demonstrated by the Kubernetes deployment because those are cluster responsibilities.

## Current platform versions

- Java 25.0.4, Maven 3.9.16, Spring Boot 4.1.0
- Angular 22.1, TypeScript 6.0, Node.js 24.19 LTS, npm 12.0.2
- PostgreSQL 18.4, Redis 8.8, Kafka 4.3.1, Keycloak 26.7.1
- NGINX unprivileged 1.30.4

TypeScript and Node type definitions intentionally follow Angular 22 and Node 24 compatibility ranges instead of incompatible newer majors.

## Development and verification

The default Spring profile is dependency-free: it uses seeded H2 databases, in-memory caches, no Kafka listeners, and no authentication. This makes the services easy to run while the `prod` profile exercises the full stack.

```bash
# Requires JDK 25 and Maven 3.9+
mvn clean verify

cd devapp-web
npm ci
npm test
npm run test:coverage
npm run build-prod
```

Start `user-app` on 8080, `order-app` on 8081, and then `npm start`; Angular's development proxy routes both APIs. The included VS Code dev container provides Java 25, Maven, Node 24, and Angular CLI 22.

The production manifests can be rendered without changing the cluster:

```bash
kubectl kustomize deployments
```

Repository layout:

- `devapp-common/`: shared auditing, errors, enums, and immutable Kafka events
- `user-app/`, `order-app/`: independent Spring Boot services and persistence models
- `devapp-web/`: Angular SPA and unprivileged NGINX image
- `compose.yaml`, `infra/keycloak/`: complete local demo
- `deployments/`: Kustomize workloads, ingress, secrets, policies, and dashboards
- `Jenkinsfile`: Java/Angular verification, Kaniko image publishing, GitOps update, rollout and smoke tests

## Cluster delivery

Jenkins polls `main`, runs `mvn clean verify` and the Angular Vitest suite, builds immutable images with Kaniko, and publishes them to Nexus. It then changes only the Kustomize image tags in Git. Argo CD owns reconciliation, pruning, and self-healing; Jenkins waits for that exact Git revision to become healthy before smoke-testing all three services.

One-time CI/CD bootstrap is performed after the repository is pushed:

```bash
./configure-cicd.sh
```

The script stores a repository-scoped GitHub token in Vault and provisions the Jenkins and Argo CD resources. Routine releases should go through this pipeline; `install-devapp.sh` remains a manual bootstrap option.

Production URLs:

- Application: <https://devapp.swirlit.dev>
- API documentation: <https://devapp.swirlit.dev/api/docs>
- Metrics: <https://grafana.swirlit.dev/d/devapp-overview>
- Logs: <https://kibana.swirlit.dev/app/dashboards#/view/devapp-logs>
- Jenkins: <https://jenkins.swirlit.dev/job/devapp/>
- Argo CD: <https://argocd.swirlit.dev/applications/devapp>

## License

GPL 3.0
