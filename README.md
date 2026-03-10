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

### Container Registry
- **Azure Container Registry (ACR)** - Private container image storage with AKS integration

## Repository Structure

```
azure-aks-enterprise-platform-baseline/
├── docs/                    # Architecture and operational documentation
├── infra/terraform/         # Terraform infrastructure code
│   ├── modules/            # Reusable Terraform modules
│   │   ├── aks/           # AKS cluster with OIDC & Workload Identity
│   │   ├── networking/    # VNet, subnets, NSGs
│   │   ├── monitoring/    # Prometheus, Grafana, Log Analytics
│   │   ├── keyvault/      # Key Vault with RBAC
│   │   └── acr/           # Azure Container Registry with AKS integration
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
  - Azure Container Registry

### Estimated Monthly Cost
- **AKS** (3 x Standard_D2s_v3): ~$150-200
- **Log Analytics**: ~$15-20
- **Azure Monitor workspace**: ~$10-15
- **Managed Grafana**: ~$25-30
- **Azure Container Registry** (Basic): ~$5
- **Key Vault**: ~$1-5
- **Total**: ~$205-275/month

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

# Get your Entra ID object ID for Grafana admin access
az ad signed-in-user show --query id -o tsv
```

### 3. Configure Terraform Variables

```bash
cd infra/terraform/envs/dev

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# - Add your Entra ID object ID to grafana_admin_user_object_ids
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

Access Grafana using your Entra ID credentials (you must be in the `grafana_admin_user_object_ids` list).

## Current Implementation Status

### ✅ Production-Ready Platform (Complete)

**Infrastructure:**
- [x] Terraform modules for networking, AKS, monitoring, Key Vault, ACR, Workload Identity
- [x] AKS cluster with OIDC issuer and Workload Identity
- [x] Azure Monitor workspace and Managed Grafana
- [x] Log Analytics with Container Insights
- [x] Key Vault with RBAC authorization
- [x] Azure Container Registry with AKS integration
- [x] Application Routing add-on (NGINX ingress)
- [x] Azure Policy with 16 baseline constraints
- [x] Secrets Store CSI Driver integration

**Demo Application:**
- [x] Sample Python Flask API with Prometheus instrumentation
- [x] Workload Identity integration (secretless Key Vault access)
- [x] Kubernetes manifests (deployment, service, ingress, podmonitor)
- [x] Metrics collection via PodMonitor

**Observability:**
- [x] Custom Grafana dashboards (Cluster Health, Ingress Metrics, Application Health)
- [x] Prometheus metrics collection (NGINX + application metrics)
- [x] ServiceMonitor for NGINX ingress controller
- [x] Load testing scripts for dashboard validation

**CI/CD Automation:**
- [x] Infrastructure pipeline for Terraform deployments
- [x] Application pipeline for container builds and deployments
- [x] Automated validation (terraform fmt, validate, kubeval)
- [x] Security scanning with Trivy
- [x] Manual approval gates for production changes
- [x] Rollback procedures documented

## Key Features

### Security
✅ **Workload Identity**: Secretless authentication using OIDC federation
✅ **RBAC Authorization**: Entra ID integration for Kubernetes and Key Vault
✅ **Network Isolation**: VNet integration with network policies
✅ **Policy Enforcement**: Azure Policy add-on for compliance guardrails
✅ **Secrets Management**: CSI driver for mounting Key Vault secrets

### Observability
✅ **Metrics**: Managed Prometheus with cluster-wide metrics collection (NGINX + applications)
✅ **Dashboards**: Azure Managed Grafana with 3 custom dashboards (cluster, ingress, application)
✅ **Logging**: Container Insights with Log Analytics workspace
✅ **Application Instrumentation**: Sample API with prometheus-client for HTTP metrics
✅ **ServiceMonitor/PodMonitor**: Automated metrics scraping configuration

### Operations
✅ **Infrastructure as Code**: Modular Terraform for repeatability
✅ **Add-on Management**: Azure-managed ingress, policy, and CSI drivers
✅ **Day-2 Operations**: Built-in observability from deployment
✅ **CI/CD Pipelines**: Automated deployment workflows with approval gates

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

- **[docs/architecture.md](docs/architecture.md)** - Architecture diagrams, data flows, and component details
- **[docs/operations.md](docs/operations.md)** - Operational runbooks, troubleshooting, and day-2 operations
- **[docs/dashboards.md](docs/dashboards.md)** - Grafana dashboard catalog and usage guide
- **[docs/cicd-architecture.md](docs/cicd-architecture.md)** - CI/CD pipeline architecture and deployment workflows
- **[docs/decisions.md](docs/decisions.md)** - Architecture Decision Records (ADRs)
- **[docs/app-deployment.md](docs/app-deployment.md)** - Application deployment guide
- **[platform/policies/README.md](platform/policies/README.md)** - Azure Policy documentation and guidelines
- **[pipelines/README.md](pipelines/README.md)** - CI/CD pipeline setup and configuration

## Design Decisions

### Why Workload Identity over Pod Identity?
Workload Identity is the modern, Microsoft-recommended approach using OIDC federation. Pod Identity is deprecated.

### Why Managed Prometheus/Grafana?
Reduces operational burden, provides automatic updates, and integrates seamlessly with Azure Monitor ecosystem.

### Why Application Routing Add-on?
Azure-managed NGINX ingress with support through November 2026. Simpler than self-managed alternatives while maintaining production readiness.

### Why Azure Policy over OPA/Gatekeeper?
Native Azure integration, centralized policy management, and enterprise compliance reporting.

## Screenshots and Verification

### Platform Verification

The platform includes a comprehensive verification script to validate all components:

```bash
./scripts/verify-platform.sh
```

This script checks:
- ✅ AKS cluster health and node status
- ✅ NGINX ingress controller deployment
- ✅ Azure Monitor metrics collection
- ✅ Grafana connectivity
- ✅ Azure Policy compliance
- ✅ CSI driver functionality
- ✅ Application deployment status
- ✅ Workload Identity configuration
- ✅ ACR integration

### Key Metrics

| Component | Status | Details |
|-----------|--------|---------|
| **AKS Cluster** | ✅ Running | 3 nodes (Standard_D2s_v3), Kubernetes 1.33 |
| **NGINX Ingress** | ✅ Running | 2 replicas, External IP allocated |
| **Prometheus** | ✅ Scraping | ~50 targets, 1000+ metrics |
| **Grafana** | ✅ Connected | 3 custom dashboards, Azure AD auth |
| **Azure Policy** | ✅ Active | 16 constraints, 0 violations |
| **Sample App** | ✅ Deployed | 2 replicas, secrets mounted, metrics exposed |
| **ACR Integration** | ✅ Configured | AcrPull role assigned to kubelet identity |

### Application Endpoints

Once deployed, the sample application is accessible at:

```bash
# Get ingress IP
kubectl get ingress -n demo-app sample-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Test endpoints
curl -H "Host: demo.aks.internal" http://<INGRESS_IP>/health
curl -H "Host: demo.aks.internal" http://<INGRESS_IP>/info
curl -H "Host: demo.aks.internal" http://<INGRESS_IP>/secret
curl -H "Host: demo.aks.internal" http://<INGRESS_IP>/metrics
```

### Grafana Dashboards

Access Grafana to view operational dashboards:

1. Get Grafana endpoint: `terraform output grafana_endpoint`
2. Open in browser (Azure AD authentication)
3. Navigate to **Dashboards** to view:
   - **Cluster Health Overview**: Node and pod metrics
   - **NGINX Ingress Metrics**: Request rates and latencies
   - **Application Health**: Sample API metrics and logs

## What I Learned

This project deepened my understanding of several key areas:

### Platform Engineering Mindset

**Separation of Concerns**: The distinction between platform team responsibilities (infrastructure, observability, policies) and application team responsibilities (workloads, routing, dashboards) became clear through this implementation. This separation enables scalability in organizations.

**Managed Services Trade-offs**: Using Azure-managed Prometheus and Grafana reduced operational complexity but introduced vendor lock-in. The key learning was evaluating when operational burden justifies managed services versus self-hosted solutions.

### Azure Workload Identity Deep Dive

**OIDC Federation Mechanics**: Understanding how Kubernetes ServiceAccount tokens are exchanged for Azure AD tokens through federated credentials was crucial. The flow involves:
1. AKS OIDC issuer signs ServiceAccount tokens
2. Azure AD validates the token against federated credential configuration
3. Application receives Azure AD token for resource access

**Common Pitfalls**: The subject claim in federated credentials must exactly match `system:serviceaccount:<namespace>:<serviceaccount-name>`. Mismatches result in cryptic authentication errors.

### Terraform Module Design

**Dependency Management**: Learned to properly sequence module dependencies (networking → monitoring → AKS) to avoid circular dependencies and race conditions.

**State Management**: Remote state with locking in Azure Storage prevents concurrent modifications, but requires careful handling of state locks during pipeline failures.

**Output Propagation**: Passing outputs between modules (e.g., OIDC issuer URL from AKS to workload-identity module) requires careful planning of data flows.

### Azure Policy vs. OPA Gatekeeper

**Native Integration**: Azure Policy's integration with Azure Security Center and Compliance Dashboard provides enterprise-wide visibility that self-hosted OPA lacks.

**Audit vs. Enforcement**: Running policies in audit mode during initial deployment allowed us to identify issues without blocking workloads. Transitioning to enforcement mode requires careful analysis of violation reports.

### Observability at Scale

**Metrics Cardinality**: Learned that label cardinality in Prometheus metrics can explode storage requirements. Careful selection of labels (e.g., endpoint, status code) versus high-cardinality dimensions (e.g., user ID) is critical.

**Dashboard Design**: Effective dashboards focus on actionable insights rather than raw metrics. The "RED method" (Rate, Errors, Duration) for services proved valuable for application dashboards.

### CI/CD Pipeline Architecture

**Plan Artifacts**: Publishing Terraform plans as artifacts allows reviewers to understand changes before approval, reducing surprises during apply stages.

**Approval Gates**: Manual approval environments in Azure DevOps provide necessary governance without blocking developer velocity for non-production changes.

**Rollback Strategies**: Kubernetes deployment rollbacks using `kubectl rollout undo` are straightforward, but require discipline in maintaining deployment history.

### Security Patterns

**Least Privilege RBAC**: Granting workload identities only "Key Vault Secrets User" role (not "Secrets Officer") prevents accidental secret modifications.

**Image Scanning**: Integrating Trivy in CI/CD pipelines catches vulnerabilities early, but requires decisions on whether to block on HIGH vs. CRITICAL vulnerabilities.

**Network Policies**: Azure Network Policy provides pod-to-pod segmentation within the cluster, but requires explicit allow-listing of traffic flows.

### Operational Readiness

**Day-1 vs. Day-2**: The project emphasized "Day-1" readiness (observability from deployment) over "Day-2" enhancements (advanced monitoring). This prioritization accelerated time-to-production.

**Documentation as Code**: Keeping documentation (architecture diagrams, runbooks) alongside infrastructure code ensures consistency as the platform evolves.

## Future Enhancements

While the platform is production-ready for a development environment, these enhancements would be valuable for scaling to production use:

### Multi-Environment Strategy

**Environments**: Extend to staging and production environments with:
- Separate Terraform workspaces or directories
- Environment-specific variable files
- Promotion workflows (dev → staging → prod)
- Blue-green deployment slots for production

**Cost**: Staging + Prod would add ~$400-500/month

### GitOps Integration

**Tools**: Implement Flux CD or Argo CD for pull-based deployments:
- Cluster state defined declaratively in Git
- Automatic drift detection and correction
- Multi-cluster management from single control plane
- ApplicationSets for deploying to multiple environments

**Benefits**: Improved auditability, disaster recovery, and multi-cluster consistency

### Advanced Networking

**Ingress Improvements**:
- Migrate to Gateway API (successor to Ingress)
- Implement cert-manager for automatic TLS certificate management
- Configure external-dns for automatic DNS record creation

**Service Mesh**:
- Istio or Linkerd for advanced traffic management
- Mutual TLS between services
- Circuit breaking and retries
- Distributed tracing with Jaeger/Tempo

### Enhanced Observability

**Distributed Tracing**:
- Integrate OpenTelemetry for application tracing
- Connect to Azure Monitor or Grafana Tempo
- Correlate traces with logs and metrics

**Advanced Dashboards**:
- Cost dashboards (using Kubecost or OpenCost)
- Capacity planning dashboards
- SLO-based dashboards with error budgets

**Alerting**:
- Define SLOs and SLIs
- Configure alerting rules in Grafana
- Integrate with PagerDuty or OpsGenie for on-call

### Security Hardening

**Network Security**:
- Implement Azure Firewall for egress traffic control
- Private AKS cluster (API server not publicly accessible)
- Private endpoints for ACR and Key Vault
- Azure Front Door with WAF for ingress protection

**Policy Enforcement**:
- Transition Azure Policies from audit to enforcement mode
- Implement Pod Security Standards (restricted profile)
- Regular policy compliance scanning with Azure Security Center

**Image Security**:
- Mandatory image signing with Notary v2 or Cosign
- Image provenance verification in admission controller
- Automated vulnerability patching workflows

### Disaster Recovery

**Backup**:
- Velero for etcd and PersistentVolume backups
- Regular backup testing and restore drills
- Cross-region backup replication

**High Availability**:
- Multi-zone AKS node pools
- PodDisruptionBudgets for critical workloads
- Cross-region failover architecture

### Developer Experience

**Self-Service Platform**:
- Namespace provisioning automation
- Resource quota templates by environment
- Slack/Teams integration for deployment notifications
- Developer portal (Backstage) for service catalog

**Local Development**:
- Skaffold or Tilt for local Kubernetes development
- Dev containers for consistent development environments
- Telepresence for local-to-cluster debugging

### Cost Optimization

**Right-Sizing**:
- Implement Vertical Pod Autoscaler for resource recommendations
- Use Azure Spot VMs for non-critical workloads
- Implement cluster autoscaler for dynamic node scaling

**Monitoring**:
- Integrate Kubecost for granular cost attribution
- Set up budget alerts and cost anomaly detection
- Implement resource quotas per namespace/team

### Compliance and Governance

**Multi-Tenancy**:
- Implement Hierarchical Namespace Controller for tenant isolation
- Resource quotas and limit ranges per tenant
- Network policies for tenant segmentation

**Audit and Compliance**:
- Enable Azure Activity Log integration
- Implement audit logging for all Kubernetes API calls
- Regular compliance scanning (CIS Benchmarks)
- Automated compliance reporting

### CI/CD Maturity

**Advanced Deployment Strategies**:
- Canary deployments with Flagger
- Progressive delivery with feature flags
- Automated rollback based on metrics

**Testing Automation**:
- Integration tests in pipeline before deployment
- Smoke tests after deployment
- Load testing in staging environment
- Chaos engineering experiments

**Pipeline Security**:
- Scan Terraform code with tfsec or Checkov
- Implement SAST/DAST scanning in pipelines
- Enforce signed commits and merge requirements

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

**Project Status**: ✅ Complete - Production-Ready AKS Platform with Full CI/CD Automation
**Last Updated**: 2026-03-10
