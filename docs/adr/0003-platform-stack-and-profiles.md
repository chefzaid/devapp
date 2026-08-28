# ADR 0003: Use The Java, Angular, And Shared Platform Stack

- Status: Accepted
- Date: 2026-08-28

## Context

The template needs modern REST/event services, a browser client, relational persistence, distributed caching, identity, messaging, observability, containers, Kubernetes, and automated delivery. It must also support a fast developer loop without requiring the whole platform.

The surrounding `bm-cluster` platform already supplies PostgreSQL, Redis, Kafka, Keycloak, Vault, GitLab Container Registry, GitLab CI, Argo CD, Prometheus/Grafana, Elasticsearch/Kibana, K3s, and NGINX Ingress.

## Decision

Use:

- Java 25 and Spring Boot 4.1 for services
- Spring MVC, Validation, Data JPA, Cache, Kafka, Security resource server, Actuator, and SpringDoc
- Angular 22, TypeScript 6, RxJS, and `angular-oauth2-oidc` for the SPA
- PostgreSQL 18, Redis 8, Kafka 4 KRaft, and Keycloak 26 for production-shaped environments
- Docker/Compose locally
- Kustomize/Kubernetes on K3s
- shared platform observability, secrets, registry, and CI/CD

Maintain two runtime modes:

- dependency-free default: H2, simple cache, no authentication, no messaging
- UAT/production-shaped: PostgreSQL/Flyway, Redis, Keycloak JWT, Kafka, structured logs, and rate limiting

## Rationale

Spring Boot supplies mature, composable infrastructure for all backend patterns the template needs. Angular demonstrates a typed SPA with guards, interceptors, reactive services, tests, and optimized packaging.

The profile split prevents technical completeness from making ordinary code changes slow or infrastructure-dependent.

Reusing `bm-cluster` avoids duplicating operational platform ownership in the application repository.

## Consequences

Shared configuration shapes in both services must remain aligned.

H2 tests cannot prove PostgreSQL/Flyway/Redis/Kafka/Keycloak behavior, so production-profile and container verification remain necessary.

The template inherits compatibility and upgrade responsibilities across Java, Node, browsers, databases, messaging, and Kubernetes.

Infrastructure integrations should remain configurable so an adopter can substitute equivalent services.
