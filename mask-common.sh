#!/bin/bash

use_java_21_if_available() {
  if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ] && "$JAVA_HOME/bin/java" -version 2>&1 | head -n 1 | grep -Eq '^(openjdk|java) version "21\.'; then
    export PATH="$JAVA_HOME/bin:$PATH"
    return
  fi

  for candidate in \
    /usr/lib/jvm/java-21-openjdk-amd64 \
    /usr/lib/jvm/java-21-openjdk-arm64 \
    /usr/lib/jvm/temurin-21-jdk-amd64 \
    /usr/lib/jvm/temurin-21-jdk-arm64; do
    if [ -x "$candidate/bin/java" ]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:$PATH"
      return
    fi
  done

  if command -v java >/dev/null 2>&1 && java -version 2>&1 | head -n 1 | grep -Eq '^(openjdk|java) version "21\.'; then
    JAVA_BIN="$(command -v java)"
    export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$JAVA_BIN")")")"
    export PATH="$JAVA_HOME/bin:$PATH"
    return
  fi

  if command -v update-alternatives >/dev/null 2>&1; then
    JAVA21_BIN="$(update-alternatives --list java 2>/dev/null | grep '21' | head -n 1)"
    if [ -n "${JAVA21_BIN:-}" ]; then
      export JAVA_HOME="$(dirname "$(dirname "$JAVA21_BIN")")"
      export PATH="$JAVA_HOME/bin:$PATH"
    fi
  fi
}
