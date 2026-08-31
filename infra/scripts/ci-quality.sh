#!/usr/bin/env bash
set -uo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repository_root" || exit 1
quality_dir="$repository_root/quality-reports"
mkdir -p "$quality_dir"

security_status=passed
run_npm_audit() {
  local directory="$1" label="$2"
  if (cd "$directory" && npm audit --audit-level=high --json) \
      > "$quality_dir/npm-audit-$label.json"; then
    printf 'npm security audit passed for %s.\n' "$label"
  else
    security_status=failed
    printf 'npm security audit reported findings for %s; see the quality artifact.\n' "$label" >&2
  fi
}

run_npm_audit devapp-web devapp-web

sonar_status=skipped
if [[ "${CI_COMMIT_BRANCH:-}" == "${CI_DEFAULT_BRANCH:-main}" ]]; then
  if [[ -z "${SONAR_TOKEN:-}" ]]; then
    sonar_status=failed
    printf 'SONAR_TOKEN is unavailable; Sonar analysis was not submitted.\n' >&2
  else
    sonar_version="$APP_VERSION"
    if sonar-scanner-npm \
      -Dsonar.host.url="$SONAR_HOST_URL" \
      -Dsonar.token="$SONAR_TOKEN" \
      -Dsonar.projectVersion="$sonar_version" \
      -Dsonar.qualitygate.wait=false; then
      sonar_status=submitted
      printf 'Sonar analysis submitted without waiting on or enforcing the quality gate.\n'
    else
      sonar_status=failed
      printf 'Sonar analysis failed to submit; release/deploy remains independent.\n' >&2
    fi
  fi
else
  printf 'SonarQube Community Build analyzes the default branch only; local quality reports were still generated for %s.\n' \
    "${CI_COMMIT_BRANCH:-detached}"
fi

printf 'SONAR_REPORT_STATUS=%s\nSECURITY_REPORT_STATUS=%s\n' \
  "$sonar_status" "$security_status" > "$quality_dir/quality.env"
printf 'Quality reporting complete: sonar=%s security=%s.\n' "$sonar_status" "$security_status"
