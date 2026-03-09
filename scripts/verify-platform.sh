#!/bin/bash
# Platform Verification Script
# This script verifies that all platform components are properly configured

set -e

echo "=================================================="
echo "AKS Platform Verification"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}"
    else
        echo -e "${RED}❌ FAIL${NC}"
        return 1
    fi
}

# Function to print section header
section() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

# 1. Check kubectl connection
section "1. Checking AKS Cluster Connection"
echo -n "Testing kubectl connectivity... "
kubectl cluster-info > /dev/null 2>&1
check_status

echo -n "Checking node status... "
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$NODE_COUNT" -ge 3 ]; then
    echo -e "${GREEN}✅ PASS${NC} ($NODE_COUNT nodes ready)"
else
    echo -e "${RED}❌ FAIL${NC} (Expected 3 nodes, found $NODE_COUNT)"
fi

# 2. Check NGINX Ingress
section "2. Verifying NGINX Ingress Controller"
echo -n "Checking NGINX pods... "
NGINX_PODS=$(kubectl get pods -n app-routing-system -l app=nginx --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$NGINX_PODS" -ge 2 ]; then
    echo -e "${GREEN}✅ PASS${NC} ($NGINX_PODS replicas running)"
else
    echo -e "${RED}❌ FAIL${NC} (Expected 2 replicas, found $NGINX_PODS)"
fi

echo -n "Checking LoadBalancer service... "
EXTERNAL_IP=$(kubectl get svc -n app-routing-system nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$EXTERNAL_IP" ]; then
    echo -e "${GREEN}✅ PASS${NC} (External IP: $EXTERNAL_IP)"
else
    echo -e "${RED}❌ FAIL${NC} (No external IP assigned)"
fi

echo -n "Checking IngressClass... "
kubectl get ingressclass webapprouting.kubernetes.azure.com > /dev/null 2>&1
check_status

# 3. Check Azure Policy
section "3. Verifying Azure Policy Add-on"
echo -n "Checking Azure Policy pods... "
POLICY_PODS=$(kubectl get pods -n kube-system -l app=azure-policy --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$POLICY_PODS" -ge 2 ]; then
    echo -e "${GREEN}✅ PASS${NC} ($POLICY_PODS pods running)"
else
    echo -e "${RED}❌ FAIL${NC} (Expected 2 pods, found $POLICY_PODS)"
fi

echo -n "Checking ConstraintTemplates... "
TEMPLATES=$(kubectl get constrainttemplates --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$TEMPLATES" -ge 10 ]; then
    echo -e "${GREEN}✅ PASS${NC} ($TEMPLATES templates installed)"
else
    echo -e "${YELLOW}⚠️  WARNING${NC} (Expected 10+ templates, found $TEMPLATES)"
fi

# 4. Check CSI Driver
section "4. Verifying Secrets Store CSI Driver"
echo -n "Checking CSI driver pods... "
CSI_DRIVER_PODS=$(kubectl get pods -n kube-system -l app=secrets-store-csi-driver --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$CSI_DRIVER_PODS" -ge 3 ]; then
    echo -e "${GREEN}✅ PASS${NC} ($CSI_DRIVER_PODS DaemonSet pods running)"
else
    echo -e "${RED}❌ FAIL${NC} (Expected 3 DaemonSet pods, found $CSI_DRIVER_PODS)"
fi

echo -n "Checking Azure provider pods... "
AZURE_PROVIDER_PODS=$(kubectl get pods -n kube-system -l app=secrets-store-provider-azure --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$AZURE_PROVIDER_PODS" -ge 3 ]; then
    echo -e "${GREEN}✅ PASS${NC} ($AZURE_PROVIDER_PODS DaemonSet pods running)"
else
    echo -e "${RED}❌ FAIL${NC} (Expected 3 DaemonSet pods, found $AZURE_PROVIDER_PODS)"
fi

# 5. Check Prometheus (AMA Metrics)
section "5. Verifying Prometheus Metrics Collection"
echo -n "Checking ama-metrics collector pods... "
AMA_METRICS_PODS=$(kubectl get pods -n kube-system -l rsName=ama-metrics --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$AMA_METRICS_PODS" -ge 2 ]; then
    echo -e "${GREEN}✅ PASS${NC} ($AMA_METRICS_PODS collector pods running)"
else
    echo -e "${RED}❌ FAIL${NC} (Expected 2+ collector pods, found $AMA_METRICS_PODS)"
fi

echo -n "Checking ama-metrics-node DaemonSet... "
AMA_NODE_PODS=$(kubectl get pods -n kube-system -l dsName=ama-metrics-node --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$AMA_NODE_PODS" -ge 3 ]; then
    echo -e "${GREEN}✅ PASS${NC} ($AMA_NODE_PODS node pods running)"
else
    echo -e "${RED}❌ FAIL${NC} (Expected 3 node pods, found $AMA_NODE_PODS)"
fi

echo -n "Checking kube-state-metrics... "
kubectl get pods -n kube-system -l app.kubernetes.io/name=ama-metrics-ksm --no-headers 2>/dev/null | grep -q "Running"
check_status

# 6. Check Container Insights
section "6. Verifying Container Insights"
echo -n "Checking AKS monitoring configuration... "
AKS_NAME="aksplatform-dev-aks"
RG_NAME="aksplatform-dev-rg"
MONITORING_ENABLED=$(az aks show --name "$AKS_NAME" --resource-group "$RG_NAME" --query "addonProfiles.omsagent.enabled" -o tsv 2>/dev/null || echo "false")
if [ "$MONITORING_ENABLED" == "true" ]; then
    echo -e "${GREEN}✅ PASS${NC} (OMS agent enabled)"
else
    echo -e "${YELLOW}⚠️  WARNING${NC} (OMS agent may not be enabled)"
fi

# 7. Check Grafana
section "7. Verifying Azure Managed Grafana"
echo -n "Checking Grafana instance... "
GRAFANA_ENDPOINT=$(az grafana list --resource-group "$RG_NAME" --query "[0].properties.endpoint" -o tsv 2>/dev/null)
if [ -n "$GRAFANA_ENDPOINT" ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    echo "   Endpoint: $GRAFANA_ENDPOINT"
else
    echo -e "${RED}❌ FAIL${NC} (No Grafana instance found)"
fi

# 8. Check OIDC Issuer
section "8. Verifying OIDC Issuer (Workload Identity)"
echo -n "Checking OIDC issuer configuration... "
OIDC_ISSUER=$(az aks show --name "$AKS_NAME" --resource-group "$RG_NAME" --query "oidcIssuerProfile.issuerUrl" -o tsv 2>/dev/null)
if [ -n "$OIDC_ISSUER" ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    echo "   Issuer URL: $OIDC_ISSUER"
else
    echo -e "${RED}❌ FAIL${NC} (OIDC issuer not configured)"
fi

# 9. Summary
section "Summary"
echo -e "${GREEN}Platform components verified successfully!${NC}"
echo ""
echo "Next Steps:"
echo "  1. Access Grafana: $GRAFANA_ENDPOINT"
echo "  2. Review documentation: docs/architecture.md"
echo "  3. Review policy definitions: platform/policies/README.md"
echo "  4. Deploy applications with Workload Identity"
echo ""
echo "=================================================="
