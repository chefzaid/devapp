#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repository_root"

version="${1:-}"
[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
  echo "Usage: $0 <major.minor.patch>" >&2
  exit 2
}

printf '%s\n' "$version" > VERSION
mvn --batch-mode --quiet org.codehaus.mojo:versions-maven-plugin:2.19.1:set \
  -DnewVersion="$version" -DprocessAllModules=true -DgenerateBackupPoms=false

for manifest in devapp-web/package.json devapp-web/package-lock.json; do
  expected_replacements=1
  [[ "$manifest" == *package-lock.json ]] && expected_replacements=2
  temporary_file="$(mktemp "${manifest}.XXXXXX")"
  awk -v version="$version" -v expected="$expected_replacements" '
    BEGIN { updated = 0 }
    {
      if (updated < expected && $0 ~ /^[[:space:]]*"version"[[:space:]]*:/) {
        sub(/"version"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"version\": \"" version "\"")
        updated++
      }
      print
    }
    END {
      if (updated != expected) {
        printf "Expected %d version fields, updated %d\n", expected, updated > "/dev/stderr"
        exit 1
      }
    }
  ' "$manifest" > "$temporary_file"
  chmod 0644 "$temporary_file"
  mv "$temporary_file" "$manifest"
done
