# ADR 0001: Split Detailed Documentation Out Of The Root README

- Status: Accepted
- Date: 2026-08-28

## Context

The root README mixed project positioning, credentials, feature inventory, hardening decisions, platform versions, development, test commands, cluster delivery, operational URLs, and repository synchronization.

That made the entry point difficult to scan and left no durable home for data ownership, security boundaries, incident response, or architecture rationale. Sibling projects Thoughty and Indezy already use a reader-oriented `docs/` structure.

## Decision

Keep `README.md` as the short project entry point and move detailed material into:

- `docs/features.md`
- `docs/data-model.md`
- `docs/development.md`
- `docs/testing.md`
- `docs/deployment.md`
- `docs/operations.md`
- `docs/security.md`
- `docs/adr/`

Keep future technical capabilities in root `TODO.md`.

Documentation must explicitly distinguish implemented behavior from planned behavior. The roadmap must prioritize reusable technical capabilities and keep the demonstration domain minimal.

## Rationale

Different readers get a stable path:

- evaluators start with features
- contributors start with development/testing
- architects start with ADRs/data model
- deployers start with deployment
- operators start with operations
- reviewers start with security

The structure mirrors Thoughty and Indezy without copying their product-specific content.

## Consequences

The README remains concise while detailed guides can grow.

Cross-links and implementation accuracy become maintenance responsibilities. Technical changes should update the relevant guide and ADR in the same pull request.

Roadmap items cannot be presented as current features merely because dependencies or configuration placeholders exist.
