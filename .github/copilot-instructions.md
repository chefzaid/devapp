# Copilot Instructions for DevApp

## Architecture

Multi-module Spring Boot 3.5.3 (Java 21) + Angular 21 monorepo. Two microservices communicate via Kafka using the Saga pattern, with an Angular SPA frontend behind Nginx.

### Modules

- **`devapp-common/`** — Shared library depended on by both services. Contains: domain models (`User`, `Order`, `OrderStatus`), `JwtUtil` (HS256, JJWT 0.11.5), `BaseEntity` with JPA auditing, `SwaggerConfig` (springdoc-openapi), `GlobalExceptionHandler`, and `Constants`.
- **`user-app/`** (port 8080) — User service. REST CRUD at `/api/users`. Consumes from Kafka topic `order_topic`, validates the user exists, sets order status to APPROVED/REJECTED, publishes result to `order_result_topic`.
- **`order-app/`** (port 8081) — Order service. REST CRUD at `/api/orders`. On order creation, sets status to PENDING and publishes to `order_topic`. Consumes from `order_result_topic` to update order status. Uses Redis for caching.
- **`devapp-web/`** (port 4200 dev / port 80 prod via Nginx) — Angular 21 standalone components with Angular Material. Routes: `/login`, `/users` (guarded), `/orders` (guarded), `/` → redirects to `/users`.

### Kafka Saga Flow

```
OrderService.createOrder() → status=PENDING → publish to "order_topic"
    → user-app OrderListener consumes → validates user exists
        → APPROVED (+ notification) or REJECTED
        → publish to "order_result_topic"
            → order-app OrderResultListener consumes → updates order status in DB
```

The event payload is the full `Order` object serialized as JSON (JsonSerializer/JsonDeserializer).

### Authentication & Security

- **Keycloak** provides OAuth2/OIDC. Realm: `devapp`.
- **Frontend** uses `angular-oauth2-oidc` with Authorization Code Flow + PKCE. Token issuer URL is `/auth/realms/devapp` (proxied through Nginx).
- **Backend services** are OAuth2 Resource Servers (`spring-boot-starter-oauth2-resource-server`). JWT issuer: `http://keycloak:8080/realms/devapp` (K8s DNS).
- **AuthInterceptor** (Angular) attaches Bearer token to all API requests.
- **AuthGuard** (Angular) protects `/users` and `/orders` routes; redirects to `/login`.
- `JwtAuthenticationFilter` in user-app exists but is currently disabled (commented-out `@Component`). Security relies on OAuth2 Resource Server config instead.
- Public endpoints: `/api/auth/**`, `/h2-console/**`, `/actuator/**`, `/swagger-ui/**`, `/v3/api-docs/**`.

### Request Routing (Production)

Nginx in devapp-web proxies API calls to backend K8s services:
- `/api/users` → `http://user-app:8080/api/users`
- `/api/orders` → `http://order-app:8081/api/orders`

Nginx Ingress routes:
- `/` → devapp-web:80
- `/api/users` → user-app:8080
- `/api/orders` → order-app:8081
- `/auth` → keycloak:8080

Frontend environment files use relative paths (`/api`, `/auth`) so routing works through Nginx.

## Build & Test Commands

### Backend (Java 21, Maven)

```bash
# Build all modules (from repo root) — must build devapp-common first
mvn clean package

# Run all backend tests
mvn clean verify

# Run a single test class
mvn test -pl user-app -Dtest=UserServiceTest

# Run a single test method
mvn test -pl order-app -Dtest=OrderControllerTest#testCreateOrder

# Run tests for one module only
mvn test -pl devapp-common
```

### Frontend (Angular 21, Node 24)

```bash
cd devapp-web

npm install
npm run build            # dev build
npm run build-prod       # production build (output: dist/devapp-web)
npm test                 # unit tests (Karma/Jasmine, headless Chrome, single run)
npm run test:ci          # unit tests with coverage + JUnit report
npm run lint             # ESLint
npm run lint:fix         # ESLint auto-fix
npm run test:e2e         # Cypress E2E tests (baseUrl: localhost:4200)
npm run test:integration # Cypress integration tests
npm run analyze          # Bundle analysis
```

### Integration Tests (Docker Compose)

```bash
docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit
```

Spins up: postgres-test (:5433), kafka-test (:9093), redis-test (:6380), both backend services, devapp-web, and a Node test-runner container.

## Spring Profiles

| Profile | Database | DDL | Kafka | Redis | Activated by |
|---------|----------|-----|-------|-------|-------------|
| **dev** (default) | H2 in-memory | `create-drop` | localhost:9092 | — | default |
| **test** | H2 in-memory | `none` (uses `classpath:db/schema.sql`) | — | — | `application-test.yml` |
| **prod** | PostgreSQL (env vars: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`) | `validate` | env: `KAFKA_BOOTSTRAP_SERVERS` | env: `REDIS_HOST` | set in K8s manifests |

## Module Structure Conventions

### Backend (Java)

Each backend service follows the same package layout under `io.simpleit.devapp.<service>`:

```
controller/    — REST controllers (@RestController, @RequestMapping("/api/..."))
service/       — Business logic (@Service, @Cacheable where applicable)
repository/    — Spring Data JPA repositories
config/        — Spring configuration (Kafka, Redis, Security, etc.)
security/      — SecurityConfig, filters (user-app only has JwtAuthenticationFilter)
dto/           — Request/Response DTOs (user-app: AuthRequest, AuthResponse)
```

Shared code in `devapp-common` under `io.simpleit.devapp.common`: `domain`, `security`, `config`, `exception`, `util`.

### Frontend (Angular 21 — Standalone Components)

```
src/app/
  components/     — Shared components (notification)
  guards/         — auth.guard.ts (functional guard)
  interceptors/   — auth.interceptor.ts (functional interceptor, attaches Bearer token)
  models/         — user.model.ts, order.model.ts
  services/       — auth.service.ts, user.service.ts, order.service.ts, notification.service.ts
  user/           — UserComponent (list + create form)
  order/          — OrderComponent (list + create form with user dropdown)
```

Routes are defined in `main.ts` (no separate routing module). App uses `provideRouter()` and `provideHttpClient(withInterceptors(...))`.

## Key Conventions

- **Lombok** across all backend modules — `@Data`, `@Builder`, `@NoArgsConstructor`, `@AllArgsConstructor` on entities and DTOs.
- **JPA Auditing** via `BaseEntity` in devapp-common — `createdBy`, `lastModifiedBy`, `createdDate`, `lastModifiedDate` auto-populated by `AuditorAwareImpl`.
- **Domain models** (`User`, `Order`) are in devapp-common, shared by both services. `Order` has `@ManyToOne` to `User`. `OrderStatus` enum: PENDING, APPROVED, REJECTED, COMPLETED, SHIPPED, CANCELLED, PROCESSING, DELIVERED.
- **Redis caching** in both services: 10-minute TTL, JSON value serialization, String key serialization.
- **Kafka** producer/consumer configs are per-service (not shared). Both use `JsonSerializer`/`JsonDeserializer` with `Order` as the message type. Consumer group IDs from `spring.kafka.consumer.group-id`.
- **Validation**: `@Valid` on controller request bodies; Spring Boot Validation starter handles constraint violations via `GlobalExceptionHandler`.
- **OpenAPI docs**: Auto-generated at `/swagger-ui/` and `/v3/api-docs/` for each service.
- **Pre-commit hooks** (`.pre-commit-config.yaml`): trailing whitespace fix, end-of-file fixer, YAML check, large file check (>500KB).

## CI/CD Pipeline

The `Jenkinsfile` defines a multi-stage pipeline running in Kubernetes (Jenkins agent pods):

1. **Checkout & Setup** — clean workspace, git checkout
2. **Code Quality & Security** (parallel):
   - Backend tests: `mvn clean test` + JaCoCo coverage
   - Frontend: `npm run lint`, `npm run test:ci`, `npm run build`
   - SonarQube analysis (coverage reports from JaCoCo XML + LCOV)
3. **Build Applications** (parallel):
   - Backend: `mvn package -DskipTests` → artifacts archived
   - Frontend: `npm run build-prod` → artifacts archived
4. **Security Scanning** (parallel):
   - OWASP Dependency Check (fails build on CVSS ≥ 7)
   - License compliance check
5. **Docker Build & Trivy Scan** — builds 3 images (user-app, order-app, devapp-web), Trivy scans for HIGH/CRITICAL vulnerabilities
6. **Integration Tests** — `docker-compose.test.yml` (main/develop branches only)
7. **Push Docker Images** — to registry (main/develop only)
8. **Deploy to Staging** — Ansible playbook `deployment/ansible/deploy.yml` (develop branch)
9. **Smoke Tests** — curl health checks on `/actuator/health` (develop branch)
10. **Deploy to Production** — manual approval, Ansible playbook (main branch)

**Post actions**: Slack/email notifications, Docker cleanup, artifact archival.

### Deployment

- **Ansible** (`deployment/ansible/deploy.yml`): Templates K8s manifests with image tags, applies to target namespace.
- **K8s manifests** in `deployment/k8s/`: infrastructure (postgres, kafka, redis, keycloak, monitoring) + app (01-user-app, 02-order-app, 03-devapp-web).
- **Namespaces**: `devapp` (default), `devapp-staging`, `devapp-prod`.
- **ArgoCD** monitors `deployment/k8s/` for GitOps reconciliation.

## Dev Container

A full dev container setup exists in `.devcontainer/` with Docker Compose providing: PostgreSQL 16, Kafka (Confluent 7.4.0), Zookeeper, and Redis 7. Helper scripts in `.devcontainer/scripts/`:
- `kafka-setup.sh` — manage topics, produce/consume test messages
- `test-kafka-integration.sh` — end-to-end Kafka integration test
- `post-create.sh` — generates `start-all.sh`, `stop-all.sh`, per-service start scripts
