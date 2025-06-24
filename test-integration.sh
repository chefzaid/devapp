#!/bin/bash

# DevApp Integration Test Script
# Tests the complete application flow

set -e

echo "🧪 DevApp Integration Test Suite"
echo "================================"

# Configuration
USER_SERVICE="http://localhost:8080"
ORDER_SERVICE="http://localhost:8081"
FRONTEND="http://localhost:4200"
AUTH="admin:password"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
test_passed() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

test_failed() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

test_info() {
    echo -e "${YELLOW}ℹ️  INFO:${NC} $1"
}

# Test service availability
test_service_health() {
    local service_name=$1
    local service_url=$2
    
    test_info "Testing $service_name health..."
    
    if curl -s -u "$AUTH" "$service_url/actuator/health" | grep -q '"status":"UP"'; then
        test_passed "$service_name is healthy"
    else
        test_failed "$service_name health check failed"
    fi
}

# Test API endpoints
test_api_endpoint() {
    local method=$1
    local url=$2
    local expected_status=$3
    local description=$4
    local data=$5
    
    test_info "Testing $description..."
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "%{http_code}" -u "$AUTH" -X "$method" -H "Content-Type: application/json" -d "$data" "$url")
    else
        response=$(curl -s -w "%{http_code}" -u "$AUTH" -X "$method" "$url")
    fi
    
    status_code="${response: -3}"
    
    if [ "$status_code" = "$expected_status" ]; then
        test_passed "$description (HTTP $status_code)"
    else
        test_failed "$description (Expected HTTP $expected_status, got $status_code)"
    fi
}

# Test CORS
test_cors() {
    local service_url=$1
    local service_name=$2
    
    test_info "Testing CORS for $service_name..."
    
    cors_headers=$(curl -s -I -H "Origin: http://localhost:4200" "$service_url/api/users" | grep -i "access-control")
    
    if [ -n "$cors_headers" ]; then
        test_passed "$service_name CORS headers present"
    else
        test_failed "$service_name CORS headers missing"
    fi
}

# Main test execution
echo ""
echo "🔍 Testing Service Health..."
test_service_health "User Service" "$USER_SERVICE"
test_service_health "Order Service" "$ORDER_SERVICE"

echo ""
echo "🔍 Testing User Service API..."
test_api_endpoint "GET" "$USER_SERVICE/api/users" "200" "Get all users"
test_api_endpoint "POST" "$USER_SERVICE/api/users" "200" "Create user" '{"name":"Test User"}'
test_api_endpoint "POST" "$USER_SERVICE/api/users" "400" "Create user with invalid data" '{"name":""}'

echo ""
echo "🔍 Testing Order Service API..."
test_api_endpoint "GET" "$ORDER_SERVICE/api/orders" "200" "Get all orders"
test_api_endpoint "POST" "$ORDER_SERVICE/api/orders" "200" "Create order" '{"productId":12345,"user":{"id":1,"name":"John Doe"},"status":"PENDING"}'

echo ""
echo "🔍 Testing CORS Configuration..."
test_cors "$USER_SERVICE" "User Service"
test_cors "$ORDER_SERVICE" "Order Service"

echo ""
echo "🔍 Testing Frontend Availability..."
if curl -s "$FRONTEND" | grep -q "DevApp"; then
    test_passed "Frontend is accessible"
else
    test_failed "Frontend is not accessible"
fi

echo ""
echo "🔍 Testing Actuator Endpoints..."
test_api_endpoint "GET" "$USER_SERVICE/actuator/info" "200" "User service info endpoint"
test_api_endpoint "GET" "$ORDER_SERVICE/actuator/info" "200" "Order service info endpoint"
test_api_endpoint "GET" "$USER_SERVICE/actuator/metrics" "200" "User service metrics endpoint"
test_api_endpoint "GET" "$ORDER_SERVICE/actuator/metrics" "200" "Order service metrics endpoint"

# Test Kafka integration (if available)
echo ""
echo "🔍 Testing Kafka Integration..."
test_info "Creating test order to trigger Kafka message..."
test_api_endpoint "POST" "$ORDER_SERVICE/api/orders" "200" "Create order (Kafka test)" '{"productId":99999,"user":{"id":1,"name":"Kafka Test User"},"status":"PENDING"}'

# Summary
echo ""
echo "📊 Test Summary"
echo "==============="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}💥 Some tests failed!${NC}"
    exit 1
fi
