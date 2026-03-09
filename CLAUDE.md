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

# Get your Azure AD object ID (needed for Grafana admin access)
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

## Architecture Overview

### Infrastructure Layer Structure

The project uses a modular Terraform architecture with clear separation of concerns:

- **[infra/terraform/modules/](infra/terraform/modules/)**: Reusable Terraform modules
  - **[aks/](infra/terraform/modules/aks/)**: AKS cluster with OIDC issuer, Workload Identity, Azure Policy, CSI Driver, and Web App Routing (NGINX)
  - **[networking/](infra/terraform/modules/networking/)**: VNet, subnets, and Network Security Groups
  - **[monitoring/](infra/terraform/modules/monitoring/)**: Log Analytics, Azure Monitor workspace (Prometheus), and Managed Grafana
  - **[keyvault/](infra/terraform/modules/keyvault/)**: Key Vault with RBAC authorization

- **[infra/terraform/envs/dev/](infra/terraform/envs/dev/)**: Development environment configuration that orchestrates the modules

### Key Architecture Decisions

1. **Workload Identity over Pod Identity**: Uses OIDC federation for secretless authentication (Pod Identity is deprecated)
2. **Managed Prometheus/Grafana**: Reduces operational burden, Azure-native integration
3. **Application Routing Add-on**: Azure-managed NGINX ingress (supported through Nov 2026)
4. **Azure Policy**: Native compliance enforcement vs. self-managed OPA/Gatekeeper
5. **RBAC Authorization for Key Vault**: Modern approach instead of access policies

### Data Flow: Secrets Retrieval

1. Pod uses ServiceAccount with Workload Identity annotation (`azure.workload.identity/client-id`)
2. AKS exchanges pod token for Azure AD token via OIDC issuer
3. Azure AD validates federated credential (service account subject matches)
4. CSI driver mounts secrets from Key Vault using the Azure AD token
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

See [infra/terraform/envs/dev/main.tf:33-40](infra/terraform/envs/dev/main.tf#L33-L40) for naming logic.

## Project Status

**Current Status**: Infrastructure Complete - Application Deployment In Progress

### ✅ Completed Infrastructure
- Terraform modules for networking, AKS, monitoring, Key Vault
- AKS cluster with OIDC issuer and Workload Identity
- Azure Monitor workspace and Managed Grafana
- Log Analytics with Container Insights
- Key Vault with RBAC authorization
- NGINX ingress controller verified and tested
- Prometheus metrics collection validated
- Grafana integration confirmed
- Azure Policy active with 16 constraint templates (audit mode)
- Secrets Store CSI Driver ready for Key Vault integration
- Comprehensive architecture documentation

### 🔄 Next Steps
- Demo application deployment with Workload Identity
- Custom Grafana dashboards
- CI/CD pipeline automation

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

Override these in `terraform.tfvars` (create from `terraform.tfvars.example`).

## Important Files

- **[README.md](README.md)**: Project overview, getting started guide, architecture
- **[docs/architecture.md](docs/architecture.md)**: Comprehensive architecture documentation with data flows
- **[platform/policies/README.md](platform/policies/README.md)**: Azure Policy documentation
- **[platform/manifests/example-secretproviderclass.yaml](platform/manifests/example-secretproviderclass.yaml)**: CSI driver example
- **[scripts/verify-platform.sh](scripts/verify-platform.sh)**: Automated platform verification script
- **[docs/decisions.md](docs/decisions.md)**: Architecture Decision Records (coming soon)
- **[docs/operations.md](docs/operations.md)**: Operational runbooks (coming soon)
- **[.gitignore](.gitignore)**: Ensures secrets and state files are not committed
