#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repository_root"

mode="${1:-verify}"
: "${APP_VERSION:?APP_VERSION is required}"
: "${REGISTRY_PUSH_HOST:?REGISTRY_PUSH_HOST is required}"
: "${KANIKO_EXECUTOR:?KANIKO_EXECUTOR is required}"

kaniko_options=()
case "$mode" in
  verify)
    kaniko_options+=(--no-push --cache=false)
    ;;
  publish)
    : "${CI_REGISTRY_USER:?CI_REGISTRY_USER is required}"
    : "${CI_REGISTRY_PASSWORD:?CI_REGISTRY_PASSWORD is required}"
    mkdir -p /kaniko/.docker
    jq -n --arg registry "$REGISTRY_PUSH_HOST" --arg username "$CI_REGISTRY_USER" \
      --arg password "$CI_REGISTRY_PASSWORD" \
      '{auths:{($registry):{username:$username,password:$password}}}' \
      > /kaniko/.docker/config.json
    export DOCKER_CONFIG=/kaniko/.docker
    ;;
  *)
    printf 'Usage: %s [verify|publish]\n' "$0" >&2
    exit 2
    ;;
esac

build_image() {
  local name="$1" context="$2" dockerfile="$3"
  local repository="$REGISTRY_PUSH_HOST/$CI_PROJECT_PATH/$name"
  local options=(
    --context "dir://$context"
    --dockerfile "$dockerfile"
    --destination "$repository:$APP_VERSION"
    --insecure-registry "$REGISTRY_PUSH_HOST"
  )
  if [[ "$mode" == publish ]]; then
    options+=(--cache=true --cache-repo "$repository/cache" --cache-ttl=720h)
  else
    options+=("${kaniko_options[@]}")
  fi
  "$KANIKO_EXECUTOR" "${options[@]}"
}

build_image user-app "$repository_root" "$repository_root/user-app/Dockerfile.runtime"
build_image order-app "$repository_root" "$repository_root/order-app/Dockerfile.runtime"
build_image devapp-web "$repository_root/devapp-web" "$repository_root/devapp-web/Dockerfile.runtime"
