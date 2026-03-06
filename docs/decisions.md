# Architecture Decision Records (ADRs)

This document captures key architectural decisions made during the development of the AKS Enterprise Platform Baseline.

## ADR-001: Use Azure Workload Identity over Pod Identity

**Status**: Accepted

**Context**:
We need a secure method for Kubernetes workloads to authenticate to Azure services (particularly Key Vault) without managing static credentials.

**Decision**:
Implement Azure Workload Identity using OIDC federation instead of the deprecated Azure AD Pod Identity.

**Rationale**:
- Workload Identity is the Microsoft-recommended approach as of 2024
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
- Consistent with Azure AD RBAC patterns
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

## Future ADRs

The following decisions will be documented in subsequent phases:

- **ADR-006**: Ingress TLS certificate management strategy
- **ADR-007**: Multi-environment promotion strategy
- **ADR-008**: Namespace isolation and multi-tenancy model
- **ADR-009**: Backup and disaster recovery approach
- **ADR-010**: Autoscaling strategy (HPA, VPA, Cluster Autoscaler)

---

**Last Updated**: 2026-03-06
**Phase**: Phase 1 - Core Infrastructure
