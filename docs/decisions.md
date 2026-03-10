# Architecture Decision Records (ADRs)

This document captures key architectural decisions made during the development of the AKS Enterprise Platform Baseline.

## ADR-001: Use Azure Workload Identity over Pod Identity

**Status**: Accepted

**Context**:
We need a secure method for Kubernetes workloads to authenticate to Azure services (particularly Key Vault) without managing static credentials.

**Decision**:
Implement Azure Workload Identity using OIDC federation instead of the deprecated Entra ID Pod Identity.

**Rationale**:
- Workload Identity is the Microsoft-recommended approach as of now
- Uses standard OIDC federation (no custom admission webhooks)
- Better security model with federated credentials
- Pod Identity is deprecated and will be removed
- Simpler architecture with native Kubernetes service account tokens
- No need for NMI (Node Managed Identity) pods

**Consequences**:
- Requires AKS cluster with OIDC issuer enabled
- Workloads need proper service account annotations
- Federated identity credentials must be created for each workload identity

---

## ADR-002: Use Azure Monitor Managed Prometheus over Self-Hosted

**Status**: Accepted

**Context**:
We need a metrics collection and storage solution for cluster and application observability.

**Decision**:
Use Azure Monitor managed service for Prometheus instead of self-hosting Prometheus.

**Rationale**:
- Reduces operational overhead (no Prometheus pod management)
- Automatic scaling and high availability
- Native integration with Azure Managed Grafana
- Microsoft-managed updates and security patches
- Cost-effective for enterprise use cases
- Follows Azure-native patterns

**Consequences**:
- Depends on Azure Monitor service availability
- Less customization compared to self-hosted
- Data collection rules required for metric scraping
- Regional availability constraints

---

## ADR-003: Use Application Routing Add-on over Manual NGINX

**Status**: Accepted

**Context**:
We need an ingress controller for exposing applications to internal/external traffic.

**Decision**:
Enable the Application Routing add-on (managed NGINX) instead of deploying NGINX manually via Helm.

**Rationale**:
- Azure-managed lifecycle (updates, security patches)
- Officially supported through November 2026
- Simpler configuration for baseline use cases
- Integrated with AKS monitoring
- No need to manage NGINX Helm charts
- Suitable for most enterprise scenarios

**Consequences**:
- Less control over NGINX configuration
- Tied to Azure's update schedule
- Future migration path to Gateway API recommended by Microsoft
- Limited to NGINX features exposed by add-on

---

## ADR-004: Use Azure Policy over OPA/Gatekeeper

**Status**: Accepted

**Context**:
We need policy enforcement for Kubernetes resource compliance and security guardrails.

**Decision**:
Use the Azure Policy add-on for AKS instead of self-managing Open Policy Agent (OPA) Gatekeeper.

**Rationale**:
- Native Azure integration for centralized governance
- Enterprise compliance reporting in Azure Portal
- Pre-built policy definitions for common scenarios
- Unified policy management across Azure resources
- Integration with Azure Security Center
- Easier for platform teams familiar with Azure Policy

**Consequences**:
- Requires Azure Policy add-on enabled on AKS
- Policy definitions use Azure-specific syntax
- Less flexibility compared to custom Rego policies
- Relies on Azure services for policy evaluation

---

## ADR-005: Use RBAC Authorization for Key Vault

**Status**: Accepted

**Context**:
We need to control access to secrets stored in Azure Key Vault.

**Decision**:
Enable RBAC authorization model for Key Vault instead of access policies.

**Rationale**:
- Modern Azure authorization model
- Consistent with Entra ID RBAC patterns
- Granular role assignments (Key Vault Secrets User, etc.)
- Better audit trail via Azure Activity Log
- Supports managed identities and Workload Identity seamlessly
- Aligns with Zero Trust principles

**Consequences**:
- Requires understanding of Azure RBAC roles
- Role assignments take time to propagate
- Cannot mix RBAC and access policies on same vault
- Soft delete and purge protection enabled by default

---

---

## ADR-006: Use Azure Managed Grafana over Self-Hosted Grafana

**Status**: Accepted

**Context**:
We need a visualization and dashboarding solution for observability metrics collected by Prometheus.

**Decision**:
Use Azure Managed Grafana instead of self-hosting Grafana in the AKS cluster.

**Rationale**:
- Fully managed service with automatic updates and patching
- High availability built-in (no need to manage replicas)
- Native integration with Azure Monitor workspace (Prometheus)
- Entra ID authentication out-of-the-box
- RBAC via Azure role assignments (Grafana Admin, Grafana Editor, Grafana Viewer)
- Reduces operational burden on platform team
- Cost-effective compared to running dedicated infrastructure

**Consequences**:
- Grafana instance runs outside the cluster (external dependency)
- Limited control over Grafana version and plugins
- Data sources must be accessible from Azure Managed Grafana
- Dashboard provisioning requires manual import or API calls
- Regional availability constraints

**Alternatives Considered**:
- Self-hosted Grafana in AKS: More control but higher operational overhead
- Azure Monitor Workbooks: Azure-native but less powerful than Grafana for Prometheus metrics

---

## ADR-007: Dashboard as Code via JSON Export

**Status**: Accepted

**Context**:
Custom Grafana dashboards need to be version-controlled and reproducible across environments.

**Decision**:
Store dashboard JSON files in Git at [`platform/manifests/grafana-dashboards/`](../platform/manifests/grafana-dashboards/) and import them manually or via API.

**Rationale**:
- Version control for dashboards (track changes over time)
- Reproducible dashboard deployments
- Easy sharing across teams and environments
- Simple export/import workflow
- No additional tooling required

**Consequences**:
- Dashboards must be manually imported into Grafana (one-time setup)
- Updates require re-export and Git commit
- Not fully automated (no GitOps for dashboards)
- Risk of drift between Git and live dashboards

**Alternatives Considered**:
- Grafana Provisioning: Requires mounting ConfigMaps in managed Grafana (not supported)
- Terraform Grafana Provider: Adds complexity, requires API credentials
- GitOps (ArgoCD/Flux): Overkill for dashboards

---

## ADR-008: Audit-First Policy Enforcement

**Status**: Accepted

**Context**:
Azure Policy can enforce security and operational guardrails, but overly restrictive policies can block legitimate workloads.

**Decision**:
Start with `audit` mode for all policies in development environment, then progressively move to `deny` mode for high-priority policies in staging/production.

**Rationale**:
- Reduces risk of blocking legitimate workloads during initial rollout
- Provides visibility into compliance gaps without disruption
- Allows teams to learn policy requirements gradually
- Enables iterative refinement of policies and exceptions
- Follows principle of "educate before enforce"

**Consequences**:
- Non-compliant resources can be created in audit mode
- Requires manual review of compliance reports
- Teams may delay fixing policy violations
- Transition to deny mode requires change management

**Policy Enforcement Strategy**:
- **Dev**: Audit mode for all policies (education)
- **Staging**: Deny mode for high-priority policies (testing)
- **Production**: Deny mode for high-priority, audit for medium-priority

---

## ADR-009: Operations Documentation in Markdown

**Status**: Accepted

**Context**:
Platform operations require documented procedures for common tasks, troubleshooting, and maintenance.

**Decision**:
Maintain operational documentation in Markdown format within the Git repository at [`docs/operations.md`](../docs/operations.md).

**Rationale**:
- Version-controlled alongside code
- Easy to search and update
- Supports code blocks and examples
- Accessible via GitHub/IDE without special tools
- Can be rendered in internal wikis or documentation sites
- Encourages documentation-as-code practices

**Consequences**:
- Not a dedicated knowledge base (no search, no structured data)
- Requires discipline to keep docs up-to-date
- No built-in access control (docs are public with code)
- Formatting limited to Markdown capabilities

**Alternatives Considered**:
- Confluence/Wiki: Separate from code, harder to keep in sync
- README-driven: Too fragmented across multiple files
- Runbook automation tools: Overkill for baseline platform

---

## Future ADRs

The following decisions will be documented in subsequent phases:

- **ADR-010**: Ingress TLS certificate management strategy
- **ADR-011**: Multi-environment promotion strategy
- **ADR-012**: Namespace isolation and multi-tenancy model
- **ADR-013**: Backup and disaster recovery approach
- **ADR-014**: Autoscaling strategy (HPA, VPA, Cluster Autoscaler)

---

**Last Updated**: 2026-03-09
