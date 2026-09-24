#!/usr/bin/env bash
# Mark onboarding publications so an interrupted operator can identify their release.
set -euo pipefail
: "${1:?A deployment commit message is required}"
arguments=(-m "$1")
if [[ -n "${DEPLOYMENT_RUNTIME_REVISION:-}" ]]; then
  [[ "$DEPLOYMENT_RUNTIME_REVISION" =~ ^[a-f0-9]{40}$ &&
     "${DEPLOYMENT_ENVIRONMENT:-}" =~ ^(int|uat|prod)$ &&
     "${CI_PIPELINE_ID:-}" =~ ^[0-9]+$ && "${CI_COMMIT_SHA:-}" =~ ^[a-f0-9]{40}$ &&
     ( "${APP_VERSION:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ||
       ( "$DEPLOYMENT_ENVIRONMENT" == int && "${APP_VERSION:-}" == "snapshot-$CI_COMMIT_SHA-$CI_PIPELINE_ID" ) ) ]] || {
    echo 'Deployment publication requires its environment, runtime revision, release and pipeline identity' >&2
    exit 1
  }
  arguments+=(--allow-empty --trailer "Deployment-Pipeline: $CI_PIPELINE_ID"
    --trailer "Deployment-Source: $CI_COMMIT_SHA" --trailer "Deployment-Environment: $DEPLOYMENT_ENVIRONMENT"
    --trailer "Deployment-Release: $APP_VERSION" --trailer "Deployment-Runtime: $DEPLOYMENT_RUNTIME_REVISION")
fi
if [[ "${APP_ONBOARDING:-false}" == true ]]; then
  [[ "${CI_PIPELINE_ID:-}" =~ ^[0-9]+$ && "${CI_COMMIT_SHA:-}" =~ ^[a-f0-9]{40}$ ]] || {
    echo 'Onboarding publication requires its pipeline ID and source revision' >&2
    exit 1
  }
  arguments+=(--allow-empty
    --trailer "Onboarding-Pipeline: $CI_PIPELINE_ID"
    --trailer "Onboarding-Source: $CI_COMMIT_SHA")
fi
git commit "${arguments[@]}"
