# CI/CD Pipelines

This directory contains Azure DevOps pipeline definitions for automating infrastructure and application deployments.

## Overview

Two pipelines work together to provide complete automation:

1. **[infra-pipeline.yml](infra-pipeline.yml)** - Infrastructure deployment using Terraform
2. **[app-pipeline.yml](app-pipeline.yml)** - Application build and deployment

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Code Repository                        │
│                                                           │
│  ┌──────────────────┐         ┌──────────────────┐     │
│  │  infra/**        │         │  app/**          │     │
│  │  (Terraform)     │         │  (Application)   │     │
│  └────────┬─────────┘         └────────┬─────────┘     │
└───────────┼──────────────────────────────┼──────────────┘
            │                              │
            │ triggers                     │ triggers
            ↓                              ↓
┌─────────────────────┐        ┌─────────────────────┐
│ Infrastructure      │        │ Application         │
│ Pipeline            │        │ Pipeline            │
│                     │        │                     │
│ 1. Validate         │        │ 1. Build Image      │
│ 2. Plan             │        │ 2. Security Scan    │
│ 3. Apply (approval) │        │ 3. Validate K8s     │
│                     │        │ 4. Deploy (approval)│
└──────────┬──────────┘        └──────────┬──────────┘
           │                              │
           ↓                              ↓
    ┌────────────┐                 ┌────────────┐
    │   Azure    │                 │    ACR     │
    │ Resources  │                 │  + AKS     │
    └────────────┘                 └────────────┘
```

## Pipeline: Infrastructure (infra-pipeline.yml)

### Purpose
Automates Terraform deployment of AKS infrastructure including networking, monitoring, Key Vault, and ACR.

### Triggers
- **Branch**: `main`, `develop`
- **Path filters**: `infra/terraform/**`

### Stages

#### 1. Validate
- Install Terraform
- Initialize backend
- Check formatting (`terraform fmt -check`)
- Validate configuration (`terraform validate`)

#### 2. Plan
- Generate execution plan
- Publish plan as artifact
- Display changes for review

#### 3. Apply (requires approval)
- Apply Terraform changes
- Verify AKS cluster health
- Output deployment results

### Prerequisites

1. **Azure Service Connection**
   - Name: `azure-aks-platform-sp` (update in pipeline)
   - Type: Azure Resource Manager
   - Scope: Subscription level with Contributor access

2. **Terraform Backend**
   - Resource Group: `rg-terraform`
   - Storage Account: `sttfstateta`
   - Container: `tfstate`
   - Key: `azure-aks-dev.tfstate`

3. **Environment**
   - Create environment `aks-platform-dev` in Azure DevOps
   - Add approval gates as needed

### Setup Instructions

1. **Create Service Principal**
   ```bash
   az ad sp create-for-rbac \
     --name "sp-aks-platform-pipeline" \
     --role Contributor \
     --scopes /subscriptions/<SUBSCRIPTION_ID>
   ```

2. **Create Service Connection in Azure DevOps**
   - Project Settings → Service connections → New service connection
   - Choose "Azure Resource Manager"
   - Choose "Service Principal (manual)"
   - Enter the SP credentials from step 1
   - Name it `azure-aks-platform-sp`

3. **Create Pipeline**
   - Pipelines → New pipeline → Azure Repos Git
   - Select your repository
   - Choose "Existing Azure Pipelines YAML file"
   - Path: `/pipelines/infra-pipeline.yml`

4. **Configure Variables**
   Update these variables in the pipeline YAML:
   - `azureServiceConnection`: Your service connection name
   - `backendResourceGroup`, `backendStorageAccount`, etc.

## Pipeline: Application (app-pipeline.yml)

### Purpose
Builds container images, scans for vulnerabilities, and deploys applications to AKS.

### Triggers
- **Branch**: `main`, `develop`
- **Path filters**: `app/**`

### Stages

#### 1. Build
- Build Docker image for `sample-api`
- Tag with build ID and `latest`
- Push to Azure Container Registry
- Security scan with Trivy
- Publish Kubernetes manifests

#### 2. ValidateManifests
- Validate Kubernetes manifests with kubeval
- Check for syntax errors and deprecated APIs

#### 3. DeployDev (requires approval)
- Get AKS credentials
- Update image tag in deployment
- Apply all Kubernetes manifests
- Wait for rollout completion
- Verify deployment health

#### 4. RollbackOnFailure (conditional)
- Display rollback instructions if deployment fails

### Prerequisites

1. **Azure Container Registry Service Connection**
   - Name: `acr-connection` (update in pipeline)
   - Type: Docker Registry
   - Registry URL: `aksplatformdevacr.azurecr.io`

2. **Azure Service Connection** (same as infrastructure pipeline)
   - For AKS access

3. **Environment**
   - Create environment `aks-demo-app-dev` in Azure DevOps
   - Add approval gates as needed

### Setup Instructions

1. **Create ACR Service Connection**
   ```bash
   # Get ACR credentials
   az acr credential show --name aksplatformdevacr
   ```

   - Project Settings → Service connections → New service connection
   - Choose "Docker Registry"
   - Registry type: "Others"
   - Docker Registry: `https://aksplatformdevacr.azurecr.io`
   - Docker ID: (from command above)
   - Docker Password: (from command above)
   - Service connection name: `acr-connection`

   **Note**: For production, use managed identities instead of admin credentials.

2. **Create Pipeline**
   - Pipelines → New pipeline → Azure Repos Git
   - Select your repository
   - Choose "Existing Azure Pipelines YAML file"
   - Path: `/pipelines/app-pipeline.yml`

3. **Configure Variables**
   Update these variables in the pipeline YAML:
   - `dockerRegistryServiceConnection`: Your ACR service connection name
   - `containerRegistry`: Your ACR URL
   - `azureServiceConnection`: Your Azure service connection name
   - `aksResourceGroup`, `aksClusterName`: Match your environment

## Security Considerations

### Secrets Management
- ✅ **Use service connections** for credentials (not plain text variables)
- ✅ **Enable pipeline secrets** for sensitive values
- ✅ **Use managed identities** where possible
- ❌ **Never commit** service principal credentials to Git

### Image Security
- **Trivy scanning** runs on every image build
- Scans for HIGH and CRITICAL vulnerabilities
- Currently set to `continueOnError: true` (warns but doesn't block)
- For production: Set `exitCode: 1` to fail on critical vulnerabilities

### Approval Gates
- **Infrastructure Apply**: Requires manual approval
- **Application Deploy**: Requires manual approval
- Configure approvers in Azure DevOps Environments

## Pipeline Variables Reference

### Infrastructure Pipeline
| Variable | Default | Description |
|----------|---------|-------------|
| `terraformVersion` | `1.5.7` | Terraform version to use |
| `azureServiceConnection` | `azure-aks-platform-sp` | Azure service connection name |
| `backendResourceGroup` | `rg-terraform` | Terraform state resource group |
| `backendStorageAccount` | `sttfstateta` | Terraform state storage account |
| `backendContainer` | `tfstate` | Terraform state container |
| `backendKey` | `azure-aks-dev.tfstate` | Terraform state file key |

### Application Pipeline
| Variable | Default | Description |
|----------|---------|-------------|
| `dockerRegistryServiceConnection` | `acr-connection` | ACR service connection |
| `imageRepository` | `sample-api` | Container image name |
| `containerRegistry` | `aksplatformdevacr.azurecr.io` | ACR URL |
| `azureServiceConnection` | `azure-aks-platform-sp` | Azure service connection |
| `aksResourceGroup` | `aksplatform-dev-rg` | AKS resource group |
| `aksClusterName` | `aksplatform-dev-aks` | AKS cluster name |
| `k8sNamespace` | `demo-app` | Kubernetes namespace |

## Troubleshooting

### Infrastructure Pipeline Issues

**Problem**: Terraform init fails with "backend configuration changed"
```bash
# Solution: Delete the .terraform directory and reinitialize
# This is handled automatically in the pipeline
```

**Problem**: "grafana_admin_user_object_ids" not set
```bash
# Solution: Get your object ID
az ad signed-in-user show --query id -o tsv

# The pipeline automatically fetches this, but you can override it
```

**Problem**: State lock timeout
```bash
# Solution: Check for other running pipelines
# If needed, manually release the lock:
az storage blob lease break \
  --account-name sttfstateta \
  --container-name tfstate \
  --blob-name azure-aks-dev.tfstate
```

### Application Pipeline Issues

**Problem**: Docker build fails on M1/M2 Mac locally
```bash
# Solution: Use --platform flag
docker build --platform linux/amd64 -t myapp .
# Pipeline already includes this flag
```

**Problem**: Image push unauthorized
```bash
# Solution: Verify ACR service connection
# Ensure credentials are correct in Azure DevOps
az acr login --name aksplatformdevacr
```

**Problem**: Deployment times out
```bash
# Solution: Check pod status
kubectl get pods -n demo-app
kubectl describe pod <pod-name> -n demo-app
kubectl logs <pod-name> -n demo-app

# Common causes:
# - Image pull errors (check ACR integration)
# - Secret mount failures (check Workload Identity)
# - Resource limits too low
```

**Problem**: Rollout status stuck
```bash
# Solution: Check deployment events
kubectl describe deployment sample-api -n demo-app

# If needed, rollback manually:
kubectl rollout undo deployment/sample-api -n demo-app
```

## Best Practices

### Infrastructure Pipeline
1. **Always review the plan** before approving Apply stage
2. **Use separate pipelines** for different environments (dev, staging, prod)
3. **Enable branch policies** to require PR reviews before main branch changes
4. **Run plan on PR** to catch issues before merge
5. **Tag releases** after successful infrastructure deployments

### Application Pipeline
1. **Use semantic versioning** for image tags in production
2. **Run security scans** and block on critical vulnerabilities
3. **Test in dev** before promoting to higher environments
4. **Keep manifests in sync** between repository and cluster
5. **Enable deployment history** with `kubectl rollout` for easy rollbacks

### General
1. **Separate concerns**: Infrastructure vs. application pipelines
2. **Use environments**: For approval gates and deployment tracking
3. **Monitor pipeline runs**: Set up notifications for failures
4. **Keep pipelines fast**: Parallel stages where possible
5. **Document changes**: Update this README when modifying pipelines

## Pipeline Enhancements (Future)

### Infrastructure Pipeline
- [ ] Add drift detection (compare live vs. Terraform state)
- [ ] Add cost estimation (Infracost or similar)
- [ ] Multi-environment support (dev → staging → prod)
- [ ] Automated testing of provisioned resources

### Application Pipeline
- [ ] Multi-stage deployments (canary, blue-green)
- [ ] Automated smoke tests after deployment
- [ ] Integration with feature flags
- [ ] Automatic rollback on health check failures
- [ ] GitOps integration (ArgoCD, Flux)

## References

- [Azure DevOps Pipelines Documentation](https://learn.microsoft.com/azure/devops/pipelines/)
- [Terraform in Azure Pipelines](https://learn.microsoft.com/azure/devops/pipelines/tasks/reference/terraform-installer-v0)
- [Kubernetes Task for Azure Pipelines](https://learn.microsoft.com/azure/devops/pipelines/tasks/reference/kubernetes-v1)
- [Docker Task for Azure Pipelines](https://learn.microsoft.com/azure/devops/pipelines/tasks/reference/docker-v2)

---

**Last Updated**: 2026-03-10
