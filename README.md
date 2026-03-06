# Azure AKS Enterprise Platform Baseline

> A production-ready Azure Kubernetes Service (AKS) landing zone demonstrating platform engineering best practices with security, observability, and operational readiness.

## Overview

This project delivers a secure, observable, and reusable AKS platform baseline for enterprise internal workloads. It showcases modern Azure-native patterns for container platform engineering, focusing on operational excellence rather than application features.

### What This Project Demonstrates

- **Platform Engineering**: Reusable infrastructure patterns for enterprise AKS deployments
- **Security Hardening**: Workload Identity for secretless deployments, Azure Policy guardrails
- **Operational Readiness**: Day-1 observability with managed Prometheus and Grafana
- **DevOps Best Practices**: Infrastructure as Code with Terraform, clear separation of concerns
- **Enterprise Patterns**: Azure-native managed services, RBAC-based security model

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Subscription                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Resource Group (Platform)                 │  │
│  │                                                         │  │
│  │  ┌──────────────┐      ┌─────────────────┐            │  │
│  │  │   AKS Cluster│      │  Azure Monitor  │            │  │
│  │  │              │◄─────│   Workspace     │            │  │
│  │  │  - OIDC      │      │  (Prometheus)   │            │  │
│  │  │  - Workload  │      └─────────────────┘            │  │
│  │  │    Identity  │                                      │  │
│  │  │  - App       │      ┌─────────────────┐            │  │
│  │  │    Routing   │◄─────│ Azure Managed   │            │  │
│  │  │    (NGINX)   │      │    Grafana      │            │  │
│  │  │  - CSI       │      └─────────────────┘            │  │
│  │  │    Driver    │                                      │  │
│  │  │  - Azure     │      ┌─────────────────┐            │  │
│  │  │    Policy    │      │  Log Analytics  │            │  │
│  │  └──────┬───────┘      │   Workspace     │            │  │
│  │         │              └─────────────────┘            │  │
│  │         │                                              │  │
│  │         │              ┌─────────────────┐            │  │
│  │         └──────────────►  Azure Key      │            │  │
│  │                        │     Vault       │            │  │
│  │                        └─────────────────┘            │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Core Infrastructure
- **Azure Kubernetes Service (AKS)** - Container orchestration
- **Terraform** - Infrastructure as Code
- **Helm** - Kubernetes package management
- **Azure DevOps Pipelines** - CI/CD automation

### Observability
- **Azure Monitor managed Prometheus** - Metrics collection
- **Azure Managed Grafana** - Dashboards and visualization
- **Container Insights / Log Analytics** - Centralized logging

### Security & Identity
- **Azure Workload Identity (OIDC)** - Secretless authentication
- **Azure Key Vault + CSI Driver** - Secrets management
- **Azure Policy for AKS** - Compliance guardrails

### Networking
- **Application Routing Add-on (NGINX)** - Ingress controller
- **Azure Virtual Network** - Network isolation

## Repository Structure

```
azure-aks-enterprise-platform-baseline/
├── docs/                    # Architecture and operational documentation
├── infra/terraform/         # Terraform infrastructure code
│   ├── modules/            # Reusable Terraform modules
│   │   ├── aks/           # AKS cluster with OIDC & Workload Identity
│   │   ├── networking/    # VNet, subnets, NSGs
│   │   ├── monitoring/    # Prometheus, Grafana, Log Analytics
│   │   └── keyvault/      # Key Vault with RBAC
│   └── envs/dev/          # Development environment
├── platform/               # Platform-level Kubernetes resources
│   ├── helm-values/       # Helm chart values
│   ├── manifests/         # Core platform manifests
│   └── policies/          # Azure Policy definitions
├── app/                    # Demo application
│   ├── sample-api/        # Python REST API
│   └── k8s/               # Kubernetes manifests
└── pipelines/             # CI/CD pipeline definitions
```

## Prerequisites

### Tools Required
- **Terraform** >= 1.5
- **Azure CLI** >= 2.50
- **kubectl** >= 1.28
- **Helm** >= 3.12
- **Git**

### Azure Requirements
- Azure subscription with **Contributor** role
- Azure DevOps organization (for CI/CD pipelines)
- Sufficient quota for:
  - 3-5 VMs for AKS nodes
  - Log Analytics workspace
  - Azure Monitor workspace
  - Managed Grafana instance
  - Key Vault

### Estimated Monthly Cost
- **AKS** (3 x Standard_D2s_v3): ~$150-200
- **Log Analytics**: ~$15-20
- **Azure Monitor workspace**: ~$10-15
- **Managed Grafana**: ~$25-30
- **Key Vault**: ~$1-5
- **Total**: ~$200-270/month

💡 **Tip**: Tear down resources after testing to minimize costs.

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/azure-aks-enterprise-platform-baseline.git
cd azure-aks-enterprise-platform-baseline
```

### 2. Configure Azure Credentials

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "Your Subscription Name"

# Get your Azure AD object ID for Grafana admin access
az ad signed-in-user show --query id -o tsv
```

### 3. Configure Terraform Variables

```bash
cd infra/terraform/envs/dev

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# - Add your Azure AD object ID to grafana_admin_user_object_ids
# - Adjust location, project name, and other settings as needed
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

⏱️ **Deployment time**: Approximately 15-20 minutes

### 5. Access the AKS Cluster

```bash
# Get cluster credentials
az aks get-credentials \
  --resource-group aksplatform-dev-rg \
  --name aksplatform-dev-aks

# Verify connectivity
kubectl get nodes
kubectl get pods --all-namespaces
```

### 6. Access Grafana

The Grafana endpoint URL is output after Terraform deployment:

```bash
terraform output grafana_endpoint
```

Access Grafana using your Azure AD credentials (you must be in the `grafana_admin_user_object_ids` list).

## Project Phases

### ✅ Phase 1: Core Infrastructure (Current)
- [x] Terraform modules for networking, AKS, monitoring, Key Vault
- [x] AKS cluster with OIDC issuer and Workload Identity
- [x] Azure Monitor workspace and Managed Grafana
- [x] Log Analytics with Container Insights
- [x] Key Vault with RBAC authorization

### 🔄 Phase 2: Cluster Platform Layer (Next)
- [ ] Enable Application Routing add-on (NGINX ingress)
- [ ] Configure managed Prometheus scraping
- [ ] Connect Grafana with default dashboards
- [ ] Enable Azure Policy with baseline policies
- [ ] Verify Secrets Store CSI Driver integration

### ⏳ Phase 3: Demo Workload
- [ ] Python REST API with health and secret endpoints
- [ ] Workload Identity configuration
- [ ] Key Vault secret integration via CSI driver
- [ ] Ingress route configuration
- [ ] Policy compliance validation

### ⏳ Phase 4: Guardrails & Operations
- [ ] Custom Grafana dashboards (cluster health, ingress metrics)
- [ ] Enhanced policy definitions
- [ ] Comprehensive documentation (architecture, operations, ADRs)
- [ ] Code cleanup and formatting

### ⏳ Phase 5: CI/CD Automation
- [ ] Infrastructure pipeline (Terraform plan/apply)
- [ ] Application pipeline (build, push, deploy)
- [ ] Security scanning integration
- [ ] Final validation and screenshots

## Key Features

### Security
✅ **Workload Identity**: Secretless authentication using OIDC federation
✅ **RBAC Authorization**: Azure AD integration for Kubernetes and Key Vault
✅ **Network Isolation**: VNet integration with network policies
✅ **Policy Enforcement**: Azure Policy add-on for compliance guardrails
✅ **Secrets Management**: CSI driver for mounting Key Vault secrets

### Observability
✅ **Metrics**: Managed Prometheus with automatic cluster scraping
✅ **Dashboards**: Azure Managed Grafana with default AKS dashboards
✅ **Logging**: Container Insights with Log Analytics workspace
✅ **Monitoring**: Data collection rules for Prometheus metrics

### Operations
✅ **Infrastructure as Code**: Modular Terraform for repeatability
✅ **Add-on Management**: Azure-managed ingress, policy, and CSI drivers
✅ **Day-2 Operations**: Built-in observability from deployment

## Component Responsibilities

### Platform Team Owns
- AKS cluster lifecycle management
- Ingress controller configuration
- Observability stack (Prometheus, Grafana, logs)
- Key Vault provisioning and access policies
- Network policies and security baselines
- Azure Policy definitions and assignments
- CI/CD pipelines for infrastructure

### Application Teams Own
- Kubernetes manifests for workloads
- Ingress resources for routing
- ServiceAccount + SecretProviderClass configurations
- Application-specific Grafana dashboards
- Resource quotas within namespaces

## Documentation

- [plan.md](plan.md) - Detailed implementation plan with phases and timelines
- [docs/architecture.md](docs/architecture.md) - *(Coming in Phase 4)* Architecture diagrams and design
- [docs/decisions.md](docs/decisions.md) - *(Coming in Phase 4)* Architecture Decision Records (ADRs)
- [docs/operations.md](docs/operations.md) - *(Coming in Phase 4)* Operational runbooks
- [docs/dashboards.md](docs/dashboards.md) - *(Coming in Phase 4)* Grafana dashboard catalog

## Design Decisions

### Why Workload Identity over Pod Identity?
Workload Identity is the modern, Microsoft-recommended approach using OIDC federation. Pod Identity is deprecated.

### Why Managed Prometheus/Grafana?
Reduces operational burden, provides automatic updates, and integrates seamlessly with Azure Monitor ecosystem.

### Why Application Routing Add-on?
Azure-managed NGINX ingress with support through November 2026. Simpler than self-managed alternatives while maintaining production readiness.

### Why Azure Policy over OPA/Gatekeeper?
Native Azure integration, centralized policy management, and enterprise compliance reporting.

## Cleanup

To destroy all resources and avoid ongoing costs:

```bash
cd infra/terraform/envs/dev
terraform destroy
```

⚠️ **Warning**: This will permanently delete all resources, including any data in Key Vault (subject to soft-delete retention).

## Contributing

This is a portfolio/reference project. Feel free to fork and adapt for your own use cases.

## License

MIT License - See LICENSE file for details

## References

- [Azure AKS Documentation](https://learn.microsoft.com/azure/aks/)
- [Azure Workload Identity](https://azure.github.io/azure-workload-identity/)
- [Azure Monitor managed Prometheus](https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-overview)
- [Azure Managed Grafana](https://learn.microsoft.com/azure/managed-grafana/)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- [Azure Policy for AKS](https://learn.microsoft.com/azure/aks/policy-reference)

---

**Project Status**: Phase 1 Complete - Core Infrastructure
**Last Updated**: 2026-03-06
**Next Milestone**: Phase 2 - Cluster Platform Layer
