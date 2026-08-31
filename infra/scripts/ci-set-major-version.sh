#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repository_root"

: "${NEW_MAJOR_VERSION:?Set NEW_MAJOR_VERSION when starting the pipeline (for example: 2)}"
[[ "$NEW_MAJOR_VERSION" =~ ^[1-9][0-9]*$ ]] || {
  echo "NEW_MAJOR_VERSION must be a positive integer" >&2
  exit 2
}

git fetch origin "$CI_DEFAULT_BRANCH"
test "$CI_COMMIT_SHA" = "$(git rev-parse "origin/$CI_DEFAULT_BRANCH")" || {
  echo "The branch advanced after this pipeline was created; start a new pipeline." >&2
  exit 1
}
git checkout -B "$CI_DEFAULT_BRANCH" "origin/$CI_DEFAULT_BRANCH"

current_major="${VERSION%%.*}"
(( NEW_MAJOR_VERSION > current_major )) || {
  echo "NEW_MAJOR_VERSION must be greater than the current major version ($current_major)" >&2
  exit 2
}
next_version="$NEW_MAJOR_VERSION.0.0"
infra/scripts/set-project-version.sh "$next_version"

git config user.name "DevApp GitLab CI"
git config user.email "gitlab-ci@swirlit.dev"
git add VERSION pom.xml devapp-common/pom.xml order-app/pom.xml user-app/pom.xml \
  devapp-web/package.json devapp-web/package-lock.json
git commit -m "chore: set version $next_version [skip ci]"
git push origin "HEAD:$CI_DEFAULT_BRANCH"
printf 'DevApp version is now %s\n' "$next_version"
