#!/usr/bin/env bash
set -euo pipefail

cd /workspace/swirl-demo-app

cat <<'INFO'
Swirl Demo App development environment

  Frontend:  cd swirlapp-web && npm start
  User API:  mvn spring-boot:run -pl swirlapp-user
  Order API: mvn spring-boot:run -pl swirlapp-order

Local development uses H2, a simple in-memory cache, and disabled authentication.
To start the complete infrastructure demo:

  docker compose -f .devcontainer/docker-compose.yml --profile local-infra up -d

Keycloak: http://localhost:8180/auth (admin/admin)
Kafka:    localhost:29092
Redis:    localhost:6379
Postgres: localhost:5432
INFO
