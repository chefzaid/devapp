#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/infra/scripts" "$work/bin"
cp "$root/infra/scripts/ci-quality.sh" "$work/infra/scripts/"
cat > "$work/bin/npm" <<'MOCK'
#!/bin/sh
exit 0
MOCK
cat > "$work/bin/sonar-scanner-npm" <<'MOCK'
#!/bin/sh
mkdir -p .scannerwork
printf 'ceTaskId=test\n' > .scannerwork/report-task.txt
exit "${MOCK_SCANNER_STATUS:-0}"
MOCK
cp "$work/bin/npm" "$work/bin/sleep"
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" CI_COMMIT_BRANCH=main CI_DEFAULT_BRANCH=main
export SONAR_TOKEN=fixture-analysis-token SONAR_HOST_URL=http://sonar.example APP_VERSION=1.0.0
mkdir -p "$work/devapp-web"
bash "$work/infra/scripts/ci-quality.sh" > "$work/success.log" 2>&1
if MOCK_SCANNER_STATUS=1 bash "$work/infra/scripts/ci-quality.sh" > "$work/failure.log" 2>&1; then
  echo 'Scanner failure incorrectly reported success' >&2; exit 1
fi
if SONAR_TOKEN='' bash "$work/infra/scripts/ci-quality.sh" > "$work/missing.log" 2>&1; then
  echo 'Missing credentials incorrectly reported success' >&2; exit 1
fi
printf 'Quality submission success, scanner failure and missing-token behavior verified.\n'
