#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repository_root"

phase="${1:-all}"

prepare_sources() {
  infra/scripts/set-project-version.sh "$APP_VERSION"
}

build_application() {
  kubectl kustomize infra/k8s >/dev/null
  kubectl apply --dry-run=client --validate=false \
    -f infra/argocd/application.yaml >/dev/null
  mvn --batch-mode clean package -DskipTests \
    -Dhttp.proxyHost= -Dhttps.proxyHost=

  pushd devapp-web >/dev/null
  npm ci
  npm run test:e2e:types
  npm run build-prod
  tar -czf "devapp-web-${APP_VERSION}.tar.gz" -C dist devapp-web
  popd >/dev/null
}

test_application() {
  mvn --batch-mode clean verify -Djacoco.haltOnFailure=false \
    -Dhttp.proxyHost= -Dhttps.proxyHost=

  pushd devapp-web >/dev/null
  npm ci
  npm run test:ci -- --coverage-reporters=cobertura
  coverage_report="coverage/devapp-web/cobertura-coverage.xml"
  [[ -s "$coverage_report" ]]
  coverage_line_rate="$(awk 'match($0, /line-rate="[^"]+"/) { print substr($0, RSTART + 11, RLENGTH - 12); exit }' "$coverage_report")"
  [[ "$coverage_line_rate" =~ ^[0-9]+([.][0-9]+)?$ ]]
  awk -v rate="$coverage_line_rate" 'BEGIN { printf "FRONTEND_COVERAGE=%.2f%%\n", rate * 100 }'
  popd >/dev/null

  python3 infra/scripts/ci-coverage-check.py \
    ./*/target/site/jacoco/jacoco.xml \
    devapp-web/coverage/devapp-web/cobertura-coverage.xml
}

prepare_sources
case "$phase" in
  build)
    build_application
    ;;
  test)
    test_application
    ;;
  all)
    build_application
    test_application
    ;;
  *)
    printf 'Usage: %s [build|test|all]\n' "$0" >&2
    exit 2
    ;;
esac
