#!/bin/bash

# DevApp Setup Test Script
# Verifies that all tools and dependencies are properly installed

set -e

echo "🧪 Testing DevApp development environment setup..."
echo ""

# Test Java installation
echo "☕ Testing Java..."
java -version
echo "✅ Java OK"
echo ""

# Test Maven installation
echo "📦 Testing Maven..."
mvn -version
echo "✅ Maven OK"
echo ""

# Test Node.js installation
echo "🟢 Testing Node.js..."
node -v
npm -v
echo "✅ Node.js OK"
echo ""

# Test Angular CLI
echo "🅰️ Testing Angular CLI..."
ng version --skip-git
echo "✅ Angular CLI OK"
echo ""

# Test project structure
echo "📁 Testing project structure..."
if [ -d "/workspace/devapp/devapp-web" ]; then
    echo "✅ Angular project found"
else
    echo "❌ Angular project not found"
    exit 1
fi

if [ -d "/workspace/devapp/user-app" ]; then
    echo "✅ User app found"
else
    echo "❌ User app not found"
    exit 1
fi

if [ -d "/workspace/devapp/order-app" ]; then
    echo "✅ Order app found"
else
    echo "❌ Order app not found"
    exit 1
fi

if [ -d "/workspace/devapp/devapp-common" ]; then
    echo "✅ Common module found"
else
    echo "❌ Common module not found"
    exit 1
fi

echo ""

# Test Maven build
echo "🔨 Testing Maven build..."
cd /workspace/devapp
mvn clean compile -q
echo "✅ Maven build OK"
echo ""

# Test Angular dependencies
echo "📦 Testing Angular dependencies..."
cd devapp-web
if [ -d "node_modules" ]; then
    echo "✅ Node modules installed"
else
    echo "⚠️ Node modules not found, installing..."
    npm install
    echo "✅ Node modules installed"
fi
cd ..
echo ""

# Test database scripts
echo "🗄️ Testing database scripts..."
if [ -f "devapp-common/src/main/resources/db/schema.sql" ]; then
    echo "✅ Centralized schema.sql found"
else
    echo "❌ Centralized schema.sql not found"
    exit 1
fi

if [ -f "devapp-common/src/main/resources/db/data.sql" ]; then
    echo "✅ Centralized data.sql found"
else
    echo "❌ Centralized data.sql not found"
    exit 1
fi

echo ""

# Test helper scripts
echo "📝 Testing helper scripts..."
if [ -f "start-all.sh" ]; then
    echo "✅ start-all.sh found"
else
    echo "❌ start-all.sh not found"
fi

if [ -f "stop-all.sh" ]; then
    echo "✅ stop-all.sh found"
else
    echo "❌ stop-all.sh not found"
fi

echo ""
echo "🎉 All tests passed! DevApp development environment is ready."
echo ""
echo "🚀 Next steps:"
echo "  1. Run './start-all.sh' to start all services"
echo "  2. Open http://localhost:4200 for Angular app"
echo "  3. Open http://localhost:8080 for User service"
echo "  4. Open http://localhost:8081 for Order service"
echo "  5. Open http://localhost:8080/h2-console for database"
