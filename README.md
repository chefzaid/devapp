# DevApp

DevApp is a deliberately small, production-shaped full-stack template. Two Java 25 / Spring Boot 4 services and an Angular 22 SPA demonstrate reusable application, event-driven, security, observability, testing, and GitOps patterns on the platform supplied by [`bm-cluster`](https://github.com/chefzaid/bm-cluster).

[![Java](https://img.shields.io/badge/Java-25-orange.svg)](https://openjdk.org/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-4.1.0-brightgreen.svg)](https://spring.io/projects/spring-boot)
[![Angular](https://img.shields.io/badge/Angular-22.1-red.svg)](https://angular.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-6.0-blue.svg)](https://www.typescriptlang.org/)

## GitLab Delivery

- [Run a pipeline](https://gitlab.swirlit.dev/swirlit/devapp/-/pipelines/new?ref=main)
- [Pipelines and delivery jobs](https://gitlab.swirlit.dev/swirlit/devapp/-/pipelines)
- [Versioned application packages](https://gitlab.swirlit.dev/swirlit/devapp/-/packages)
- [Container images](https://gitlab.swirlit.dev/swirlit/devapp/-/container_registry)
- [Releases](https://gitlab.swirlit.dev/swirlit/devapp/-/releases)

GitLab exposes `build`, `verify`, `release`, and `version` stages. Their jobs are ordered as `01-build`, `02-test`, `03-package`; `01-e2e`, `02-quality`, `03-security`; `01-release`, `02-deploy`; and `set-major-version`. Build and package are required; tests and their 80 percent coverage rule are non-blocking. Standard mode leaves E2E, quality, security, and release manual. `PIPELINE_MODE=full` runs non-blocking quality and Trivy security reporting automatically and automates release and deploy, while E2E remains manual.

Application versions start at `1.0.0` and are owned by [`VERSION`](./VERSION). Each new commit advances the patch component for its build (`1.0.1`, `1.0.2`, ...). A successful release tags and deploys that exact version, then prepares the next minor cycle (`1.1.0`, `1.2.0`, ...). To change the major version, start a pipeline with `NEW_MAJOR_VERSION` set to the desired integer and play `set-major-version`; it prepares `<major>.0.0` and synchronizes the Maven and npm manifests.

## Documentation

- [Features](./docs/features.md)
- [Architecture Overview and ADR Index](./docs/architecture.md)
- [Data Model Reference](./docs/data-model.md)
- [Development Guide](./docs/development.md)
- [Testing Guide](./docs/testing.md)
- [Deployment Guide](./docs/deployment.md)
- [Operations Runbook](./docs/operations.md)
- [Security Reference](./docs/security.md)
- [Infrastructure Layout](./docs/deployment.md#infrastructure-layout)

## Roadmap

Future reusable technical capabilities are tracked in [TODO.md](./TODO.md). Product behavior stays intentionally minimal so every example remains easy to understand and transplant.

## Quick Start

Docker builds and runs the complete authenticated demo, including PostgreSQL, Redis, Kafka, and Keycloak:

```bash
docker compose -f infra/compose/compose.yaml up --build -d
docker compose -f infra/compose/compose.yaml ps
```

Open <http://localhost:4200> and sign in with username `user` and password `password`. These credentials are public and intended only for the disposable demo environment.

Useful commands:

```bash
docker compose -f infra/compose/compose.yaml logs -f user-app order-app
docker compose -f infra/compose/compose.yaml down
mvn clean verify
cd devapp-web && npm ci && npm test
```

See the [Development Guide](./docs/development.md) for dependency-free local development and the [Testing Guide](./docs/testing.md) for the complete verification matrix.

## License

GPL 3.0
