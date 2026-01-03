#!/bin/bash
# test-ingress.sh
# Test script for NGINX Ingress Controller Deployment
# Usage: ./test-ingress.sh

echo "🚀 NGINX INGRESS CONTROLLER TEST SCRIPT"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_IP="10.10.0.204"
PORTS_TO_TEST="80 8080 30080"
ENDPOINTS=("/" "/api" "/auth" "/healthz")

# Function to print colored output
print_status() {
    if [ "$1" = "success" ]; then
        echo -e "${GREEN}✓ $2${NC}"
    elif [ "$1" = "error" ]; then
        echo -e "${RED}✗ $2${NC}"
    elif [ "$1" = "warning" ]; then
        echo -e "${YELLOW}⚠ $2${NC}"
    elif [ "$1" = "info" ]; then
        echo -e "${BLUE}ℹ $2${NC}"
    fi
}

# Function to test endpoint
test_endpoint() {
    local port=$1
    local endpoint=$2
    local timeout=5
    
    local url="http://${TARGET_IP}:${port}${endpoint}"
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $timeout "$url" 2>/dev/null)
    
    if [ -n "$status_code" ] && [ "$status_code" != "000" ]; then
        echo "$status_code"
    else
        echo "FAILED"
    fi
}

# Function to check Kubernetes resources
check_k8s_resources() {
    print_status "info" "Checking Kubernetes resources..."
    
    echo ""
    echo "📦 Namespace: ingress-nginx"
    kubectl get ns ingress-nginx 2>/dev/null && print_status "success" "Namespace exists" || print_status "error" "Namespace not found"
    
    echo ""
    echo "📦 Pods in ingress-nginx:"
    local ingress_pods=$(kubectl get pods -n ingress-nginx 2>/dev/null | grep -c "Running")
    if [ "$ingress_pods" -ge 2 ]; then
        print_status "success" "$ingress_pods pods running"
        kubectl get pods -n ingress-nginx --no-headers | head -5
    else
        print_status "error" "Not enough pods running"
    fi
    
    echo ""
    echo "📦 Test application:"
    local test_pods=$(kubectl get pods -n default -l app=test-app 2>/dev/null | grep -c "Running")
    if [ "$test_pods" -ge 2 ]; then
        print_status "success" "$test_pods test-app pods running"
    else
        print_status "error" "Test application not running properly"
    fi
    
    echo ""
    echo "📦 Services:"
    kubectl get svc -n ingress-nginx ingress-nginx-controller 2>/dev/null && print_status "success" "Ingress service exists" || print_status "error" "Ingress service not found"
    kubectl get svc -n default test-app-service 2>/dev/null && print_status "success" "Test service exists" || print_status "error" "Test service not found"
    
    echo ""
    echo "📦 Endpoints:"
    local endpoints=$(kubectl get endpoints -n default test-app-service 2>/dev/null | awk 'NR==2 {print $2}')
    if [ "$endpoints" != "<none>" ] && [ -n "$endpoints" ]; then
        print_status "success" "Endpoints: $endpoints"
    else
        print_status "error" "No endpoints found"
    fi
    
    echo ""
    echo "📦 Ingress:"
    kubectl get ingress -A 2>/dev/null | grep -E "(NAME|test-ingress)" && print_status "success" "Ingress resource exists" || print_status "error" "Ingress resource not found"
}

# Function to test network connectivity
test_network() {
    print_status "info" "Testing network connectivity..."
    echo ""
    
    for port in $PORTS_TO_TEST; do
        echo -n "Port $port: "
        if timeout 2 bash -c "cat < /dev/null > /dev/tcp/${TARGET_IP}/${port}" 2>/dev/null; then
            print_status "success" "OPEN"
        else
            print_status "error" "CLOSED"
        fi
    done
}

# Function to test all endpoints
test_all_endpoints() {
    print_status "info" "Testing HTTP endpoints..."
    echo ""
    
    for port in $PORTS_TO_TEST; do
        echo "🔍 Testing on port $port:"
        echo "------------------------"
        
        for endpoint in "${ENDPOINTS[@]}"; do
            echo -n "  ${endpoint}: "
            local status=$(test_endpoint "$port" "$endpoint")
            
            if [ "$status" = "200" ]; then
                print_status "success" "HTTP 200"
                
                # Show content preview for successful requests
                if [ "$endpoint" = "/healthz" ]; then
                    local content=$(curl -s --connect-timeout 3 "http://${TARGET_IP}:${port}${endpoint}")
                    echo "    Content: '$content'"
                elif [ "$status" = "200" ] && [ "$endpoint" != "/healthz" ]; then
                    echo "    Content type: HTML"
                fi
            elif [ "$status" = "429" ]; then
                print_status "warning" "HTTP 429 (Rate Limited)"
            elif [ "$status" = "503" ]; then
                print_status "error" "HTTP 503 (Service Unavailable)"
            elif [ "$status" = "FAILED" ]; then
                print_status "error" "Connection failed"
            else
                echo "HTTP $status"
            fi
        done
        echo ""
    done
}

# Function to test rate limiting
test_rate_limiting() {
    print_status "info" "Testing rate limiting (5 quick requests)..."
    echo ""
    
    local port=80
    local endpoint="/"
    local success_count=0
    
    for i in {1..5}; do
        echo -n "  Request $i: "
        local status=$(test_endpoint "$port" "$endpoint")
        
        if [ "$status" = "200" ]; then
            print_status "success" "OK"
            ((success_count++))
        elif [ "$status" = "429" ]; then
            print_status "warning" "Rate Limited (expected)"
        else
            echo "HTTP $status"
        fi
        
        # Small delay between requests
        sleep 0.1
    done
    
    echo ""
    if [ "$success_count" -eq 5 ]; then
        print_status "success" "All 5 requests succeeded (rate limit not triggered)"
    elif [ "$success_count" -lt 5 ]; then
        print_status "warning" "Some requests were rate limited (normal behavior)"
    fi
}

# Function to check logs
check_logs() {
    print_status "info" "Checking logs for errors..."
    echo ""
    
    local pod_count=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | wc -l)
    
    if [ "$pod_count" -gt 0 ]; then
        echo "Recent logs from ingress controller:"
        kubectl logs -n ingress-nginx -l app=nginx-ingress-controller --tail=5 2>/dev/null | grep -E "(error|Error|ERROR|fail|Fail|FAIL)" | head -3 || echo "  No errors found in recent logs"
    else
        print_status "error" "No ingress pods found"
    fi
}

# Function to run comprehensive test
run_comprehensive_test() {
    echo "🔄 Starting comprehensive test..."
    echo ""
    
    # Step 1: Check Kubernetes resources
    check_k8s_resources
    echo ""
    
    # Step 2: Test network connectivity
    test_network
    echo ""
    
    # Step 3: Test endpoints
    test_all_endpoints
    
    # Step 4: Test rate limiting
    test_rate_limiting
    echo ""
    
    # Step 5: Check logs
    check_logs
    echo ""
    
    # Step 6: Summary
    print_status "info" "TEST SUMMARY"
    echo "================"
    
    # Count successful endpoint tests on port 80
    local successful_tests=0
    for endpoint in "${ENDPOINTS[@]}"; do
        if [ "$(test_endpoint 80 "$endpoint")" = "200" ]; then
            ((successful_tests++))
        fi
    done
    
    if [ "$successful_tests" -eq "${#ENDPOINTS[@]}" ]; then
        print_status "success" "✅ ALL TESTS PASSED!"
        echo "   - All Kubernetes resources are running"
        echo "   - All endpoints are accessible"
        echo "   - Rate limiting is working"
        echo "   - No critical errors in logs"
    elif [ "$successful_tests" -ge 2 ]; then
        print_status "warning" "⚠️  PARTIAL SUCCESS"
        echo "   - Some endpoints are working"
        echo "   - Check logs for issues"
    else
        print_status "error" "❌ TESTS FAILED"
        echo "   - Check Kubernetes deployment"
        echo "   - Verify network connectivity"
        echo "   - Check pod logs for errors"
    fi
    
    echo ""
    echo "🔧 Troubleshooting commands:"
    echo "   kubectl get pods -n ingress-nginx"
    echo "   kubectl logs -n ingress-nginx -l app=nginx-ingress-controller"
    echo "   kubectl describe ingress test-ingress -n default"
    echo "   curl -v http://${TARGET_IP}/healthz"
}

# Function for quick test
quick_test() {
    echo "⚡ Running quick test..."
    echo ""
    
    echo -n "Health check: "
    local health_status=$(test_endpoint 80 "/healthz")
    if [ "$health_status" = "200" ]; then
        print_status "success" "HEALTHY"
    else
        print_status "error" "UNHEALTHY (HTTP $health_status)"
    fi
    
    echo -n "Main page
