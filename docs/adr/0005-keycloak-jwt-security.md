# ADR 0005: Delegate Authentication To Keycloak And Validate JWTs At Each API

- Status: Accepted
- Date: 2026-08-28

## Context

DevApp needs to demonstrate browser SSO and independent API authorization without implementing credential storage, password hashing, sessions, recovery, or identity lifecycle inside the example services.

The shared platform already provides Keycloak. A browser SPA cannot safely hold a confidential client secret.

## Decision

Use Keycloak OpenID Connect Authorization Code flow with PKCE `S256`:

- Angular is a public client
- direct password grants are disabled
- frontend guard controls navigation experience
- frontend interceptor adds bearer tokens to APIs
- each Spring service is an OAuth2 resource server and validates JWTs independently
- APIs are stateless
- application APIs require authentication in UAT/production
- health/metrics/docs use an explicit allowlist
- production H2 console is disabled/disallowed
- local default profile may disable auth for development
- public TLS terminates at NGINX Ingress with forwarded headers understood by Spring

Keep credentials out of application tables. The example `User` is directory data, not the Keycloak identity record.

## Rationale

Keycloak centralizes credential and federation concerns while services keep a standard bearer-token boundary.

Authorization Code + PKCE is appropriate for a public SPA and avoids exposing user passwords to application code.

Independent resource-server validation prevents the frontend or ingress from becoming the only security boundary.

The development switch keeps the default loop fast, while separate security integration tests verify the actual filter chain.

## Consequences

Issuer, redirect origin, forwarded host/scheme, and JWK configuration must remain precisely aligned.

Frontend guards are not authorization; every real data policy must be enforced in backend code.

The template currently demonstrates authentication only. Role/authority mapping and method authorization remain planned.

The imported realm credentials/client secret are disposable demo values and must be replaced/removed for real environments.

Changing from bearer headers to cookie-backed application sessions would require revisiting CSRF and session security.
