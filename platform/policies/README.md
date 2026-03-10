# Azure Policy for AKS - Baseline Policy Set

This directory contains Azure Policy definitions for enforcing security and operational best practices on the AKS cluster.

## Policy Enforcement Status

Azure Policy add-on is enabled on the AKS cluster. The add-on runs as pods in the `kube-system` namespace:
- `azure-policy`: Policy controller
- `azure-policy-webhook`: Admission webhook for policy enforcement

## Policy Summary

| # | Policy | Effect | Priority | Built-in ID |
|---|--------|--------|----------|-------------|
| 1 | Disallow Privileged Containers | deny | High | `95edb821-ddaf-4404-9732-666045e056b4` |
| 2 | Require Resource Limits | audit/deny | High | Built-in |
| 3 | Require Pod Labels | audit | Medium | Custom |
| 4 | Disallow Host Namespaces | deny | High | `82985f06-dc18-4a48-bc1c-b9f4f0098cfe` |
| 5 | Read-Only Root Filesystem | audit | Medium | `df49d893-a74c-421d-bc95-c663042e5b80` |
| 6 | Disallow Latest Image Tag | audit | Medium | `febd0533-8e55-448f-b837-bd0e06f16469` |
| 7 | Require Health Probes | audit | Medium | Custom |
| 8 | Disallow Dangerous Capabilities | deny | High | `c26596ff-4d70-4e6a-9a30-c2506bd2f80c` |
| 9 | Require Non-Root User | audit | High | `f06ddb64-5fa3-4b77-b166-acb36f7f6042` |
| 10 | Enforce AppArmor Profiles | audit | Low | Custom |

## Baseline Policies

The following policies are recommended for the enterprise AKS baseline:

### 1. Disallow Privileged Containers
**Policy**: `Kubernetes cluster should not allow privileged containers`
**Built-in ID**: `95edb821-ddaf-4404-9732-666045e056b4`
**Effect**: `deny` or `audit`
**Rationale**: Privileged containers have access to host resources and break container isolation.

### 2. Require Resource Limits and Requests
**Policy**: `Kubernetes cluster containers CPU and memory resource limits should not exceed the specified limits`
**Built-in ID**: `e345b504-d8e8-4f4a-9f7c-7f5f5f5f5f5f` (example)
**Effect**: `deny` or `audit`
**Rationale**: Prevents resource exhaustion and ensures quality of service.

### 3. Require Pod Labels
**Policy**: `Kubernetes cluster pods should use specified labels`
**Effect**: `audit`
**Required Labels**:
- `app`: Application name
- `environment`: Environment (dev, staging, prod)
- `owner`: Team or owner

**Rationale**: Ensures proper resource organization and cost allocation.

### 4. Disallow Host Namespaces
**Policy**: `Kubernetes cluster pods should not use host network or host process namespace`
**Built-in ID**: `82985f06-dc18-4a48-bc1c-b9f4f0098cfe`
**Effect**: `deny`
**Rationale**: Pods should not share the host network or process namespace.

### 5. Require Read-Only Root Filesystem
**Policy**: `Kubernetes cluster containers should run with a read only root file system`
**Built-in ID**: `df49d893-a74c-421d-bc95-c663042e5b80`
**Effect**: `audit` (recommend `deny` for production)
**Rationale**: Increases security by preventing modifications to the container filesystem. Applications that need to write should use emptyDir or persistent volumes.

**Exceptions**: Some applications require writable filesystem (e.g., writing temporary files to `/tmp`). Consider using `emptyDir` volume mounts for these cases.

### 6. Disallow Latest Image Tag
**Policy**: `Kubernetes cluster containers should not use forbidden images`
**Built-in ID**: `febd0533-8e55-448f-b837-bd0e06f16469`
**Effect**: `audit` (recommend `deny` for production)
**Rationale**: Using `:latest` tag leads to non-deterministic deployments. Always pin specific image versions (e.g., `nginx:1.21.6` instead of `nginx:latest`).

**Configuration**:
```json
{
  "imageRegex": ".*:latest$"
}
```

### 7. Require Liveness and Readiness Probes
**Policy**: `Kubernetes cluster containers should have readiness and liveness probes`
**Effect**: `audit`
**Rationale**: Health probes ensure Kubernetes can detect and recover from application failures automatically. Without probes, failed containers may continue receiving traffic.

**Best Practices**:
- **Liveness Probe**: Detects if application is stuck/deadlocked → restarts container
- **Readiness Probe**: Detects if application is ready to serve traffic → controls load balancing
- Use HTTP probes for web services, TCP probes for databases, exec probes for custom checks

**Example**:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 8. Disallow Dangerous Capabilities
**Policy**: `Kubernetes cluster pods should only use approved capabilities`
**Built-in ID**: `c26596ff-4d70-4e6a-9a30-c2506bd2f80c`
**Effect**: `deny`
**Rationale**: Linux capabilities like `SYS_ADMIN`, `NET_ADMIN`, and `SYS_PTRACE` grant excessive privileges that can be used to compromise the cluster.

**Allowed Capabilities** (minimal set):
- `NET_BIND_SERVICE`: Bind to ports < 1024
- `CHOWN`: Change file ownership
- `DAC_OVERRIDE`: Bypass file read/write/execute permission checks

**Blocked Capabilities**:
- `SYS_ADMIN`: System administration operations
- `NET_ADMIN`: Network administration
- `SYS_PTRACE`: Trace/inspect other processes

### 9. Require Non-Root User
**Policy**: `Kubernetes cluster pods should not run as root`
**Built-in ID**: `f06ddb64-5fa3-4b77-b166-acb36f7f6042`
**Effect**: `audit` (recommend `deny` for production)
**Rationale**: Running containers as root increases the attack surface. If a container is compromised, the attacker has root privileges within that container.

**Implementation**:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
```

### 10. Enforce AppArmor Profiles (Linux)
**Policy**: `Kubernetes cluster pods should use specified AppArmor profiles`
**Effect**: `audit`
**Rationale**: AppArmor provides mandatory access control (MAC) to restrict what containers can do at the kernel level.

**Recommended Profile**: `runtime/default`

```yaml
metadata:
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: runtime/default
```

## Assigning Policies

Azure Policies are assigned at the **subscription** or **resource group** level, not in this repository.

### Using Azure Portal
1. Navigate to **Azure Policy** in the portal
2. Select **Definitions** → **Kubernetes**
3. Choose a policy and click **Assign**
4. Select scope: AKS cluster resource group or subscription
5. Configure parameters and effects (deny/audit)

### Using Azure CLI

```bash
# Assign built-in policy to deny privileged containers
az policy assignment create \
  --name "deny-privileged-containers" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/aksplatform-dev-rg" \
  --policy "95edb821-ddaf-4404-9732-666045e056b4" \
  --params '{
    "effect": {"value": "deny"},
    "excludedNamespaces": {"value": ["kube-system", "gatekeeper-system", "azure-arc"]}
  }'

# Assign policy to deny host namespaces
az policy assignment create \
  --name "deny-host-namespaces" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/aksplatform-dev-rg" \
  --policy "82985f06-dc18-4a48-bc1c-b9f4f0098cfe" \
  --params '{
    "effect": {"value": "deny"},
    "excludedNamespaces": {"value": ["kube-system"]}
  }'
```

### Using Terraform (Future Enhancement)

Policies can be assigned via Terraform using `azurerm_policy_assignment` resource:

```hcl
resource "azurerm_policy_assignment" "deny_privileged" {
  name                 = "deny-privileged-containers"
  scope                = azurerm_resource_group.rg.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/95edb821-ddaf-4404-9732-666045e056b4"

  parameters = jsonencode({
    effect = {
      value = "deny"
    }
    excludedNamespaces = {
      value = ["kube-system", "gatekeeper-system", "azure-arc"]
    }
  })
}
```

## Verifying Policy Compliance

### Check Policy States
```bash
# List all policy assignments
az policy assignment list --resource-group aksplatform-dev-rg

# Check compliance state
az policy state list \
  --resource-group aksplatform-dev-rg \
  --resource "/subscriptions/<sub-id>/resourceGroups/aksplatform-dev-rg/providers/Microsoft.ContainerService/managedClusters/aksplatform-dev-aks"
```

### View Policy Events in AKS
```bash
# Check Azure Policy pod logs
kubectl logs -n kube-system -l app=azure-policy

# View admission webhook logs
kubectl logs -n kube-system -l app=azure-policy-webhook
```

## Testing Policy Enforcement

See [test-policy-enforcement.yaml](test-policy-enforcement.yaml) for examples of compliant and non-compliant pods.

## Excluded Namespaces

Certain system namespaces should be excluded from policy enforcement:
- `kube-system`: Core Kubernetes components
- `gatekeeper-system`: Policy engine infrastructure
- `azure-arc`: Azure Arc components
- `app-routing-system`: NGINX ingress controller

## Policy Recommendations by Environment

### Development Environment
- Start with `audit` mode for all policies
- Focus on education and compliance metrics
- Allow exceptions for debugging (e.g., privileged containers in dev namespace)

### Staging Environment
- Move to `deny` mode for high-priority policies
- Test policy impact on real workloads
- Validate exception handling processes

### Production Environment
- Enforce `deny` mode for all high-priority policies
- Maintain `audit` mode for medium/low priority policies
- Require policy compliance before deployment approval

## Troubleshooting Policy Violations

### Common Issues

**Issue**: Pod fails to create with "admission webhook denied the request"
**Solution**: Check policy logs and adjust pod spec to comply

```bash
# View policy violations
kubectl get events --field-selector type=Warning

# Check specific pod events
kubectl describe pod <pod-name>
```

**Issue**: Policy shows as "NonCompliant" but pods are running
**Solution**: Existing resources created before policy assignment are not affected. Policy only applies to new/updated resources.

```bash
# Force compliance by recreating resources
kubectl rollout restart deployment <deployment-name>
```

## References

- [Azure Policy for AKS](https://learn.microsoft.com/azure/aks/policy-reference)
- [Built-in Policy Definitions for AKS](https://learn.microsoft.com/azure/aks/policy-samples)
- [Azure Policy Kubernetes Effects](https://learn.microsoft.com/azure/governance/policy/concepts/effects#kubernetes)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/security-checklist/)

---

**Last Updated**: 2026-03-09
**Phase**: Phase 4 - Guardrails & Operations
