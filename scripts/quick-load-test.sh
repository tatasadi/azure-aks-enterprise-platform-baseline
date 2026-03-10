#!/bin/bash

# Quick Load Test - Simple one-liner style tests
# Run this for quick dashboard testing

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get ingress IP
INGRESS_IP=$(kubectl get ingress -n demo-app sample-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
BASE_URL="http://$INGRESS_IP"

echo -e "${GREEN}Quick Load Test${NC}"
echo "Target: $BASE_URL"
echo ""

# Simple curl loop - 100 requests
echo -e "${YELLOW}Sending 100 requests...${NC}"
for i in {1..100}; do
    curl -s -H "Host: demo.aks.internal" "$BASE_URL/health" > /dev/null &
    [ $((i % 10)) -eq 0 ] && echo "  Sent $i requests..."
    sleep 0.1
done
wait

echo -e "${GREEN}Done! Check Grafana dashboards for metrics.${NC}"
