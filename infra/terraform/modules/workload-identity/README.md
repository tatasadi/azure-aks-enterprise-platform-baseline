# Workload Identity Terraform Module

This module creates an Azure Workload Identity for AKS applications, enabling secretless authentication to Azure services.

## Features

- Creates a User Assigned Managed Identity
- Establishes federated identity credential with AKS OIDC issuer
- Optionally grants Key Vault Secrets User role
- Follows Azure Workload Identity best practices

## Usage

```hcl
module "app_workload_identity" {
  source = "../../modules/workload-identity"

  identity_name        = "demo-app-workload-identity"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  oidc_issuer_url      = module.aks.oidc_issuer_url
  namespace            = "demo-app"
  service_account_name = "demo-sa"
  keyvault_id          = module.keyvault.keyvault_id
  tags                 = var.tags
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| identity_name | Name of the User Assigned Managed Identity | string | yes |
| resource_group_name | Name of the resource group | string | yes |
| location | Azure region | string | yes |
| oidc_issuer_url | OIDC issuer URL from AKS | string | yes |
| namespace | Kubernetes namespace | string | yes |
| service_account_name | Kubernetes service account name | string | yes |
| keyvault_id | Key Vault ID for role assignment | string | no |
| tags | Tags to apply | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| client_id | Client ID for ServiceAccount annotation |
| principal_id | Principal ID (Object ID) |
| identity_id | Azure Resource ID |
| identity_name | Name of the identity |
| tenant_id | Tenant ID |

## ServiceAccount Configuration

After creating the workload identity, annotate your Kubernetes ServiceAccount:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-sa
  namespace: demo-app
  annotations:
    azure.workload.identity/client-id: "<client_id_from_output>"
  labels:
    azure.workload.identity/use: "true"
```

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Entra ID                              │
│  ┌────────────────────────────────────────────────────┐  │
│  │  User Assigned Managed Identity                    │  │
│  │  - Client ID: <output>                             │  │
│  │  - Federated Credential                            │  │
│  │    Subject: system:serviceaccount:ns:sa            │  │
│  └────────────┬───────────────────────────────────────┘  │
└───────────────┼──────────────────────────────────────────┘
                │
                │ OIDC Token Exchange
                │
┌───────────────▼──────────────────────────────────────────┐
│              AKS Cluster                                 │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Pod with ServiceAccount                           │  │
│  │  - Uses projected service account token            │  │
│  │  - Exchanges token for Entra ID token via OIDC     │  │
│  │  - Accesses Key Vault, Storage, etc.               │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

## Best Practices

1. **One identity per application**: Create separate identities for different apps
2. **Principle of least privilege**: Only grant necessary permissions
3. **Namespace isolation**: Use separate namespaces for different teams/apps
4. **Audit logging**: Enable diagnostic logs for identity operations

## References

- [Azure Workload Identity Documentation](https://azure.github.io/azure-workload-identity/)
- [AKS Workload Identity](https://learn.microsoft.com/azure/aks/workload-identity-overview)
