#!/bin/bash

# Build and Deploy Sample API with Prometheus Metrics
# This script builds the updated sample-api image and deploys it to AKS

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VERSION="v1.1.0"
ACR_NAME="aksplatformdevacr"
IMAGE_NAME="sample-api"
FULL_IMAGE="${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${VERSION}"

echo -e "${GREEN}Building and Deploying Sample API ${VERSION}${NC}"
echo -e "${YELLOW}This version includes Prometheus metrics instrumentation${NC}"
echo ""

# Step 1: Login to ACR
echo -e "${GREEN}Step 1: Logging in to Azure Container Registry...${NC}"
az acr login --name ${ACR_NAME}

# Step 2: Build Docker image
echo -e "${GREEN}Step 2: Building Docker image...${NC}"
cd ../app/sample-api
docker build -t ${FULL_IMAGE} .
cd ../..

# Step 3: Push to ACR
echo -e "${GREEN}Step 3: Pushing image to ACR...${NC}"
docker push ${FULL_IMAGE}

# Step 4: Update deployment image
echo -e "${GREEN}Step 4: Updating Kubernetes deployment...${NC}"
kubectl set image deployment/sample-api -n demo-app sample-api=${FULL_IMAGE}

# Step 5: Wait for rollout
echo -e "${GREEN}Step 5: Waiting for rollout to complete...${NC}"
kubectl rollout status deployment/sample-api -n demo-app --timeout=120s

# Step 6: Apply PodMonitor
echo -e "${GREEN}Step 6: Applying PodMonitor for metrics scraping...${NC}"
kubectl apply -f app/k8s/podmonitor.yaml

# Step 7: Verify deployment
echo -e "${GREEN}Step 7: Verifying deployment...${NC}"
echo ""
echo "Pods:"
kubectl get pods -n demo-app -l app=sample-api
echo ""
echo "PodMonitor:"
kubectl get podmonitor -n demo-app
echo ""

# Step 8: Test metrics endpoint
echo -e "${GREEN}Step 8: Testing metrics endpoint...${NC}"
POD_NAME=$(kubectl get pod -n demo-app -l app=sample-api -o jsonpath='{.items[0].metadata.name}')
echo "Testing /metrics endpoint on pod: ${POD_NAME}"
kubectl exec -n demo-app ${POD_NAME} -- python3 -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8080/metrics').read().decode()[:500])"

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Wait 2-4 minutes for metrics to be scraped and ingested"
echo "2. Generate some traffic: ./scripts/load-test/quick-load-test.sh"
echo "3. Check Grafana Application Health dashboard"
echo ""
echo "To manually test metrics endpoint:"
echo "  kubectl port-forward -n demo-app service/sample-api 8080:80"
echo "  curl http://localhost:8080/metrics"
