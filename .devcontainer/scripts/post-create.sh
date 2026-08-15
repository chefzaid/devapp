#!/usr/bin/env bash
set -euo pipefail

cd /workspace/devapp

echo "Installing backend dependencies with Java 25..."
mvn -B -ntp -DskipTests install

echo "Installing Angular dependencies..."
cd devapp-web
CYPRESS_INSTALL_BINARY=0 npm ci
npm run build-prod

echo "DevApp is ready. Run 'mvn test' and 'npm test' to verify changes."
