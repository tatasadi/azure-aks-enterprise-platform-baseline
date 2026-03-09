# Azure Policy for AKS - Baseline Policy Set

This directory contains Azure Policy definitions for enforcing security and operational best practices on the AKS cluster.

## Policy Enforcement Status

Azure Policy add-on is enabled on the AKS cluster. The add-on runs as pods in the `kube-system` namespace:
- `azure-policy`: Policy controller
- `azure-policy-webhook`: Admission webhook for policy enforcement

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

### 5. Require Read-Only Root Filesystem (Optional)
**Policy**: `Kubernetes cluster containers should run with a read only root file system`
**Effect**: `audit`
**Rationale**: Increases security by preventing modifications to the container filesystem.

### 6. Disallow Latest Image Tag (Optional)
**Policy**: `Kubernetes cluster containers should not use :latest tag`
**Effect**: `audit`
**Rationale**: Ensures reproducible deployments with pinned image versions.

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

## References

- [Azure Policy for AKS](https://learn.microsoft.com/azure/aks/policy-reference)
- [Built-in Policy Definitions for AKS](https://learn.microsoft.com/azure/aks/policy-samples)
- [Azure Policy Kubernetes Effects](https://learn.microsoft.com/azure/governance/policy/concepts/effects#kubernetes)
