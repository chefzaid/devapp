#!/bin/bash

# Kafka Setup and Management Script
# This script provides utilities for managing Kafka topics and testing connectivity

set -e

KAFKA_CONTAINER="devapp-kafka-1"
KAFKA_BROKER="localhost:9092"
ORDER_TOPIC="order_topic"

echo "🔧 Kafka Management Script"
echo ""

# Function to check if Kafka is running
check_kafka() {
    echo "🔍 Checking Kafka connectivity..."
    if docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_BROKER --list > /dev/null 2>&1; then
        echo "✅ Kafka is running and accessible"
        return 0
    else
        echo "❌ Kafka is not accessible"
        return 1
    fi
}

# Function to create topics
create_topics() {
    echo "📝 Creating Kafka topics..."
    
    # Create order_topic if it doesn't exist
    if ! docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_BROKER --list | grep -q "^${ORDER_TOPIC}$"; then
        echo "Creating topic: $ORDER_TOPIC"
        docker exec $KAFKA_CONTAINER kafka-topics \
            --bootstrap-server $KAFKA_BROKER \
            --create \
            --topic $ORDER_TOPIC \
            --partitions 3 \
            --replication-factor 1
        echo "✅ Topic $ORDER_TOPIC created"
    else
        echo "✅ Topic $ORDER_TOPIC already exists"
    fi
}

# Function to list topics
list_topics() {
    echo "📋 Listing Kafka topics..."
    docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_BROKER --list
}

# Function to describe topics
describe_topics() {
    echo "📊 Describing Kafka topics..."
    docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_BROKER --describe
}

# Function to test producer
test_producer() {
    echo "🚀 Testing Kafka producer..."
    echo "Type messages and press Enter. Type 'exit' to quit."
    docker exec -it $KAFKA_CONTAINER kafka-console-producer \
        --bootstrap-server $KAFKA_BROKER \
        --topic $ORDER_TOPIC
}

# Function to test consumer
test_consumer() {
    echo "👂 Testing Kafka consumer..."
    echo "Listening for messages on topic: $ORDER_TOPIC"
    echo "Press Ctrl+C to stop"
    docker exec -it $KAFKA_CONTAINER kafka-console-consumer \
        --bootstrap-server $KAFKA_BROKER \
        --topic $ORDER_TOPIC \
        --from-beginning
}

# Function to send test order message
send_test_order() {
    echo "📦 Sending test order message..."
    local test_message='{"id":999,"productId":1001,"status":"PENDING","user":{"id":1,"name":"Test User"}}'
    echo "$test_message" | docker exec -i $KAFKA_CONTAINER kafka-console-producer \
        --bootstrap-server $KAFKA_BROKER \
        --topic $ORDER_TOPIC
    echo "✅ Test order message sent"
}

# Function to show consumer groups
show_consumer_groups() {
    echo "👥 Listing consumer groups..."
    docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER --list
}

# Function to describe consumer group
describe_consumer_group() {
    local group_id=${1:-"group_id"}
    echo "📊 Describing consumer group: $group_id"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --bootstrap-server $KAFKA_BROKER \
        --group $group_id \
        --describe
}

# Main menu
case "${1:-menu}" in
    "check")
        check_kafka
        ;;
    "setup")
        check_kafka && create_topics
        ;;
    "list")
        list_topics
        ;;
    "describe")
        describe_topics
        ;;
    "producer")
        test_producer
        ;;
    "consumer")
        test_consumer
        ;;
    "test-order")
        send_test_order
        ;;
    "groups")
        show_consumer_groups
        ;;
    "group-info")
        describe_consumer_group "${2:-group_id}"
        ;;
    "menu"|*)
        echo "Available commands:"
        echo "  check       - Check Kafka connectivity"
        echo "  setup       - Create required topics"
        echo "  list        - List all topics"
        echo "  describe    - Describe all topics"
        echo "  producer    - Start interactive producer"
        echo "  consumer    - Start interactive consumer"
        echo "  test-order  - Send a test order message"
        echo "  groups      - List consumer groups"
        echo "  group-info  - Describe consumer group"
        echo ""
        echo "Usage: $0 <command>"
        echo "Example: $0 setup"
        ;;
esac
