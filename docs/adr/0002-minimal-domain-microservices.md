# ADR 0002: Keep A Minimal Domain Across Two Independently Deployable Services

- Status: Accepted
- Date: 2026-08-28

## Context

DevApp is intended to demonstrate reusable production-shaped patterns, including service deployment, persistence ownership, asynchronous communication, security, caching, observability, and delivery.

A single backend would not demonstrate cross-service events. A rich product domain would make the template harder to understand, copy, and remove.

## Decision

Use two independently runnable/deployable Spring Boot services and one Angular SPA:

- `user-app`: owns a minimal user directory and validates order users
- `order-app`: owns minimal orders and their validation state
- `devapp-common`: contains cross-cutting infrastructure and immutable shared event/status contracts, not service-owned entities
- `devapp-web`: demonstrates login and create/list flows only

Keep the domain deliberately constrained to the smallest end-to-end behavior needed to exercise the technical stack.

Use layered packages within each service. Keep REST DTOs separate from JPA entities. Do not share repositories or directly query another service's table.

## Rationale

Two services make event ordering, eventual consistency, retries, DLTs, service ownership, deployment, and observability concrete.

The minimal user/order model reduces cognitive load and makes patterns portable. Template adopters can replace the example domain without losing the infrastructure concepts.

A shared module avoids duplicating genuinely cross-cutting behavior while the no-shared-entity rule prevents accidental distributed-monolith coupling.

## Consequences

The template has more runtime components than a modular monolith, even though its product behavior is tiny.

Cross-service consistency is eventual and failures must be explicit.

New functional features require strong justification: they should prove a missing technical pattern rather than expand the product for its own sake.

If reusable infrastructure accumulates, it may be extracted into optional internal starters so example services can be removed cleanly.
