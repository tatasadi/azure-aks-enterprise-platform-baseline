#!/bin/bash

# Advanced Load Testing with Apache Bench, wrk, or hey
# Choose your preferred load testing tool

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Advanced Load Testing for AKS Demo App ===${NC}\n"

# Get ingress IP
INGRESS_IP=$(kubectl get ingress -n demo-app sample-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$INGRESS_IP" ]; then
    echo -e "${RED}Error: Could not get ingress IP${NC}"
    exit 1
fi

BASE_URL="http://$INGRESS_IP"
echo -e "${GREEN}Target: $BASE_URL${NC}\n"

# Check which tools are available
HAS_AB=false
HAS_WRK=false
HAS_HEY=false

command -v ab &> /dev/null && HAS_AB=true
command -v wrk &> /dev/null && HAS_WRK=true
command -v hey &> /dev/null && HAS_HEY=true

echo -e "${YELLOW}Available tools:${NC}"
[ "$HAS_AB" = true ] && echo "  ✓ Apache Bench (ab)" || echo "  ✗ Apache Bench (ab) - Install: brew install httpd (macOS)"
[ "$HAS_WRK" = true ] && echo "  ✓ wrk" || echo "  ✗ wrk - Install: brew install wrk (macOS)"
[ "$HAS_HEY" = true ] && echo "  ✓ hey" || echo "  ✗ hey - Install: brew install hey (macOS)"
echo ""

if [ "$HAS_AB" = false ] && [ "$HAS_WRK" = false ] && [ "$HAS_HEY" = false ]; then
    echo -e "${RED}No load testing tools found. Please install one of:${NC}"
    echo "  brew install httpd  # Apache Bench"
    echo "  brew install wrk    # wrk"
    echo "  brew install hey    # hey"
    exit 1
fi

# Select tool
echo -e "${GREEN}Select load test tool:${NC}"
[ "$HAS_AB" = true ] && echo "1. Apache Bench (ab)"
[ "$HAS_WRK" = true ] && echo "2. wrk (recommended)"
[ "$HAS_HEY" = true ] && echo "3. hey"
echo ""

read -p "Enter choice: " tool_choice

# Select scenario
echo -e "${GREEN}Select test scenario:${NC}"
echo "1. Light load (100 requests, 10 concurrent)"
echo "2. Medium load (1000 requests, 50 concurrent)"
echo "3. Heavy load (10000 requests, 100 concurrent)"
echo "4. Sustained load (2 minutes, 50 concurrent)"
echo "5. Custom"
echo ""

read -p "Enter choice: " scenario

case $scenario in
    1)
        REQUESTS=100
        CONCURRENCY=10
        DURATION=0
        ;;
    2)
        REQUESTS=1000
        CONCURRENCY=50
        DURATION=0
        ;;
    3)
        REQUESTS=10000
        CONCURRENCY=100
        DURATION=0
        ;;
    4)
        REQUESTS=0
        CONCURRENCY=50
        DURATION=120
        ;;
    5)
        read -p "Enter total requests (0 for duration-based): " REQUESTS
        read -p "Enter concurrent connections: " CONCURRENCY
        if [ "$REQUESTS" -eq 0 ]; then
            read -p "Enter duration in seconds: " DURATION
        fi
        ;;
esac

# Run load test based on selected tool
case $tool_choice in
    1)
        if [ "$HAS_AB" = false ]; then
            echo -e "${RED}Apache Bench not installed${NC}"
            exit 1
        fi

        echo -e "${YELLOW}Running Apache Bench...${NC}"
        if [ "$DURATION" -gt 0 ]; then
            echo "Apache Bench doesn't support duration-based tests. Using 10000 requests instead."
            REQUESTS=10000
        fi

        ab -n "$REQUESTS" -c "$CONCURRENCY" -H "Host: demo.aks.internal" "$BASE_URL/health"
        ;;

    2)
        if [ "$HAS_WRK" = false ]; then
            echo -e "${RED}wrk not installed${NC}"
            exit 1
        fi

        echo -e "${YELLOW}Running wrk...${NC}"
        if [ "$DURATION" -eq 0 ]; then
            DURATION=30  # Default duration
        fi

        # Create Lua script for wrk with multiple endpoints
        cat > /tmp/wrk-script.lua <<'EOF'
request = function()
    paths = {"/", "/health", "/info", "/secret"}
    path = paths[math.random(#paths)]
    wrk.headers["Host"] = "demo.aks.internal"
    return wrk.format("GET", path)
end
EOF

        wrk -t4 -c"$CONCURRENCY" -d"${DURATION}s" --latency -s /tmp/wrk-script.lua "$BASE_URL"
        rm -f /tmp/wrk-script.lua
        ;;

    3)
        if [ "$HAS_HEY" = false ]; then
            echo -e "${RED}hey not installed${NC}"
            exit 1
        fi

        echo -e "${YELLOW}Running hey...${NC}"
        if [ "$DURATION" -gt 0 ]; then
            hey -z "${DURATION}s" -c "$CONCURRENCY" -H "Host: demo.aks.internal" "$BASE_URL/health"
        else
            hey -n "$REQUESTS" -c "$CONCURRENCY" -H "Host: demo.aks.internal" "$BASE_URL/health"
        fi
        ;;
esac

echo ""
echo -e "${GREEN}=== Load test completed ===${NC}"
echo -e "${YELLOW}Now check your Grafana dashboards:${NC}"
echo "1. Cluster Health Overview - See CPU/memory impact"
echo "2. Ingress Metrics - View request rates, latency, errors"
echo "3. Application Health - Monitor pod metrics"
