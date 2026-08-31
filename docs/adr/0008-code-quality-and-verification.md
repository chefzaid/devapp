# ADR 0008: Keep Verification Layered And Continuous

- Status: Accepted
- Date: 2026-08-28

## Context

The template demonstrates behavior at multiple risk boundaries: validation/errors, JPA transactions, caching, OAuth security filters, Kafka retries/state, Angular authentication/API calls, containers, Kubernetes, identity, and GitOps rollout.

No single test type can cover these efficiently. Running only full-stack tests would be slow and hard to diagnose; running only mocked unit tests would miss production wiring.

## Decision

Use a test pyramid with explicit environment verification:

- unit tests for services, listeners, filters, cache, health, guards, interceptors, and API clients
- MVC tests for HTTP validation/error/DTO contracts
- full Spring context tests for JWT filter chains
- JaCoCo coverage evidence for deployable service logic
- Vitest component/service coverage
- Playwright local smoke and live authenticated critical flow in three engines
- containerized full-stack acceptance
- production Angular and packaged Java builds
- Kubernetes manifest rendering
- required GitLab compilation and image validation, with test/coverage and quality reports kept non-blocking
- internal smoke and exact-revision browser acceptance after rollout

Start changes at the narrowest useful layer and add integration coverage when behavior crosses infrastructure boundaries.

## Rationale

Fast tests give contributors tight feedback. Full-context tests catch configuration mistakes. Browser and post-rollout tests prove trust/routing/event boundaries that mocks cannot.

Packaging already-tested artifacts avoids divergence between what passed and what was deployed.

Failure/replay paths are first-class in an infrastructure template, so tests cover malformed input, unauthorized access, duplicate events, invalid transitions, missing data, and transient failures.

## Consequences

CI consumes more time/resources than a minimal build and browser acceptance depends on platform availability.

H2 remains insufficient for production persistence guarantees; PostgreSQL/Flyway and infrastructure tests must continue to grow.

The later delivery decision standardizes an 80 percent reported coverage policy and keeps it non-blocking for release; coverage remains evidence rather than proof of adequate risk coverage.

Testcontainers, contracts, mutation, load, chaos, accessibility, supply-chain, and manifest policy tests remain roadmap work.

New technical patterns must include configuration, failure, operations, and tests—not only a happy-path example.
