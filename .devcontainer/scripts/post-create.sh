#!/bin/bash

# DevApp Post-Create Setup Script
# This script runs after the devcontainer is created

set -e

echo "🚀 Setting up DevApp development environment..."

# Navigate to workspace
cd /workspace/devapp

# Ensure Maven directory has correct permissions
echo "🔧 Setting up Maven permissions..."
mkdir -p ~/.m2/repository
chmod -R 755 ~/.m2

# Install Maven dependencies
echo "📦 Installing Maven dependencies..."
mvn clean install -DskipTests -q

# Install Node.js dependencies for Angular app
echo "📦 Installing Node.js dependencies..."
cd devapp-web
npm install

# Build Angular application
echo "🔨 Building Angular application..."
npm run build

# Go back to root
cd ..

# Create development helper scripts
echo "📝 Creating development helper scripts..."

# Create start-all script
cat > start-all.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting all DevApp services..."

# Function to run command in background and track PID
run_bg() {
    echo "Starting: $1"
    $2 &
    echo $! > "/tmp/$1.pid"
}

# Start Angular dev server
cd devapp-web
run_bg "angular" "npm start"
cd ..

# Start User App (Spring Boot)
run_bg "user-app" "mvn spring-boot:run -pl user-app -Dspring-boot.run.jvmArguments='-Dserver.port=8080'"

# Start Order App (Spring Boot) 
run_bg "order-app" "mvn spring-boot:run -pl order-app -Dspring-boot.run.jvmArguments='-Dserver.port=8081'"

echo "✅ All services started!"
echo "📱 Angular: http://localhost:4200"
echo "👤 User App: http://localhost:8080"
echo "📦 Order App: http://localhost:8081"
echo "🗄️  H2 Console: http://localhost:8080/h2-console (or 8081)"
echo ""
echo "To stop all services, run: ./stop-all.sh"
EOF

# Create stop-all script
cat > stop-all.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping all DevApp services..."

# Function to stop service by PID file
stop_service() {
    if [ -f "/tmp/$1.pid" ]; then
        PID=$(cat "/tmp/$1.pid")
        if ps -p $PID > /dev/null; then
            echo "Stopping $1 (PID: $PID)"
            kill $PID
            rm "/tmp/$1.pid"
        else
            echo "$1 was not running"
            rm -f "/tmp/$1.pid"
        fi
    else
        echo "$1 PID file not found"
    fi
}

stop_service "angular"
stop_service "user-app"
stop_service "order-app"

# Also kill any remaining Java/Node processes
pkill -f "spring-boot:run" || true
pkill -f "ng serve" || true

echo "✅ All services stopped!"
EOF

# Create individual service scripts
cat > start-angular.sh << 'EOF'
#!/bin/bash
echo "🅰️ Starting Angular development server..."
cd devapp-web
npm start
EOF

cat > start-user-app.sh << 'EOF'
#!/bin/bash
echo "👤 Starting User App (Spring Boot)..."
mvn spring-boot:run -pl user-app -Dspring-boot.run.jvmArguments="-Dserver.port=8080"
EOF

cat > start-order-app.sh << 'EOF'
#!/bin/bash
echo "📦 Starting Order App (Spring Boot)..."
mvn spring-boot:run -pl order-app -Dspring-boot.run.jvmArguments="-Dserver.port=8081"
EOF

# Create Kafka management script
cat > kafka-setup.sh << 'EOF'
#!/bin/bash
# Kafka management script - see .devcontainer/scripts/kafka-setup.sh for full version
echo "🔧 Kafka Management"
echo "For full Kafka management, use: bash .devcontainer/scripts/kafka-setup.sh"
echo ""
echo "Quick commands:"
echo "  bash .devcontainer/scripts/kafka-setup.sh setup     - Create topics"
echo "  bash .devcontainer/scripts/kafka-setup.sh check     - Check connectivity"
echo "  bash .devcontainer/scripts/kafka-setup.sh test-order - Send test message"
EOF

# Make scripts executable
chmod +x *.sh
chmod +x .devcontainer/scripts/*.sh

echo "✅ DevApp development environment setup complete!"
echo ""
echo "🎯 Quick start commands:"
echo "  ./start-all.sh     - Start all services"
echo "  ./stop-all.sh      - Stop all services"
echo "  ./start-angular.sh - Start only Angular"
echo "  ./start-user-app.sh - Start only User App"
echo "  ./start-order-app.sh - Start only Order App"
echo "  ./kafka-setup.sh   - Kafka management (see .devcontainer/scripts/kafka-setup.sh)"
echo ""
echo "🌐 Service URLs:"
echo "  Angular: http://localhost:4200"
echo "  User App: http://localhost:8080"
echo "  Order App: http://localhost:8081"
echo "  H2 Console: http://localhost:8080/h2-console"
echo "  Kafka: localhost:9092"
echo "  Zookeeper: localhost:2181"
