# Azure Workload Identity for AKS applications
# This module creates a User Assigned Managed Identity with federated credentials
# for Kubernetes service accounts to authenticate to Azure services

resource "azurerm_user_assigned_identity" "workload_identity" {
  name                = var.identity_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Federated identity credential for OIDC-based authentication
# Links the Azure identity to a Kubernetes service account
resource "azurerm_federated_identity_credential" "workload_identity" {
  name                = "${var.identity_name}-federated-credential"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
}

# Role assignment: Key Vault Secrets User
# Grants the workload identity permission to read secrets from Key Vault
resource "azurerm_role_assignment" "keyvault_secrets_user" {
  count                = var.keyvault_id != null ? 1 : 0
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload_identity.principal_id
}
