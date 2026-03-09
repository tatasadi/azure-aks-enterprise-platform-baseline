# Application Deployment Guide

This guide covers deploying applications to the AKS Enterprise Platform, including the demo application and general patterns for application teams.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start: Deploy Demo Application](#quick-start-deploy-demo-application)
- [Understanding the Deployment](#understanding-the-deployment)
- [Manual Deployment Steps](#manual-deployment-steps)
- [Troubleshooting](#troubleshooting)
- [Application Team Checklist](#application-team-checklist)

---

## Prerequisites

Before deploying applications, ensure you have:

1. **AKS cluster access** configured:
   ```bash
   az aks get-credentials \
     --resource-group aksplatform-dev-rg \
     --name aksplatform-dev-aks
   ```

2. **kubectl installed** and working:
   ```bash
   kubectl get nodes
   ```

3. **Terraform infrastructure deployed**

4. **Azure CLI authenticated**:
   ```bash
   az account show
   ```

---

## Quick Start: Deploy Demo Application

Deploy the entire demo application with a single command:

```bash
kubectl apply -f app/k8s/
```

**Verify deployment:**

```bash
# Check pods are running
kubectl get pods -n demo-app

# Check ingress has an IP
kubectl get ingress -n demo-app

# Test the application
INGRESS_IP=$(kubectl get ingress -n demo-app sample-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/health
```

---

## Understanding the Deployment

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     Entra ID                            │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Workload Identity                               │   │
│  │  Client ID: f8199a1f-...                         │   │
│  │  Federated Credential ↔ demo-app:demo-sa        │   │
│  └──────────────┬───────────────────────────────────┘   │
└─────────────────┼───────────────────────────────────────┘
                  │ OIDC Token Exchange
┌─────────────────▼───────────────────────────────────────┐
│              AKS Cluster                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Namespace: demo-app                             │   │
│  │    ├─ ServiceAccount: demo-sa                    │   │
│  │    ├─ SecretProviderClass: azure-keyvault-...    │   │
│  │    ├─ Deployment: sample-api (2 replicas)        │   │
│  │    ├─ Service: sample-api (ClusterIP)            │   │
│  │    └─ Ingress: sample-api (NGINX)                │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                  │
                  ├─────────► Azure Key Vault (secrets)
                  └─────────► Azure Container Registry (images)
```

### Components

1. **Namespace**: Logical isolation for the application
2. **ServiceAccount**: Kubernetes identity with Workload Identity annotation
3. **SecretProviderClass**: CSI driver configuration for Key Vault
4. **Deployment**: Application pods with security context and resource limits
5. **Service**: Internal networking endpoint
6. **Ingress**: External access via NGINX controller

---

## Manual Deployment Steps

For understanding or troubleshooting, deploy components individually:

### Step 1: Create Namespace

```bash
kubectl apply -f app/k8s/namespace.yaml
```

**Verify:**
```bash
kubectl get namespace demo-app
```

### Step 2: Create ServiceAccount

The ServiceAccount is annotated with the Workload Identity client ID:

```bash
kubectl apply -f app/k8s/serviceaccount.yaml
```

**Verify:**
```bash
kubectl describe serviceaccount demo-sa -n demo-app
# Look for: azure.workload.identity/client-id annotation
```

**Important**: The client ID must match the Terraform-created identity:
```bash
terraform output -raw demo_app_workload_identity_client_id
```

### Step 3: Create SecretProviderClass

Configures the CSI driver to mount secrets from Key Vault:

```bash
kubectl apply -f app/k8s/secretproviderclass.yaml
```

**Verify:**
```bash
kubectl get secretproviderclass -n demo-app
kubectl describe secretproviderclass azure-keyvault-provider -n demo-app
```

### Step 4: Deploy Application

```bash
kubectl apply -f app/k8s/deployment.yaml
```

**Verify:**
```bash
# Check pods are running
kubectl get pods -n demo-app

# Check pod details
kubectl describe pod -n demo-app -l app=sample-api

# View logs
kubectl logs -n demo-app -l app=sample-api --tail=50

# Verify secret is mounted
POD_NAME=$(kubectl get pod -n demo-app -l app=sample-api -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n demo-app $POD_NAME -- ls -la /mnt/secrets/
kubectl exec -n demo-app $POD_NAME -- cat /mnt/secrets/db-connection-string
```

### Step 5: Create Service

```bash
kubectl apply -f app/k8s/service.yaml
```

**Verify:**
```bash
kubectl get service -n demo-app
kubectl describe service sample-api -n demo-app
```

### Step 6: Create Ingress

```bash
kubectl apply -f app/k8s/ingress.yaml
```

**Verify:**
```bash
kubectl get ingress -n demo-app
kubectl describe ingress sample-api -n demo-app

# Wait for IP address to be assigned
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' ingress/sample-api -n demo-app --timeout=300s
```

### Step 7: Test the Application

```bash
INGRESS_IP=$(kubectl get ingress -n demo-app sample-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test root endpoint
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/

# Test health endpoint
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/health

# Test info endpoint
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/info

# Test secret endpoint (Key Vault integration)
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/secret
```

**Expected response from `/secret`:**
```json
{
  "message": "Secrets retrieved from Azure Key Vault via CSI driver",
  "path": "/mnt/secrets",
  "secrets": {
    "db-connection-string": {
      "exists": true,
      "length": 94,
      "preview": "Server=demo-sql.data..."
    }
  },
  "status": "success",
  "timestamp": "2026-03-09T13:49:01.785080"
}
```

---

## Troubleshooting

### Pods Not Starting

**Check pod status:**
```bash
kubectl get pods -n demo-app
kubectl describe pod -n demo-app <pod-name>
```

**Common issues:**

1. **ImagePullBackOff**: ACR authentication problem
   ```bash
   # Verify ACR role assignment
   az role assignment list --scope /subscriptions/.../aksplatformdevacr --query "[?roleDefinitionName=='AcrPull']"
   ```

2. **CrashLoopBackOff**: Application error
   ```bash
   kubectl logs -n demo-app <pod-name>
   ```

3. **Pending**: Resource constraints or node issues
   ```bash
   kubectl describe pod -n demo-app <pod-name>
   # Look for "Events" section
   ```

### Secret Mount Issues

**Check CSI driver logs:**
```bash
kubectl logs -n kube-system -l app=secrets-store-csi-driver
```

**Verify Workload Identity:**
```bash
# Check ServiceAccount annotation
kubectl get serviceaccount demo-sa -n demo-app -o yaml | grep client-id

# Check federated credential
az identity federated-credential list \
  --identity-name aksplatform-dev-demo-app-wi \
  --resource-group aksplatform-dev-rg

# Check Key Vault role assignment
az role assignment list \
  --assignee $(terraform output -raw demo_app_workload_identity_client_id) \
  --all
```

**Test Key Vault access manually:**
```bash
# Using Azure CLI with your identity (should work if you have access)
az keyvault secret show --vault-name aksplatformdevkv --name db-connection-string
```

### Ingress Not Working

**Check ingress controller:**
```bash
kubectl get pods -n app-routing-system
```

**Check ingress resource:**
```bash
kubectl describe ingress sample-api -n demo-app
```

**Check ingress IP:**
```bash
kubectl get ingress -n demo-app -o wide
```

**Test without host header (direct IP):**
```bash
curl http://<INGRESS_IP>/health
```

### Policy Violations

**Check for violations:**
```bash
kubectl get constrainttemplate -o custom-columns=NAME:.metadata.name,VIOLATIONS:.status.totalViolations
```

**View specific violations:**
```bash
kubectl get constraint -o yaml
```

**Common policy requirements:**
- Resource requests and limits defined
- Non-root security context
- No privilege escalation
- Required labels: app, environment, owner

---

## Application Team Checklist

When deploying a new application, ensure:

### 1. Infrastructure (Platform Team Provides)

- [ ] Namespace created
- [ ] Workload Identity created via Terraform
  - [ ] Federated credential configured
  - [ ] Necessary role assignments (Key Vault, Storage, etc.)
- [ ] Key Vault secrets created
- [ ] ACR repository available

### 2. Kubernetes Manifests (Application Team Creates)

- [ ] **ServiceAccount** with Workload Identity annotation
  ```yaml
  annotations:
    azure.workload.identity/client-id: "<from-terraform-output>"
  labels:
    azure.workload.identity/use: "true"
  ```

- [ ] **SecretProviderClass** if using Key Vault
  ```yaml
  clientID: "<same-as-serviceaccount>"
  keyvaultName: "<vault-name>"
  ```

- [ ] **Deployment** with:
  - [ ] ServiceAccount reference
  - [ ] Resource requests and limits
  - [ ] Security context (non-root, no privilege escalation)
  - [ ] Liveness and readiness probes
  - [ ] Required labels (app, environment, owner)
  - [ ] Secret volume mount (if using CSI)

- [ ] **Service** (ClusterIP or LoadBalancer)

- [ ] **Ingress** with:
  - [ ] Correct ingress class: `webapprouting.kubernetes.azure.com`
  - [ ] Hostname configured
  - [ ] TLS configuration (if needed)

### 3. Security & Compliance

- [ ] No secrets in manifests (use Key Vault + CSI)
- [ ] Container runs as non-root user
- [ ] No privileged containers
- [ ] Read-only root filesystem (where possible)
- [ ] All required labels present
- [ ] Resource limits prevent resource exhaustion
- [ ] Network policies defined (if needed)

### 4. Testing

- [ ] Pods start successfully
- [ ] Secrets mounted correctly
- [ ] Ingress routing works
- [ ] Application responds to health checks
- [ ] No policy violations
- [ ] Logs appear in Log Analytics
- [ ] Metrics visible in Grafana

---

## Additional Resources

- [Azure Workload Identity Documentation](https://azure.github.io/azure-workload-identity/)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- [AKS Application Routing Add-on](https://learn.microsoft.com/azure/aks/app-routing)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

---

**Last Updated**: 2026-03-09
**Status**: Manual deployment guide for demo application
