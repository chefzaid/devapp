# Infrastructure

DevApp infrastructure assets are grouped by execution boundary:

| Directory | Purpose |
|---|---|
| `ansible/` | optional manual application of the committed Kustomize desired state |
| `compose/` | complete local stack and the Playwright acceptance override |
| `keycloak/` | disposable local realm import |
| `k8s/` | application manifests, Kustomize, Argo CD, Jenkins bootstrap, secrets, policies, and observability |
| `scripts/` | CI/CD bootstrap, immutable image-tag update, and Mask Java helper |

Common entry points:

```bash
docker compose -f infra/compose/compose.yaml up --build -d
kubectl kustomize infra/k8s
./infra/scripts/configure-cicd.sh
ansible-playbook -i infra/ansible/inventory infra/ansible/deploy.yml
```

`Jenkinsfile` and `maskfile.md` remain at the repository root because their tools discover those conventional names there. Application source/build files also remain outside `infra/`.

See [Deployment](../docs/deployment.md), [Development](../docs/development.md), and [Operations](../docs/operations.md) for complete workflows.
