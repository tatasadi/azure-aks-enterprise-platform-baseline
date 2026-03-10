#!/bin/bash

# Load Testing Script for AKS Demo Application
# This script generates HTTP traffic to test Grafana dashboards

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== AKS Demo App Load Testing ===${NC}\n"

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Get ingress IP
echo -e "${YELLOW}Getting ingress IP...${NC}"
INGRESS_IP=$(kubectl get ingress -n demo-app sample-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$INGRESS_IP" ]; then
    echo -e "${RED}Error: Could not get ingress IP. Make sure the demo app is deployed.${NC}"
    echo "Run: kubectl get ingress -n demo-app"
    exit 1
fi

echo -e "${GREEN}Ingress IP: $INGRESS_IP${NC}\n"

# Test endpoints
BASE_URL="http://$INGRESS_IP"
HOST_HEADER="demo.aks.internal"

echo -e "${YELLOW}Available endpoints:${NC}"
echo "  GET  $BASE_URL/ (health check)"
echo "  GET  $BASE_URL/health"
echo "  GET  $BASE_URL/info"
echo "  GET  $BASE_URL/secret"
echo ""

# Function to make requests
make_request() {
    local endpoint=$1
    local method=${2:-GET}
    curl -s -o /dev/null -w "%{http_code}" -H "Host: $HOST_HEADER" -X "$method" "$BASE_URL$endpoint"
}

# Load test options
echo -e "${GREEN}Select load test scenario:${NC}"
echo "1. Light load (10 requests/sec for 1 minute)"
echo "2. Medium load (50 requests/sec for 2 minutes)"
echo "3. Heavy load (100 requests/sec for 5 minutes)"
echo "4. Spike test (burst traffic)"
echo "5. Custom test"
echo "6. Error injection test (generate 4xx/5xx errors)"
echo ""

read -p "Enter choice [1-6]: " choice

case $choice in
    1)
        DURATION=60
        RPS=10
        echo -e "${YELLOW}Running light load test: $RPS req/sec for $DURATION seconds${NC}"
        ;;
    2)
        DURATION=120
        RPS=50
        echo -e "${YELLOW}Running medium load test: $RPS req/sec for $DURATION seconds${NC}"
        ;;
    3)
        DURATION=300
        RPS=100
        echo -e "${YELLOW}Running heavy load test: $RPS req/sec for $DURATION seconds${NC}"
        ;;
    4)
        echo -e "${YELLOW}Running spike test (10s baseline, 30s spike, 10s cool-down)${NC}"
        # Baseline
        echo "Baseline: 10 req/sec for 10 seconds..."
        for i in {1..100}; do
            make_request "/health" &
            sleep 0.1
        done
        wait

        # Spike
        echo "Spike: 200 req/sec for 30 seconds..."
        for i in {1..6000}; do
            make_request "/health" &
            sleep 0.005
        done
        wait

        # Cool-down
        echo "Cool-down: 10 req/sec for 10 seconds..."
        for i in {1..100}; do
            make_request "/health" &
            sleep 0.1
        done
        wait

        echo -e "${GREEN}Spike test completed!${NC}"
        exit 0
        ;;
    5)
        read -p "Enter requests per second: " RPS
        read -p "Enter duration in seconds: " DURATION
        echo -e "${YELLOW}Running custom load test: $RPS req/sec for $DURATION seconds${NC}"
        ;;
    6)
        echo -e "${YELLOW}Running error injection test${NC}"
        echo "Generating mix of successful and failed requests..."

        for i in {1..50}; do
            # Normal requests (200)
            make_request "/health" &
            make_request "/info" &

            # 404 errors (non-existent endpoints)
            make_request "/nonexistent" &
            make_request "/missing" &

            sleep 0.5
        done
        wait

        echo -e "${GREEN}Error injection test completed!${NC}"
        echo "Check Ingress Metrics dashboard for 4xx error rates."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Calculate sleep interval between requests
SLEEP_INTERVAL=$(echo "scale=4; 1/$RPS" | bc)

echo -e "${YELLOW}Starting load test...${NC}"
echo "Press Ctrl+C to stop"
echo ""

# Track statistics
TOTAL_REQUESTS=0
SUCCESS_COUNT=0
ERROR_COUNT=0
START_TIME=$(date +%s)

# Run load test
END_TIME=$((START_TIME + DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
    # Mix of different endpoints
    ENDPOINTS=("/" "/health" "/info" "/secret")
    ENDPOINT=${ENDPOINTS[$RANDOM % ${#ENDPOINTS[@]}]}

    # Make request in background
    HTTP_CODE=$(make_request "$ENDPOINT")

    TOTAL_REQUESTS=$((TOTAL_REQUESTS + 1))

    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi

    # Print progress every 100 requests
    if [ $((TOTAL_REQUESTS % 100)) -eq 0 ]; then
        ELAPSED=$(($(date +%s) - START_TIME))
        ACTUAL_RPS=$(echo "scale=2; $TOTAL_REQUESTS/$ELAPSED" | bc)
        echo -e "${GREEN}Progress: $TOTAL_REQUESTS requests | ${ACTUAL_RPS} req/sec | Success: $SUCCESS_COUNT | Errors: $ERROR_COUNT${NC}"
    fi

    sleep "$SLEEP_INTERVAL"
done

# Final statistics
ELAPSED=$(($(date +%s) - START_TIME))
ACTUAL_RPS=$(echo "scale=2; $TOTAL_REQUESTS/$ELAPSED" | bc)

echo ""
echo -e "${GREEN}=== Load Test Complete ===${NC}"
echo "Total Requests: $TOTAL_REQUESTS"
echo "Success: $SUCCESS_COUNT"
echo "Errors: $ERROR_COUNT"
echo "Duration: ${ELAPSED}s"
echo "Average RPS: $ACTUAL_RPS"
echo ""
echo -e "${YELLOW}Check your Grafana dashboards now!${NC}"
echo "- Cluster Health Overview: Monitor CPU/memory impact"
echo "- Ingress Metrics: See request rates and latency"
echo "- Application Health: Track app-specific metrics"
