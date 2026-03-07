#!/bin/bash

# DevApp Post-Start Script
# This script runs every time the devcontainer starts

set -e

echo "🔄 DevApp container started!"

# Navigate to workspace
cd /workspace/devapp

# Display helpful information
echo ""
echo "🎯 DevApp Development Environment Ready!"
echo ""
echo "📁 Project Structure:"
echo "  devapp-web/     - Angular 21 frontend application"
echo "  user-app/       - Spring Boot 3.5.3 user service"
echo "  order-app/      - Spring Boot 3.5.3 order service"
echo "  devapp-common/  - Shared domain models and utilities"
echo ""
echo "🚀 Quick Start:"
echo "  mask help                                 - Show simplified common commands"
echo "  mask run                                  - Start user-app, order-app, and frontend (default all)"
echo "  mask run front                            - Start Angular dev server"
echo "  mask run user                             - Start User service"
echo "  mask run order                            - Start Order service"
echo "  cd devapp-web && npm start                - Start Angular dev server"
echo "  mvn spring-boot:run -pl user-app         - Start User service"
echo "  mvn spring-boot:run -pl order-app        - Start Order service"
echo "  (Run each in separate terminals for concurrent execution)"
echo ""
echo "🌐 Service URLs (when running):"
echo "  Angular App:    http://localhost:4200"
echo "  User Service:   http://localhost:8080"
echo "  Order Service:  http://localhost:8081"
echo "  H2 Console:     http://localhost:8080/h2-console"
echo "  Keycloak:       http://localhost:8180 (admin/admin)"
echo "  PostgreSQL:     localhost:5432 (for prod profile)"
echo ""
echo "🗄️  Database Configuration:"
echo "  Development:    H2 in-memory (automatic)"
echo "  Production:     PostgreSQL (set SPRING_PROFILES_ACTIVE=prod)"
echo ""
echo "📚 Useful Commands:"
echo "  cd .devcontainer && docker compose --profile local-infra up -d   - Start optional local Kafka/Redis/Keycloak/Postgres"
echo "  mvn clean install           - Build all modules"
echo "  mvn test                    - Run all tests"
echo "  cd devapp-web && npm test   - Run Angular tests"
echo "  cd devapp-web && npm run build - Build Angular for production"
echo "  bash .devcontainer/scripts/kafka-setup.sh setup - Setup Kafka topics"
echo "  bash .devcontainer/scripts/kafka-setup.sh test-order - Send test message"
echo ""
echo "🔧 Development Tools Installed:"
echo "  Java 21, Maven 3.9.x, Node.js 24.x, Angular CLI 21"
echo ""

# Check if services are already running
if pgrep -f "spring-boot:run" > /dev/null; then
    echo "⚠️  Spring Boot services are already running"
fi

if pgrep -f "ng serve" > /dev/null; then
    echo "⚠️  Angular dev server is already running"
fi

echo "✅ Ready for development!"
