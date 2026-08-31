# ADR 0006: Use Service-Owned Flyway Histories In The Shared PostgreSQL Schema

- Status: Accepted
- Date: 2026-08-28

## Context

Both services currently use one PostgreSQL database/schema supplied by the shared platform, but each owns a different table. Production previously relied on Hibernate schema mutation, which obscured review, rollback compatibility, and ownership.

If both services used Flyway's default history table in the same schema, one service could treat the other's version sequence as its own.

## Decision

Use Flyway as the UAT/production schema owner and Hibernate only for validation.

Each service has:

- its own immutable migration directory
- its own history table
- baseline-on-migrate at version `0` for adoption into an already non-empty shared schema
- `ddl-auto: validate`
- SQL initialization disabled
- aligned H2 schema SQL for the dependency-free profile

History tables:

- `flyway_schema_history_users`
- `flyway_schema_history_orders`

Keep service table ownership independent even while the physical database is shared. Do not create cross-service foreign keys or joins.

## Rationale

Versioned migrations are reviewable and reproducible. Separate histories allow either service to initialize and advance without consuming the other's version numbers.

Hibernate validation detects drift without making unreviewed production changes.

Baseline version `0` lets a service install its history when another service has already made the schema non-empty while still running version `1` and later migrations.

## Consequences

Every entity change needs both a new owning-service Flyway migration and aligned development schema SQL.

Applied migrations must never be edited; fixes use new versions.

Application rollback must consider schema compatibility.

Sharing one physical schema remains an operational coupling. Service ownership rules preserve an easier future move to separate databases, but the move would still require infrastructure and data migration work.

Automated multi-version migration testing is planned but not yet implemented.
