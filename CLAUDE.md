# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Azure AKS Enterprise Platform Baseline - a production-ready Kubernetes landing zone demonstrating platform engineering best practices. The project focuses on infrastructure, security, and observability rather than application features.

**Key technologies**: Azure Kubernetes Service (AKS), Terraform, Azure Workload Identity (OIDC), Azure Monitor (managed Prometheus), Azure Managed Grafana, Key Vault with CSI Driver, Azure Policy.

## Common Commands

### Terraform Operations

All Terraform operations should be executed from `infra/terraform/envs/dev/`:

```bash
cd infra/terraform/envs/dev

# Initialize Terraform (first time or after module changes)
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive ../../

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy all resources
terraform destroy
```

### AKS Cluster Access

```bash
# Get cluster credentials
az aks get-credentials \
  --resource-group aksplatform-dev-rg \
  --name aksplatform-dev-aks

# Verify connectivity
kubectl get nodes
kubectl get pods --all-namespaces

# Get cluster OIDC issuer URL (for Workload Identity)
az aks show \
  --resource-group aksplatform-dev-rg \
  --name aksplatform-dev-aks \
  --query "oidcIssuerProfile.issuerUrl" -o tsv
```

### Azure Monitor & Grafana

```bash
# Get Grafana endpoint URL
terraform output -raw grafana_endpoint

# Get your Entra ID object ID (needed for Grafana admin access)
az ad signed-in-user show --query id -o tsv
```

### Key Vault Operations

```bash
# Create a test secret
az keyvault secret set \
  --vault-name aksplatformdevkv \
  --name db-connection-string \
  --value "Server=myserver;Database=mydb"

# List secrets
az keyvault secret list --vault-name aksplatformdevkv
```

### Azure Container Registry Operations

```bash
# Log in to ACR
az acr login --name aksplatformdevacr

# Build and push an image (NOTE: Build for AMD64 on M1/M2 Macs)
docker build --platform linux/amd64 -t aksplatformdevacr.azurecr.io/sample-api:v1.1.0-amd64 app/sample-api/
docker push aksplatformdevacr.azurecr.io/sample-api:v1.1.0-amd64

# List images in ACR
az acr repository list --name aksplatformdevacr -o table

# List tags for a specific image
az acr repository show-tags --name aksplatformdevacr --repository sample-api -o table

# Get ACR login server
terraform output -raw acr_login_server
```

### Application Deployment Operations

```bash
# Deploy the demo application (all manifests including PodMonitor)
kubectl apply -f app/k8s/

# Or deploy individually in order:
kubectl apply -f app/k8s/namespace.yaml
kubectl apply -f app/k8s/serviceaccount.yaml
kubectl apply -f app/k8s/secretproviderclass.yaml
kubectl apply -f app/k8s/deployment.yaml
kubectl apply -f app/k8s/service.yaml
kubectl apply -f app/k8s/ingress.yaml
kubectl apply -f app/k8s/podmonitor.yaml  # For Prometheus metrics scraping

# Check deployment status
kubectl get pods -n demo-app
kubectl get ingress -n demo-app
kubectl get podmonitor -n demo-app

# Test the application via ingress
INGRESS_IP=$(kubectl get ingress -n demo-app sample-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/health
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/secret
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/metrics  # Prometheus metrics

# View logs
kubectl logs -n demo-app -l app=sample-api --tail=50

# Verify secret is mounted
kubectl exec -n demo-app <pod-name> -- ls -la /mnt/secrets/
kubectl exec -n demo-app <pod-name> -- cat /mnt/secrets/db-connection-string
```

### Workload Identity Operations

```bash
# Get workload identity client ID from Terraform
terraform output -raw demo_app_workload_identity_client_id

# View the managed identity
az identity show --name aksplatform-dev-demo-app-wi --resource-group aksplatform-dev-rg

# List federated credentials
az identity federated-credential list \
  --identity-name aksplatform-dev-demo-app-wi \
  --resource-group aksplatform-dev-rg

# Verify role assignments
az role assignment list \
  --assignee $(terraform output -raw demo_app_workload_identity_client_id) \
  --all
```

### Observability & Monitoring Operations

```bash
# View Grafana dashboards
terraform output -raw grafana_endpoint

# Check Azure Monitor metrics collection
kubectl get pods -n kube-system | grep ama-metrics

# Verify NGINX metrics are being scraped
kubectl get servicemonitor -n app-routing-system

# Verify application metrics are being scraped
kubectl get podmonitor -n demo-app

# Test application metrics endpoint
kubectl port-forward -n demo-app service/sample-api 8080:80
curl http://localhost:8080/metrics | grep http_requests_total

# Generate test traffic for dashboards
./scripts/load-test/quick-load-test.sh

# Check Azure Monitor operator logs
kubectl logs -n kube-system -l app.kubernetes.io/component=target-allocator --tail=50
```

## Architecture Overview

### Infrastructure Layer Structure

The project uses a modular Terraform architecture with clear separation of concerns:

- **[infra/terraform/modules/](infra/terraform/modules/)**: Reusable Terraform modules
  - **[aks/](infra/terraform/modules/aks/)**: AKS cluster with OIDC issuer, Workload Identity, Azure Policy, CSI Driver, and Web App Routing (NGINX)
  - **[networking/](infra/terraform/modules/networking/)**: VNet, subnets, and Network Security Groups
  - **[monitoring/](infra/terraform/modules/monitoring/)**: Log Analytics, Azure Monitor workspace (Prometheus), and Managed Grafana
  - **[keyvault/](infra/terraform/modules/keyvault/)**: Key Vault with RBAC authorization
  - **[acr/](infra/terraform/modules/acr/)**: Azure Container Registry with AKS integration (AcrPull role assignment to kubelet identity)
  - **[workload-identity/](infra/terraform/modules/workload-identity/)**: User Assigned Managed Identity with federated credentials for Workload Identity

- **[infra/terraform/envs/dev/](infra/terraform/envs/dev/)**: Development environment configuration that orchestrates the modules

### Key Architecture Decisions

1. **Workload Identity over Pod Identity**: Uses OIDC federation for secretless authentication (Pod Identity is deprecated)
2. **Managed Prometheus/Grafana**: Reduces operational burden, Azure-native integration
3. **Application Routing Add-on**: Azure-managed NGINX ingress (supported through Nov 2026)
4. **Azure Policy**: Native compliance enforcement vs. self-managed OPA/Gatekeeper
5. **RBAC Authorization for Key Vault**: Modern approach instead of access policies

### Data Flow: Secrets Retrieval

1. Pod uses ServiceAccount with Workload Identity annotation (`azure.workload.identity/client-id`)
2. AKS exchanges pod token for Entra ID token via OIDC issuer
3. Entra ID validates federated credential (service account subject matches)
4. CSI driver mounts secrets from Key Vault using the Entra ID token
5. Secrets appear as files in pod filesystem

### Monitoring Integration

1. **Metrics Collection**: Data Collection Rule (DCR) + Data Collection Endpoint (DCE) configured in [infra/terraform/envs/dev/main.tf:106-147](infra/terraform/envs/dev/main.tf#L106-L147)
2. **Prometheus Scraping**: Azure Monitor workspace receives metrics from AKS
3. **Grafana Integration**: Grafana connects to Azure Monitor workspace via [azure_monitor_workspace_integrations](infra/terraform/modules/monitoring/main.tf#L46-L48)
4. **Logs**: Container Insights sends logs to Log Analytics workspace

## Terraform Module Guidelines

### Module Interdependencies

- **Networking** must be created before AKS (subnet dependency)
- **Monitoring** must be created before AKS (Log Analytics workspace dependency)
- **AKS** depends on both networking and monitoring modules (see [main.tf:91](infra/terraform/envs/dev/main.tf#L91))
- **Key Vault** can be created independently but requires tenant ID from data source
- **ACR** depends on AKS (for AcrPull role assignment to AKS kubelet identity)
- **Workload Identity** depends on AKS (for OIDC issuer URL) and Key Vault (for role assignment)

### Adding New Resources

When adding resources to modules:

1. Add variables to `modules/<module>/variables.tf`
2. Add resource definitions to `modules/<module>/main.tf`
3. Add outputs to `modules/<module>/outputs.tf`
4. Reference in environment config at `envs/dev/main.tf`
5. Run `terraform fmt -recursive` before committing

### AKS Add-ons Currently Enabled

The AKS cluster has these add-ons pre-configured in [infra/terraform/modules/aks/main.tf](infra/terraform/modules/aks/main.tf):

- **OIDC Issuer + Workload Identity** (lines 10-11): For secretless authentication
- **Azure Policy** (line 54): For governance and compliance
- **Secrets Store CSI Driver** (lines 57-59): For Key Vault integration
- **Web App Routing** (lines 62-64): NGINX ingress controller
- **Container Insights** (lines 44-51): Monitoring and logging

## Platform Team vs. Application Team Responsibilities

### Platform Team Owns (this repository)

- Terraform infrastructure code in `infra/`
- AKS cluster lifecycle and configuration
- Ingress controller (NGINX via Web App Routing)
- Observability stack configuration
- Key Vault provisioning and RBAC
- Network policies and security baselines
- Azure Policy definitions in `platform/policies/`
- Platform-level Kubernetes resources in `platform/manifests/`

### Application Teams Own

- Kubernetes manifests in `app/k8s/` for their workloads
- Ingress resources (routing rules)
- ServiceAccount + SecretProviderClass configurations
- Application code in `app/sample-api/`
- Application-specific dashboards

## Security Considerations

### Sensitive Data

- Never commit `.tfvars` files (except `.tfvars.example`)
- Never commit kubeconfig files
- Never commit secrets, keys, or certificates
- Use Azure Key Vault for all secrets
- Use Workload Identity for authentication (no service principal keys)

### RBAC Model

- Key Vault uses RBAC authorization (not access policies)
- AKS has system-assigned managed identity
- Grafana has system-assigned managed identity with Monitoring Reader role
- Current user gets Key Vault Administrator role during Terraform apply (see [infra/terraform/modules/keyvault/main.tf:33-37](infra/terraform/modules/keyvault/main.tf#L33-L37))

## Naming Conventions

Resources follow this pattern: `{project_name}-{environment}-{resource_type}`

Examples:
- Resource Group: `aksplatform-dev-rg`
- AKS Cluster: `aksplatform-dev-aks`
- VNet: `aksplatform-dev-vnet`
- Key Vault: `aksplatformdevkv` (no dashes due to naming restrictions)
- ACR: `aksplatformdevacr` (no dashes, alphanumeric only)

See [infra/terraform/envs/dev/main.tf:33-42](infra/terraform/envs/dev/main.tf#L33-L42) for naming logic.

## Project Status

**Current Status**: ✅ Complete - Production-Ready AKS Platform

### ✅ Completed Infrastructure (Phase 1-2)
- Terraform modules for networking, AKS, monitoring, Key Vault, ACR, and workload-identity
- AKS cluster with OIDC issuer and Workload Identity
- Azure Monitor workspace and Managed Grafana
- Log Analytics with Container Insights
- Key Vault with RBAC authorization
- Azure Container Registry with AKS kubelet identity integration
- NGINX ingress controller (Web App Routing addon)
- Azure Policy active with 16 constraint templates (audit mode)
- Secrets Store CSI Driver integrated with Key Vault

### ✅ Completed Demo Application (Phase 3)
- Sample API application deployed to AKS
  - Container image: `aksplatformdevacr.azurecr.io/sample-api:v1.1.0-amd64`
  - Endpoints: `/`, `/health`, `/info`, `/secret`, `/metrics`
  - **Prometheus metrics instrumentation** (http_requests_total, http_request_duration_seconds)
- Kubernetes manifests: namespace, serviceaccount, deployment, service, ingress, secretproviderclass, podmonitor
- Azure Workload Identity fully configured via Terraform
  - User Assigned Managed Identity: `aksplatform-dev-demo-app-wi`
  - Federated credential with AKS OIDC
  - Key Vault Secrets User role automatically assigned
- Secret retrieval from Key Vault via CSI driver verified
- Ingress routing working
- Zero policy violations

### ✅ Completed Observability (Phase 4)
- **Custom Grafana dashboards** deployed and operational:
  - Cluster Health Overview (node/cluster metrics)
  - NGINX Ingress Metrics (request rates, latency, errors)
  - Application Health (pod status, application metrics)
- **Prometheus metrics collection**:
  - NGINX Ingress Controller (ServiceMonitor)
  - Sample API application (PodMonitor)
  - Default targets (kubelet, cadvisor, kube-state-metrics, node-exporter)
- Load testing scripts for dashboard validation

### Infrastructure Verification

Run the verification script to check all platform components:

```bash
./scripts/verify-platform.sh
```

## Backend Configuration

Terraform state is stored in Azure Storage:
- Resource Group: `rg-terraform`
- Storage Account: `sttfstateta`
- Container: `tfstate`
- State File: `azure-aks-dev.tfstate`

See [infra/terraform/envs/dev/main.tf:12-17](infra/terraform/envs/dev/main.tf#L12-L17).

## Default Configuration

Default values from [infra/terraform/envs/dev/variables.tf](infra/terraform/envs/dev/variables.tf):
- Region: `westeurope`
- Environment: `dev`
- Kubernetes Version: `1.33`
- Node Count: `3` (Standard_D2s_v3)
- Auto-scaling: Disabled by default
- ACR SKU: `Basic`

Override these in `terraform.tfvars` (create from `terraform.tfvars.example`).

## Important Files

### Documentation
- **[README.md](README.md)**: Project overview, getting started guide, architecture
- **[docs/architecture.md](docs/architecture.md)**: Comprehensive architecture documentation with data flows
- **[docs/operations.md](docs/operations.md)**: Operational runbooks and procedures
- **[docs/dashboards.md](docs/dashboards.md)**: Grafana dashboards documentation
- **[docs/decisions.md](docs/decisions.md)**: Architecture Decision Records

### Platform Configuration
- **[platform/policies/README.md](platform/policies/README.md)**: Azure Policy documentation
- **[platform/manifests/nginx-servicemonitor.yaml](platform/manifests/nginx-servicemonitor.yaml)**: NGINX metrics scraping configuration
- **[platform/manifests/grafana-dashboards/](platform/manifests/grafana-dashboards/)**: Custom Grafana dashboard definitions

### Application Resources
- **[app/sample-api/](app/sample-api/)**: Demo Python Flask API with Prometheus instrumentation
- **[app/k8s/](app/k8s/)**: Kubernetes manifests including PodMonitor for metrics

### Scripts
- **[scripts/verify-platform.sh](scripts/verify-platform.sh)**: Automated platform verification script
- **[scripts/load-test/](scripts/load-test/)**: Load testing scripts for dashboard validation

### Configuration
- **[.gitignore](.gitignore)**: Ensures secrets and state files are not committed
