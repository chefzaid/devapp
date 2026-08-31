# Testing Guide

DevApp verifies the reusable layers it demonstrates: API contracts, validation and errors, transaction-oriented services, caching, security, Kafka state handling, Angular integration, and real browser authentication.

## Test Layers

Backend layers:

- plain unit tests for services, listeners, filters, cache configuration, and health indicators
- Spring MVC slice tests for request validation, status codes, Problem Details, and response DTO privacy
- full Spring Boot + MockMvc security tests for anonymous and JWT-authenticated access
- Mockito fakes for repositories, Kafka templates, and infrastructure dependencies
- JaCoCo verification during the Maven `verify` phase

Frontend layers:

- Vitest service tests with Angular HTTP testing support
- component tests for login, users, and orders
- auth guard and interceptor tests
- notification and error behavior tests
- Playwright smoke journey against the development UI
- Playwright live/full-stack journey through Keycloak and both secured APIs

Deployment layers:

- Kubernetes manifest rendering
- post-rollout backend/frontend HTTP smoke tests
- exact Argo CD revision and health wait
- Chromium, Firefox, and WebKit acceptance against the deployed ingress

## Quick Commands

Backend reactor, tests, coverage report, and gate:

```bash
mvn clean verify
```

Frontend unit tests and production build:

```bash
cd devapp-web
npm ci
npm test
npm run test:coverage
npm run build-prod
```

Playwright types, browser install, and local E2E:

```bash
npm run test:e2e:types
npm run test:e2e:install
npm run test:e2e
```

With Mask:

```bash
mask test all
mask coverage all
mask build all
```

## Backend Test Map

### Shared module

- `RequestIdFilterTest`: accepted request IDs, unsafe-value replacement, response header, and MDC behavior
- `RateLimitFilterTest`: allowed requests, response headers, and `429` rejection after the configured limit

### User service

- `UserServiceTest`: bounded reads, not-found behavior, normalization, duplicate username/email rejection, persistence, and cache-oriented service behavior
- `OrderListenerTest`: approved result, missing-user rejection, synchronous result publication, and propagation of transient failures
- `UserControllerTest`: create/get/list responses, invalid bodies, invalid IDs/limits, malformed JSON, and private entity-field exclusion
- `CacheConfigTest`: Redis serialization and TTL configuration
- `DatabaseHealthIndicatorTest`: healthy and failed repository access
- `SecurityConfigTest`: anonymous API rejection and JWT-authenticated API access in a full application context

### Order service

- `OrderServiceTest`: bounded reads, not-found behavior, create flow, feature-switched publishing, and publication failures
- `OrderResultListenerTest`: approval/rejection, duplicate results, missing orders, invalid identity/status/state, and retryable behavior
- `OrderControllerTest`: create/get/list responses and input/path/query error contracts
- `CacheConfigTest`: Redis serialization and TTL configuration
- `DatabaseHealthIndicatorTest`: healthy and failed repository access
- `SecurityConfigTest`: anonymous API rejection and JWT-authenticated API access in a full application context

The current clean reactor run executes 46 tests: 4 in `devapp-common`, 21 in `order-app`, and 21 in `user-app`.

## Direct Maven Workflows

Run one module and its required reactor dependencies:

```bash
mvn -pl user-app -am test
mvn -pl order-app -am test
```

Run one class:

```bash
mvn -pl user-app -am -Dtest=UserServiceTest -Dsurefire.failIfNoSpecifiedTests=false test
mvn -pl order-app -am -Dtest=OrderResultListenerTest -Dsurefire.failIfNoSpecifiedTests=false test
```

Run one method:

```bash
mvn -pl user-app -am -Dtest=UserServiceTest#createUserNormalizesInput \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Test reports:

- `devapp-common/target/surefire-reports/`
- `user-app/target/surefire-reports/`
- `order-app/target/surefire-reports/`
- `user-app/target/site/jacoco/index.html`
- `order-app/target/site/jacoco/index.html`

The shared module skips its JaCoCo gate because it is infrastructure code tested directly. Each deployable service applies a 60 percent instruction gate after excluding application bootstrap, configuration, domain, and DTO classes.

## Backend Test Profiles

`application-test.yml` gives each service:

- a separate H2 database in PostgreSQL compatibility mode
- Hibernate `create-drop`
- disabled SQL seed initialization
- a simple cache
- stopped Kafka listeners
- disabled messaging and security by default

Security integration tests explicitly enable `app.security.enabled` and mock `JwtDecoder`. This verifies the real resource-server filter chain without calling Keycloak.

Use production-profile smoke or container tests when behavior depends on PostgreSQL, Flyway, Redis, Kafka, or Keycloak. H2 unit/slice tests do not prove those integrations.

## Frontend Test Map

Current Vitest specs:

- `login.component.spec.ts`
- `user.component.spec.ts`
- `order.component.spec.ts`
- `auth.service.spec.ts`
- `user.service.spec.ts`
- `order.service.spec.ts`
- `notification.service.spec.ts`
- `auth.guard.spec.ts`
- `auth.interceptor.spec.ts`

The current clean frontend run executes 40 tests across 9 files.

Coverage output:

- terminal summary from `npm run test:coverage`
- LCOV output under `devapp-web/coverage/`

CI uses `npm run test:ci`, which writes `devapp-web/test-results.xml` for GitLab CI and an LCOV report for analysis tooling.

## Playwright Suites

### Local UI smoke

`e2e/home.spec.ts` checks that the login route and SSO call to action render. When `WEB_URL` is unset, Playwright starts the Angular development server automatically.

```bash
cd devapp-web
npm run test:e2e
```

### Authenticated integration

`e2e/live-cluster.spec.ts`:

1. loads OIDC discovery
2. starts Authorization Code + PKCE login
3. authenticates through Keycloak
4. loads the secured user directory
5. loads the secured order workflow
6. optionally creates a user and order
7. waits for Kafka validation to approve the new order

Run against an environment:

```bash
cd devapp-web
WEB_URL=https://devapp.swirlit.dev \
OIDC_REALM=swirlit \
OIDC_USERNAME=zaid \
OIDC_PASSWORD='<from Vault/GitLab CI variable>' \
npm run test:integration
```

Set `E2E_EXERCISE_WRITES=true` only for disposable environments where creating demonstration records is acceptable.

Browser projects:

- Chromium / Desktop Chrome
- Firefox / Desktop Firefox
- WebKit / Desktop Safari

CI retries failures twice with one worker and forbids committed focused tests.

Artifacts:

- JUnit: `test-results/playwright-junit.xml`
- traces/screenshots/videos: `test-results/playwright/`
- HTML report: `playwright-report/`

Artifacts may contain entered test data. Use only disposable credentials and records.

## Containerized Full-Stack Acceptance

Run the whole production-shaped local system plus Playwright:

```bash
docker compose \
  -f infra/compose/compose.yaml \
  -f infra/compose/compose.test.yaml up \
  --build \
  --abort-on-container-exit \
  --exit-code-from test-runner
```

The test overlay:

- uses an internal Keycloak issuer reachable through the web proxy
- starts the same PostgreSQL, Redis, Kafka, Keycloak, user, order, and web services as `infra/compose/compose.yaml`
- installs exact frontend dependencies in a Playwright image
- enables write exercise
- persists test results and reports in named volumes

Clean it up after inspection:

```bash
docker compose \
  -f infra/compose/compose.yaml \
  -f infra/compose/compose.test.yaml down -v
```

## Production-Profile Smoke Testing

For persistence changes, verify more than H2:

1. build the packaged JARs
2. start a disposable PostgreSQL and Redis
3. start both services under `prod` with security/messaging disabled only for the smoke
4. wait for readiness
5. call both list APIs
6. inspect both Flyway history tables and affected columns
7. remove only the disposable resources created for the test

This catches Flyway auto-configuration, PostgreSQL SQL differences, shared-schema baselining, Redis wiring, and Hibernate validation errors.

Testcontainers should eventually automate this workflow; it remains on the roadmap.

## Kubernetes And Delivery Verification

Render manifests without changing a cluster:

```bash
kubectl kustomize infra/k8s
```

GitLab shows ordered jobs: required `01-build`, optional `02-test`, required `03-package`, optional manual `01-e2e`, non-blocking `02-quality`, independent non-blocking `03-security`, `01-release`, and `02-deploy`. Standard mode leaves quality and Trivy security manual; full mode runs both automatically. Security scans the repository for vulnerable dependencies, IaC misconfigurations, and exposed secrets, retains JSON/SARIF artifacts, and has no dependency on quality. Release requires the successful build path, and deployment requires successful release. `PIPELINE_MODE=full` also automates release and deploy; E2E remains manual.

## Test Design Rules

### Start at the narrowest layer

Use a unit test for service state or filter logic, MVC test for HTTP mapping, full context for filter-chain integration, and Playwright only for critical cross-system journeys.

### Assert contracts, not implementation calls alone

Good outcomes include:

- invalid query limit returns a validation Problem Detail
- anonymous API call returns `401`
- transient user lookup failure is retried rather than converted to rejection
- duplicate result leaves an already-final order unchanged
- response DTO does not reveal entity audit principals or versions

### Cover failure and replay paths

Infrastructure templates need explicit coverage for malformed input, missing resources, duplicate messages, invalid transitions, dependency failure, and retry exhaustion.

### Keep fixtures minimal

Seed only enough user/order state to prove the technical behavior. Large product fixtures obscure template mechanics.

### Prefer accessible frontend selectors

Use roles, labels, headings, and visible text. Avoid selectors coupled to CSS layout when a semantic selector exists.

## Known Verification Gaps

Not yet first-class:

- Testcontainers integration suite
- automated Flyway upgrade tests from every supported schema version
- durable DLT/replay and consumer restart tests
- consumer-driven HTTP/event contracts
- mutation, load, soak, chaos, visual-regression, and accessibility suites
- automated container and secret scanning beyond the current dependency and SonarQube reports
- policy-as-code checks for manifests

Track these in [TODO.md](../TODO.md), not as existing coverage.

## Troubleshooting

### Mockito warns about dynamic agent loading

Surefire attaches the exact Mockito agent through `argLine`. Run Maven through the root reactor so the configured plugin and resolved dependency are used.

### Security test unexpectedly returns 401

Use Spring Security's JWT request post-processor and ensure the test enables security explicitly. `@WithMockUser` alone does not exercise an OAuth2 resource-server bearer-token flow equivalently.

### Playwright cannot find browser binaries

```bash
cd devapp-web
npm run test:e2e:install
```

### Public E2E receives an edge challenge

The public Cloudflare path may challenge headless clients. GitLab CI resolves the DevApp and canonical Keycloak public hostnames directly to the in-cluster ingress. `IGNORE_HTTPS_ERRORS=true` is used only for that origin route because the ingress has a Cloudflare Origin CA certificate; do not use it for normal public-endpoint validation.

### A browser test passes alone but fails in the suite

All projects execute the same flow. Use unique test data per `testInfo.project.name`, avoid shared ordering assumptions, and inspect retained traces.

## Related Guides

- [Development](./development.md)
- [Features](./features.md)
- [Data Model](./data-model.md)
- [Security](./security.md)
- [Operations](./operations.md)
