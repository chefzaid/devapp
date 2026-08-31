# Operations Runbook

This runbook covers the DevApp application layer, including its public DNS record, registry-credential projection, Argo CD application, and dashboard metadata. Shared database, messaging, identity, registry, CI/CD, ingress, logging, and monitoring services are owned by [`bm-cluster`](https://github.com/chefzaid/bm-cluster); use its runbooks when the incident is platform-wide. All DevApp-specific configuration remains in this repository.

## Runtime Surfaces

Public:

| Surface | URL |
|---|---|
| application | <https://devapp.swirlit.dev> |
| API documentation | <https://devapp.swirlit.dev/api/docs> |
| Grafana dashboard | <https://grafana.swirlit.dev/d/devapp-overview> |
| Kibana logs | <https://kibana.swirlit.dev/app/dashboards#/view/devapp-logs> |
| GitLab | <https://gitlab.swirlit.dev/swirlit/devapp> |
| GitHub mirror | <https://github.com/chefzaid/devapp> |
| GitLab CI | <https://gitlab.swirlit.dev/swirlit/devapp/-/pipelines> |
| SonarQube | <https://sonarqube.swirlit.dev/dashboard?id=swirlit%3Adevapp> |
| Argo CD | <https://argocd.swirlit.dev/applications/devapp> |

Cluster-only:

| Surface | Address |
|---|---|
| user service | `user-app.apps.svc.cluster.local:8080` |
| order service | `order-app.apps.svc.cluster.local:8081` |
| web service | `devapp-web.apps.svc.cluster.local:80` |
| PostgreSQL | `postgres.swirlit.internal:5432` |
| Redis | `redis.swirlit.internal:6379` |
| Kafka | `kafka.swirlit.internal:9092` |
| Keycloak | `keycloak.swirlit.internal:8080/auth` |

Application services use canonical Kubernetes service DNS. The shared dependencies retain platform-owned private `*.swirlit.internal` aliases, which are intentionally absent from public DNS.

## First Checks After A Rollout

```bash
kubectl get application devapp -n infra
kubectl get deploy,pods,svc,ingress -n apps
kubectl get externalsecret devapp-db-credentials devapp-registry-auth -n apps
kubectl get configmap devapp-kibana-saved-objects -n apps
```

Expected state:

- Argo CD: `Synced` and `Healthy`
- `user-app`, `order-app`, and `devapp-web`: desired replicas available
- pods: ready with low/no restart growth
- the latest Argo CD operation includes a successful `devapp-kibana-bootstrap` PostSync hook
- ExternalSecret: `Ready=True`
- observability bootstrap Job: completed
- ingress host: `devapp.swirlit.dev`

Rollout checks:

```bash
kubectl rollout status deployment/user-app -n apps
kubectl rollout status deployment/order-app -n apps
kubectl rollout status deployment/devapp-web -n apps
```

## Health And Readiness

Backend probes:

- `/actuator/health/liveness`: process can continue running
- `/actuator/health/readiness`: process can receive traffic
- `/actuator/health`: aggregate health for internal smoke tests

Frontend probe:

- `/`: NGINX can serve the SPA

Actuator is not exposed through public ingress. Inspect safely through the service or a temporary port-forward:

```bash
kubectl port-forward -n apps svc/user-app 18080:8080
curl http://127.0.0.1:18080/actuator/health
```

Use a separate terminal and stop the port-forward after inspection.

Each service has a custom `database` health contributor that performs a repository count. Redis is also a health contributor in production. Kafka listener health semantics are not yet customized, so use consumer lag and logs as well as application readiness.

## What Healthy Looks Like

Application:

- login discovery and redirect work
- anonymous `/api/users` and `/api/orders` return `401`
- authenticated list requests return `200`
- creating an order returns `201` with `PENDING`
- the order later becomes `APPROVED` for an existing user or `REJECTED` for a missing user
- response headers include `X-Request-Id`

Metrics:

- both backend scrape targets report `up=1`
- request rate matches expected traffic
- 5xx rate is near zero
- response time and Hikari pending connections remain stable
- pod restarts do not grow repeatedly

Events:

- both consumer groups are active when messaging is enabled
- lag returns toward zero
- DLT topics do not grow unexpectedly
- repeated results do not generate invalid-transition loops

## Logs And Request Correlation

UAT/production services write structured JSON to stdout. The cluster log pipeline
collects it into Elasticsearch. The **DevApp — Application Logs** Kibana
dashboard filters only `user-app`, `order-app`, and `devapp-web`; its first
panel contains warnings/errors and its second panel contains the complete recent
stream. The default window is 24 hours with a 30-second refresh.

Useful fields:

- `@timestamp`
- `app`
- `level`
- `logger_name`
- `thread_name`
- `message`
- `requestId` from MDC
- Kubernetes namespace, pod, and container fields added by the collector

Direct logs:

```bash
kubectl logs -n apps deployment/user-app --since=15m
kubectl logs -n apps deployment/order-app --since=15m
kubectl logs -n apps deployment/devapp-web --since=15m
```

Follow a specific pod when diagnosing restart or concurrency behavior:

```bash
kubectl get pods -n apps -l app=order-app
kubectl logs -n apps <order-pod-name> -f
kubectl logs -n apps <order-pod-name> --previous
```

Start with the request ID returned to the caller and search `requestId` in Kibana. Kafka messages do not yet carry that ID or an OpenTelemetry trace context, so continue event diagnosis with order ID, Kafka key, and timestamps.

Do not paste tokens, credentials, complete personal records, or browser test artifacts into incident tickets.

## Metrics Dashboard

`infra/k8s/observability.yaml` provisions panels for:

- application targets up
- HTTP request rate
- HTTP 5xx rate
- average response time
- requests by app/status
- JVM heap
- application CPU
- Hikari active/pending connections
- pod working-set memory
- pod restarts

The dashboard is a visibility baseline, not a complete alerting policy. Event lag, retry, DLT, cache, rate-limit, and SLO alerts are roadmap items.

## Common Incidents

### Pod cannot start because the database secret is missing

Symptoms:

- pod has `CreateContainerConfigError`
- `devapp-db-credentials` Secret absent
- ExternalSecret not ready

Checks:

```bash
kubectl describe externalsecret devapp-db-credentials -n apps
kubectl get secret devapp-db-credentials -n apps
kubectl get clustersecretstore vault-backend
```

Confirm Vault and External Secrets platform health. Do not create an ad hoc plaintext secret in Git.

### Flyway migration or Hibernate validation fails

Symptoms:

- service crashes during startup
- logs mention Flyway checksum/version or schema validation

Checks:

```bash
kubectl logs -n apps deployment/user-app --previous
kubectl logs -n apps deployment/order-app --previous
```

Identify the owning service and its history table:

- users: `flyway_schema_history_users`
- orders: `flyway_schema_history_orders`

Do not modify an applied migration or switch Hibernate to `update`. Correct the migration with a new version, test it on a copy/disposable database, and deploy through GitOps.

### Redis is unavailable

Symptoms:

- readiness may fail through Redis health
- cached resource reads report errors or increased latency
- logs contain Redis connection failures

Checks:

- confirm shared Redis health in `bm-cluster`
- inspect application readiness details internally
- verify `REDIS_HOST`/port and NetworkPolicy behavior

The current production cache manager has no documented stale/local fallback. Restore Redis or deploy an explicitly tested degraded-mode change; do not assume cache annotations automatically fail open.

### Kafka events remain pending

Symptoms:

- orders stay `PENDING`
- consumer lag grows
- DLT records increase

Checks:

- both application pods are ready
- `KAFKA_ENABLED=true`
- bootstrap address is reachable
- user and order consumer groups are active
- request/result topics have expected partitions
- application logs show consume, retry, or publish errors

Interpretation:

- missing user should produce a normal `REJECTED` result
- database/network/runtime failures should retry, not reject
- malformed identity/status/state is non-retryable and moves toward DLT
- result publication is awaited before the request record is acknowledged

The repository does not yet provide an operator-safe replay command. Preserve the original record and headers, identify/fix the cause, and use platform Kafka procedures. Track replay manually to prevent duplicates. Durable replay tooling is in the roadmap.

### An order exists but no request event was published

The current database insert and Kafka send are not atomic. If the service process fails after commit but before a successful publish, an order can remain `PENDING` without a record.

Confirm with order creation logs and Kafka records. There is no automatic reconciliation today. Avoid mutating production records without an incident-specific, reviewed recovery plan. The transactional outbox roadmap item is the permanent fix.

### Authentication redirects or JWT validation fail

Symptoms:

- discovery request fails
- redirect loop
- API returns `401` after apparent login
- logs report issuer mismatch or JWK retrieval failure

Checks:

- public discovery: `https://keycloak.swirlit.dev/auth/realms/swirlit/.well-known/openid-configuration`
- token `iss` equals `https://keycloak.swirlit.dev/auth/realms/swirlit`
- backend public issuer setting matches exactly
- internal JWK URL resolves from the app pod
- canonical Keycloak ingress and the shared internal service are healthy
- system time is synchronized

Do not log or paste the full access token. Decode only non-sensitive header/claim metadata in controlled tooling when necessary.

### Public site works but API path returns the SPA

Check ingress path ordering/routing and the rendered manifest:

```bash
kubectl describe ingress devapp-ingress -n apps
kubectl kustomize infra/k8s | less
```

`/api/users`, `/api/orders`, and documentation paths must route before the `/` catch-all. Keycloak is reached on its own canonical public hostname and is not proxied by the DevApp ingress.

### Prometheus target is down

Checks:

- pod readiness and annotations
- service endpoints
- `allow-application-ingress` NetworkPolicy
- Prometheus namespace/pod labels still match the policy
- `/actuator/prometheus` responds through the cluster service

Do not add Actuator back to public ingress as a shortcut.

### Kibana dashboard is absent or stale

```bash
kubectl get configmap devapp-kibana-saved-objects -n apps
kubectl get application devapp -n infra
```

Argo CD runs `devapp-kibana-bootstrap` as a PostSync hook. The hook waits for
shared Kibana, authenticates with the platform-managed least-privilege dashboard
bootstrap credential, imports the saved objects with overwrite, and is deleted
after a successful import. Inspect the Argo operation and hook logs while a
failed sync is still retained.

### Argo CD reverts a manual change

This is expected: automated self-heal is enabled. Make the change under `infra/k8s/`, commit it, and let Argo CD reconcile.

### GitLab CI published images but deployment did not advance

Inspect the explicit delivery jobs:

- `01-release`: publishes artifacts/images and fails safely if `origin/main` advanced
- `02-deploy`: commits desired image tags, refreshes Argo CD, waits for the exact GitOps revision, and runs smoke checks
- optional `01-e2e`: retains browser acceptance output but cannot suppress release or deploy

Compare:

```bash
git show origin/main:infra/k8s/kustomization.yaml
kubectl get application devapp -n infra -o yaml
```

Never force push over an advanced GitOps commit. Reconcile histories and start the next normal build.

### GitHub and GitLab differ

GitHub pushes start the repository reconciler directly. GitLab branch and tag pushes invoke it through the managed repository-dispatch webhook, including GitLab CI commits marked `[skip ci]`. The workflow normally fast-forwards or merges the mirrors without force pushing, and its monthly schedule renews the GitLab credential before expiry. Inspect the **Sync GitHub and GitLab** workflow and the GitLab webhook delivery log if synchronization fails; a true content conflict or conflicting immutable tag intentionally stops instead of discarding repository history.

## Rate-Limit Incidents

The backend limiter is fixed-window and in-process per replica. It identifies an authenticated principal where available, otherwise the remote address visible to the app.

When a caller receives `429`:

- inspect `RateLimit-*` and `Retry-After`
- correlate with `X-Request-Id`
- confirm traffic source and whether the caller is retrying too aggressively
- do not raise limits until an abuse or capacity assessment is made

With multiple replicas, each pod has independent counters. Global enforcement belongs at Cloudflare/API gateway or a shared store; the current limiter is defense in depth, not a complete DDoS control.

## Scaling Notes

The workloads currently have one replica. Before scaling:

- confirm shared Redis cache behavior
- confirm Kafka consumer groups and partition count meet concurrency goals
- recognize the per-instance rate limiter becomes approximate
- confirm database connection capacity against Hikari pools
- add PodDisruptionBudgets/topology spread as needed
- load test the ingress and service resources
- understand that outbox/inbox gaps become more visible under failures and concurrency

Kafka topics have three partitions, which caps useful parallel consumption per consumer group at three active consumers unless partitioning changes.

## Rollback

Preferred rollback is Git-based:

1. identify the last known good image-tag commit
2. revert or create a reviewed Kustomize tag change in GitLab
3. let Argo CD reconcile
4. wait for exact revision health
5. rerun smoke and browser acceptance

Database migrations require separate care. Application rollback is safe only when the old application remains compatible with the migrated schema. Prefer backward-compatible expand/migrate/contract sequences.

## Backup And Recovery Ownership

Application data resides in shared PostgreSQL. Kafka and Redis have persistent platform storage in relevant environments. Backup schedules, retention, encryption, and restore infrastructure belong to `bm-cluster`.

DevApp still needs application-level recovery validation:

- restore a database copy and run both services with Hibernate validation
- verify both Flyway histories
- validate user/order counts and representative reads
- understand Kafka offset/topic recovery separately from database recovery
- define RPO/RTO and rehearse them

These drills are not automated yet.

## Secret Rotation

Database credential rotation must coordinate:

1. PostgreSQL credential update
2. Vault value update
3. ExternalSecret reconciliation
4. application restart/reconnection
5. health verification

GitLab token rotation must update `apps/devapp/ci` in Vault and verify the GitLab CI ExternalSecret before the next desired-version commit.

Keycloak signing-key rotation should allow token/JWK overlap and verify both backend resource servers. Never rotate by editing the exported disposable realm secret values for a live realm.

## Related Guides

- [Deployment](./deployment.md)
- [Security](./security.md)
- [Testing](./testing.md)
- [Data Model](./data-model.md)
- [Architecture and ADRs](./architecture.md)
