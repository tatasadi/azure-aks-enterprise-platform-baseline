# Operations Guide

This document provides operational procedures and runbooks for managing the AKS Enterprise Platform.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Access and Authentication](#access-and-authentication)
3. [Common Operations](#common-operations)
4. [Troubleshooting](#troubleshooting)
5. [Monitoring and Alerts](#monitoring-and-alerts)
6. [Backup and Recovery](#backup-and-recovery)
7. [Security Operations](#security-operations)
8. [Maintenance Windows](#maintenance-windows)

---

## Prerequisites

### Required Tools

```bash
# Verify tool versions
terraform --version   # >= 1.5
kubectl version      # >= 1.28
helm version         # >= 3.12
az --version         # >= 2.50
```

### Azure CLI Extensions

```bash
# Install/update required extensions
az extension add --name aks-preview
az extension update --name aks-preview
```

---

## Access and Authentication

### Accessing the AKS Cluster

#### Method 1: Get credentials via Azure CLI

```bash
# Set variables
RESOURCE_GROUP="aksplatform-dev-rg"
CLUSTER_NAME="aksplatform-dev-aks"

# Get cluster credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Verify access
kubectl get nodes
kubectl cluster-info
```

#### Method 2: Using Terraform outputs

```bash
cd infra/terraform/envs/dev

# Get cluster name
terraform output aks_cluster_name

# Get credentials
az aks get-credentials \
  --resource-group aksplatform-dev-rg \
  --name $(terraform output -raw aks_cluster_name)
```

### Accessing Grafana

```bash
# Get Grafana endpoint
cd infra/terraform/envs/dev
terraform output grafana_endpoint

# Open in browser (Entra ID authentication required)
open $(terraform output -raw grafana_endpoint)
```

### Accessing Azure Key Vault

```bash
# Get Key Vault name
terraform output keyvault_name

# List secrets
az keyvault secret list \
  --vault-name $(terraform output -raw keyvault_name)

# Get secret value
az keyvault secret show \
  --vault-name $(terraform output -raw keyvault_name) \
  --name db-connection-string \
  --query value -o tsv
```

### Accessing Azure Container Registry

```bash
# Get ACR login server
terraform output acr_login_server

# Login to ACR
az acr login --name aksplatformdevacr

# List images
az acr repository list --name aksplatformdevacr -o table
```

---

## Common Operations

### 1. Deploying a New Application

#### Step-by-step Process

**Prerequisites**:
- Docker image pushed to ACR
- Namespace created
- ServiceAccount configured with Workload Identity
- SecretProviderClass created (if using Key Vault)

**Deployment Steps**:

```bash
# 1. Create namespace
kubectl create namespace my-app

# 2. Apply manifests
kubectl apply -f app/k8s/namespace.yaml
kubectl apply -f app/k8s/serviceaccount.yaml
kubectl apply -f app/k8s/secretproviderclass.yaml
kubectl apply -f app/k8s/deployment.yaml
kubectl apply -f app/k8s/service.yaml
kubectl apply -f app/k8s/ingress.yaml

# 3. Verify deployment
kubectl get pods -n my-app
kubectl get ingress -n my-app

# 4. Check logs
kubectl logs -n my-app -l app=my-app --tail=50

# 5. Test endpoint
INGRESS_IP=$(kubectl get ingress -n my-app my-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$INGRESS_IP/health
```

### 2. Adding a Secret to Key Vault

```bash
# Set variables
KEYVAULT_NAME=$(cd infra/terraform/envs/dev && terraform output -raw keyvault_name)
SECRET_NAME="api-key"
SECRET_VALUE="super-secret-value"

# Add secret
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name $SECRET_NAME \
  --value $SECRET_VALUE

# Verify secret
az keyvault secret show \
  --vault-name $KEYVAULT_NAME \
  --name $SECRET_NAME \
  --query value -o tsv

# Update SecretProviderClass to reference the new secret
kubectl edit secretproviderclass my-secret-provider -n my-app

# Restart pods to mount the new secret
kubectl rollout restart deployment my-app -n my-app
```

### 3. Granting Workload Access to Key Vault

**Scenario**: New application needs to read secrets from Key Vault

```bash
# 1. Create User Assigned Managed Identity (if not already created)
IDENTITY_NAME="my-app-identity"
RESOURCE_GROUP="aksplatform-dev-rg"

az identity create \
  --name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP

# 2. Get identity details
CLIENT_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query clientId -o tsv)
PRINCIPAL_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query principalId -o tsv)

# 3. Grant Key Vault Secrets User role
KEYVAULT_NAME=$(cd infra/terraform/envs/dev && terraform output -raw keyvault_name)
KEYVAULT_ID=$(az keyvault show --name $KEYVAULT_NAME --query id -o tsv)

az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $PRINCIPAL_ID \
  --scope $KEYVAULT_ID

# 4. Create federated identity credential
AKS_OIDC_ISSUER=$(cd infra/terraform/envs/dev && terraform output -raw aks_oidc_issuer_url)

az identity federated-credential create \
  --name my-app-federated-credential \
  --identity-name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --issuer $AKS_OIDC_ISSUER \
  --subject system:serviceaccount:my-app:my-app-sa

# 5. Annotate ServiceAccount
kubectl annotate serviceaccount my-app-sa \
  -n my-app \
  azure.workload.identity/client-id=$CLIENT_ID

# 6. Label pods
kubectl label pod -n my-app -l app=my-app azure.workload.identity/use=true

# 7. Restart deployment
kubectl rollout restart deployment my-app -n my-app
```

### 4. Scaling Applications

```bash
# Manual scaling
kubectl scale deployment my-app -n my-app --replicas=5

# Verify scaling
kubectl get pods -n my-app

# Check resource utilization
kubectl top pods -n my-app
kubectl top nodes
```

### 5. Updating Application Image

```bash
# Build and push new image
docker build -t aksplatformdevacr.azurecr.io/my-app:v2.0.0 .
docker push aksplatformdevacr.azurecr.io/my-app:v2.0.0

# Update deployment
kubectl set image deployment/my-app \
  my-app=aksplatformdevacr.azurecr.io/my-app:v2.0.0 \
  -n my-app

# Monitor rollout
kubectl rollout status deployment my-app -n my-app

# Verify new version
kubectl get pods -n my-app -o jsonpath='{.items[0].spec.containers[0].image}'

# Rollback if needed
kubectl rollout undo deployment my-app -n my-app
```

### 6. Viewing Logs

```bash
# View logs for a deployment
kubectl logs -n my-app -l app=my-app --tail=100 --follow

# View logs for specific pod
kubectl logs -n my-app my-app-pod-xyz123 -c my-app

# View previous container logs (after restart)
kubectl logs -n my-app my-app-pod-xyz123 --previous

# View logs in Log Analytics (KQL query)
az monitor log-analytics query \
  --workspace $(cd infra/terraform/envs/dev && terraform output -raw log_analytics_workspace_id) \
  --analytics-query "ContainerLog | where ContainerName == 'my-app' | order by TimeGenerated desc | limit 100" \
  --output table
```

### 7. Querying Prometheus Metrics

```bash
# Access Grafana Explore view for ad-hoc queries
# Example PromQL queries:

# CPU usage by pod
sum(rate(container_cpu_usage_seconds_total{namespace="my-app"}[5m])) by (pod)

# Memory usage by pod
sum(container_memory_working_set_bytes{namespace="my-app"}) by (pod)

# Request rate
sum(rate(nginx_ingress_controller_requests{ingress="my-app"}[5m]))

# Error rate
sum(rate(nginx_ingress_controller_requests{ingress="my-app",status=~"5.."}[5m]))
  / sum(rate(nginx_ingress_controller_requests{ingress="my-app"}[5m]))
```

---

## Troubleshooting

### Pod Won't Start

**Symptoms**: Pod stuck in `Pending`, `CrashLoopBackOff`, or `ImagePullBackOff`

**Troubleshooting Steps**:

```bash
# 1. Check pod status
kubectl describe pod <pod-name> -n <namespace>

# 2. Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# 3. Check logs
kubectl logs <pod-name> -n <namespace>

# 4. Common issues:

# Issue: ImagePullBackOff
# Solution: Verify ACR integration
az aks check-acr \
  --name aksplatform-dev-aks \
  --resource-group aksplatform-dev-rg \
  --acr aksplatformdevacr.azurecr.io

# Issue: Insufficient resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Issue: Policy violation
kubectl logs -n kube-system -l app=azure-policy-webhook --tail=50
```

### Secret Not Mounted

**Symptoms**: Application can't read secrets from `/mnt/secrets/`

**Troubleshooting Steps**:

```bash
# 1. Verify CSI driver pods are running
kubectl get pods -n kube-system | grep csi

# 2. Check SecretProviderClass
kubectl describe secretproviderclass <name> -n <namespace>

# 3. Check pod events
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 Events

# 4. Verify Workload Identity setup
# Check ServiceAccount annotation
kubectl get serviceaccount <sa-name> -n <namespace> -o yaml | grep client-id

# Check pod label
kubectl get pod <pod-name> -n <namespace> -o yaml | grep azure.workload.identity/use

# 5. Verify Key Vault access
az keyvault secret show \
  --vault-name <keyvault-name> \
  --name <secret-name>

# 6. Check CSI driver logs
kubectl logs -n kube-system <csi-driver-pod> --tail=100
```

### Ingress Not Working

**Symptoms**: Can't access application via ingress

**Troubleshooting Steps**:

```bash
# 1. Check ingress resource
kubectl get ingress -n <namespace>
kubectl describe ingress <ingress-name> -n <namespace>

# 2. Verify ingress class
kubectl get ingressclass

# 3. Check NGINX pods
kubectl get pods -n app-routing-system
kubectl logs -n app-routing-system -l app=nginx --tail=50

# 4. Check service endpoints
kubectl get endpoints <service-name> -n <namespace>

# 5. Test service directly
kubectl port-forward -n <namespace> svc/<service-name> 8080:80
curl http://localhost:8080/health

# 6. Get LoadBalancer IP
kubectl get svc -n app-routing-system

# 7. Test ingress path
INGRESS_IP=$(kubectl get svc -n app-routing-system -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
curl -H "Host: my-app.example.com" http://$INGRESS_IP/
```

### High Resource Usage

**Symptoms**: Pods OOMKilled, nodes under pressure

**Troubleshooting Steps**:

```bash
# 1. Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=memory
kubectl top pods --all-namespaces --sort-by=cpu

# 2. Check resource requests/limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 Limits

# 3. Check node conditions
kubectl describe node <node-name> | grep -A 10 Conditions

# 4. View metrics in Grafana
# Navigate to Cluster Health Overview dashboard

# 5. Scale cluster if needed
az aks nodepool scale \
  --resource-group aksplatform-dev-rg \
  --cluster-name aksplatform-dev-aks \
  --name system \
  --node-count 5
```

### Policy Blocking Deployment

**Symptoms**: Admission webhook denies pod creation

**Troubleshooting Steps**:

```bash
# 1. Check events for policy violations
kubectl get events -n <namespace> --field-selector type=Warning

# 2. View policy logs
kubectl logs -n kube-system -l app=azure-policy --tail=100

# 3. List policy assignments
az policy assignment list --resource-group aksplatform-dev-rg -o table

# 4. Check policy compliance
az policy state list \
  --resource-group aksplatform-dev-rg \
  --resource "/subscriptions/<sub-id>/resourceGroups/aksplatform-dev-rg/providers/Microsoft.ContainerService/managedClusters/aksplatform-dev-aks"

# 5. Fix common policy violations:
# - Add resource requests/limits
# - Remove privileged: true
# - Add required labels
# - Use specific image tags (not :latest)
# - Add health probes
```

---

## Monitoring and Alerts

### Key Metrics to Monitor

1. **Cluster Health**
   - Node CPU/memory utilization (threshold: 80%)
   - Pod restart count (threshold: >3 in 15 min)
   - Node status (Ready/NotReady)

2. **Application Health**
   - Request rate
   - Error rate (threshold: >5%)
   - Response latency P95 (threshold: >1000ms)
   - Pod availability

3. **Infrastructure**
   - Disk usage on nodes
   - Network throughput
   - Persistent volume capacity

### Setting Up Alert Rules (Example)

```bash
# Create alert rule for pod restarts
az monitor metrics alert create \
  --name "high-pod-restarts" \
  --resource-group aksplatform-dev-rg \
  --scopes "/subscriptions/<sub-id>/resourceGroups/aksplatform-dev-rg/providers/Microsoft.ContainerService/managedClusters/aksplatform-dev-aks" \
  --condition "avg PodRestartCount > 3" \
  --window-size 15m \
  --evaluation-frequency 5m \
  --action <action-group-id>
```

### Accessing Dashboards

- **Cluster Health**: [Grafana dashboard](platform/manifests/grafana-dashboards/cluster-health-overview.json)
- **Ingress Metrics**: [Grafana dashboard](platform/manifests/grafana-dashboards/ingress-metrics.json)
- **Application Health**: [Grafana dashboard](platform/manifests/grafana-dashboards/application-health.json)

See [dashboards.md](dashboards.md) for detailed dashboard documentation.

---

## Backup and Recovery

### Backing Up Kubernetes Resources

```bash
# Export all resources in a namespace
kubectl get all -n my-app -o yaml > my-app-backup.yaml

# Export specific resource types
kubectl get deployments,services,ingresses -n my-app -o yaml > my-app-resources.yaml

# Backup persistent volume data (application-specific)
# Use application-native backup tools or Azure Backup for AKS
```

### Disaster Recovery

**Scenario**: Complete cluster failure

**Recovery Steps**:

1. **Recreate infrastructure**:
   ```bash
   cd infra/terraform/envs/dev
   terraform apply
   ```

2. **Restore Kubernetes resources**:
   ```bash
   kubectl apply -f my-app-backup.yaml
   ```

3. **Verify application health**:
   ```bash
   kubectl get pods --all-namespaces
   ```

---

## Security Operations

### Rotating Secrets

```bash
# 1. Update secret in Key Vault
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name $SECRET_NAME \
  --value $NEW_SECRET_VALUE

# 2. CSI driver will auto-rotate within configured interval
# Or force immediate rotation by restarting pods
kubectl rollout restart deployment my-app -n my-app

# 3. Verify new secret is mounted
kubectl exec -n my-app <pod-name> -- cat /mnt/secrets/$SECRET_NAME
```

### Reviewing Access Logs

```bash
# Kubernetes audit logs (if enabled)
kubectl logs -n kube-system -l component=kube-apiserver

# Azure Activity Log
az monitor activity-log list \
  --resource-group aksplatform-dev-rg \
  --start-time $(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --query "[?contains(authorization.action, 'Microsoft.ContainerService')]"
```

### Scanning Images for Vulnerabilities

```bash
# Scan image in ACR
az acr task run \
  --registry aksplatformdevacr \
  --name quicktask \
  --cmd "trivy image aksplatformdevacr.azurecr.io/my-app:v1.0.0"
```

---

## Maintenance Windows

### Upgrading AKS Cluster

```bash
# Check available versions
az aks get-upgrades \
  --resource-group aksplatform-dev-rg \
  --name aksplatform-dev-aks

# Upgrade cluster (control plane)
az aks upgrade \
  --resource-group aksplatform-dev-rg \
  --name aksplatform-dev-aks \
  --kubernetes-version 1.34.0

# Upgrade node pool
az aks nodepool upgrade \
  --resource-group aksplatform-dev-rg \
  --cluster-name aksplatform-dev-aks \
  --name system \
  --kubernetes-version 1.34.0
```

### Draining Nodes for Maintenance

```bash
# Cordon node (prevent new pods)
kubectl cordon <node-name>

# Drain node (evict existing pods)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Perform maintenance...

# Uncordon node (allow scheduling)
kubectl uncordon <node-name>
```

---

## Emergency Contacts

| Role | Responsibility | Contact |
|------|----------------|---------|
| Platform Team Lead | Infrastructure decisions | TBD |
| On-Call Engineer | 24/7 incident response | TBD |
| Security Team | Security incidents | TBD |
| Azure Support | Azure service issues | Azure Portal |

---

## CI/CD Pipeline Operations

### Running Infrastructure Pipeline

The infrastructure pipeline automates Terraform deployments. See [pipelines/README.md](../pipelines/README.md) for detailed setup.

**Trigger Manually:**
```bash
# In Azure DevOps
# Pipelines → Infrastructure Pipeline → Run pipeline
# Select branch and review plan before approving Apply stage
```

**Monitor Pipeline:**
```bash
# View pipeline status
az pipelines show --name "Infrastructure Pipeline" --organization https://dev.azure.com/yourorg --project yourproject

# View latest run
az pipelines runs list --pipeline-name "Infrastructure Pipeline" --organization https://dev.azure.com/yourorg --project yourproject --top 1
```

**Review Terraform Plan:**
1. Navigate to pipeline run in Azure DevOps
2. Go to the "Plan" stage
3. Download "plan-output" artifact
4. Review changes before approving Apply stage

### Running Application Pipeline

The application pipeline builds and deploys the sample API application.

**Trigger Manually:**
```bash
# In Azure DevOps
# Pipelines → Application Pipeline → Run pipeline
# Select branch and monitor deployment stages
```

**Verify Deployment:**
```bash
# Check deployment status
kubectl rollout status deployment/sample-api -n demo-app

# View pods
kubectl get pods -n demo-app

# Check application logs
kubectl logs -n demo-app -l app=sample-api --tail=50

# Test application endpoint
INGRESS_IP=$(kubectl get ingress -n demo-app sample-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/health
```

**Rollback Application Deployment:**
```bash
# View deployment history
kubectl rollout history deployment/sample-api -n demo-app

# Rollback to previous version
kubectl rollout undo deployment/sample-api -n demo-app

# Rollback to specific revision
kubectl rollout undo deployment/sample-api -n demo-app --to-revision=2

# Monitor rollback
kubectl rollout status deployment/sample-api -n demo-app
```

### Pipeline Troubleshooting

**Issue: Service connection not authorized**
```bash
# Grant pipeline permissions
# Azure DevOps → Project Settings → Service connections
# Select the service connection → Security → Grant access to all pipelines
```

**Issue: Terraform state lock**
```bash
# Check for lock
az storage blob show \
  --account-name sttfstateta \
  --container-name tfstate \
  --name azure-aks-dev.tfstate \
  --query "properties.lease.state"

# Break lock if needed (ensure no other applies are running!)
az storage blob lease break \
  --account-name sttfstateta \
  --container-name tfstate \
  --blob-name azure-aks-dev.tfstate
```

**Issue: Image pull errors in deployment**
```bash
# Verify ACR integration
kubectl get pods -n demo-app -o yaml | grep -A 5 "imagePullSecrets"

# Check ACR role assignment
az role assignment list --assignee $(az aks show -g aksplatform-dev-rg -n aksplatform-dev-aks --query identityProfile.kubeletidentity.clientId -o tsv) --all

# Manually test ACR access
az acr login --name aksplatformdevacr
docker pull aksplatformdevacr.azurecr.io/sample-api:latest
```

---

## Additional Resources

- [Architecture Documentation](architecture.md)
- [Dashboard Guide](dashboards.md)
- [Policy Documentation](../platform/policies/README.md)
- [CI/CD Pipelines](../pipelines/README.md)
- [AKS Best Practices](https://learn.microsoft.com/azure/aks/best-practices)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)

---

**Last Updated**: 2026-03-10
