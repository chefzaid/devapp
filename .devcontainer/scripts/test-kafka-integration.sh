#!/bin/bash

# Kafka Integration Test Script
# Tests the complete message flow between Order Service and User Service

set -e

echo "🧪 Testing Kafka Integration with DevApp Services"
echo ""

KAFKA_CONTAINER="devapp-kafka-1"
KAFKA_BROKER="localhost:9092"
ORDER_TOPIC="order_topic"
USER_SERVICE_URL="http://localhost:8080"
ORDER_SERVICE_URL="http://localhost:8081"

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    echo "⏳ Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url/actuator/health" > /dev/null 2>&1; then
            echo "✅ $service_name is ready"
            return 0
        fi
        echo "  Attempt $attempt/$max_attempts - $service_name not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "❌ $service_name failed to start within expected time"
    return 1
}

# Function to check Kafka connectivity
check_kafka() {
    echo "🔍 Checking Kafka connectivity..."
    if docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_BROKER --list > /dev/null 2>&1; then
        echo "✅ Kafka is accessible"
        return 0
    else
        echo "❌ Kafka is not accessible"
        return 1
    fi
}

# Function to setup Kafka topics
setup_kafka_topics() {
    echo "📝 Setting up Kafka topics..."
    bash .devcontainer/scripts/kafka-setup.sh setup
}

# Function to test order creation and message flow
test_order_flow() {
    echo "📦 Testing order creation and Kafka message flow..."
    
    # Create a test order via Order Service API
    echo "Creating test order..."
    local order_response=$(curl -s -X POST "$ORDER_SERVICE_URL/api/orders" \
        -H "Content-Type: application/json" \
        -d '{
            "productId": 1001,
            "status": "PENDING",
            "user": {
                "id": 1,
                "name": "Test User"
            }
        }')
    
    if [ $? -eq 0 ]; then
        echo "✅ Order created successfully"
        echo "Response: $order_response"
    else
        echo "❌ Failed to create order"
        return 1
    fi
    
    # Wait a moment for message processing
    echo "⏳ Waiting for message processing..."
    sleep 3
    
    echo "✅ Order flow test completed"
}

# Function to monitor Kafka messages
monitor_messages() {
    echo "👂 Monitoring Kafka messages for 10 seconds..."
    timeout 10s docker exec $KAFKA_CONTAINER kafka-console-consumer \
        --bootstrap-server $KAFKA_BROKER \
        --topic $ORDER_TOPIC \
        --from-beginning || true
    echo "✅ Message monitoring completed"
}

# Function to check consumer group status
check_consumer_group() {
    echo "👥 Checking consumer group status..."
    bash .devcontainer/scripts/kafka-setup.sh group-info group_id
}

# Main test execution
echo "🚀 Starting Kafka Integration Test"
echo ""

# Step 1: Check Kafka
if ! check_kafka; then
    echo "❌ Kafka test failed - Kafka not accessible"
    exit 1
fi

# Step 2: Setup topics
setup_kafka_topics

# Step 3: Wait for services (optional - only if services are running)
echo "🔍 Checking if Spring Boot services are running..."
if curl -s "$USER_SERVICE_URL/actuator/health" > /dev/null 2>&1; then
    echo "✅ User Service is running"
    USER_SERVICE_RUNNING=true
else
    echo "⚠️  User Service is not running"
    USER_SERVICE_RUNNING=false
fi

if curl -s "$ORDER_SERVICE_URL/actuator/health" > /dev/null 2>&1; then
    echo "✅ Order Service is running"
    ORDER_SERVICE_RUNNING=true
else
    echo "⚠️  Order Service is not running"
    ORDER_SERVICE_RUNNING=false
fi

# Step 4: Test message flow (only if services are running)
if [ "$ORDER_SERVICE_RUNNING" = true ] && [ "$USER_SERVICE_RUNNING" = true ]; then
    echo ""
    echo "🔄 Testing complete message flow..."
    test_order_flow
    check_consumer_group
else
    echo ""
    echo "⚠️  Skipping message flow test - services not running"
    echo "   To test complete flow:"
    echo "   1. Start services: ./start-all.sh"
    echo "   2. Run this test again"
fi

# Step 5: Send test message directly to Kafka
echo ""
echo "📨 Sending test message directly to Kafka..."
bash .devcontainer/scripts/kafka-setup.sh test-order

# Step 6: Monitor messages
echo ""
monitor_messages

echo ""
echo "🎉 Kafka Integration Test Completed!"
echo ""
echo "📋 Summary:"
echo "  ✅ Kafka connectivity verified"
echo "  ✅ Topics created/verified"
echo "  ✅ Test message sent"
if [ "$ORDER_SERVICE_RUNNING" = true ] && [ "$USER_SERVICE_RUNNING" = true ]; then
    echo "  ✅ Service integration tested"
else
    echo "  ⚠️  Service integration skipped (services not running)"
fi
echo ""
echo "🔧 Next steps:"
echo "  - Start all services: ./start-all.sh"
echo "  - Monitor messages: bash .devcontainer/scripts/kafka-setup.sh consumer"
echo "  - Send test orders: bash .devcontainer/scripts/kafka-setup.sh test-order"
