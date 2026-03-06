# Data source for current client
data "azurerm_client_config" "current" {}

# Azure Key Vault with RBAC authorization
resource "azurerm_key_vault" "keyvault" {
  name                       = var.keyvault_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = var.sku_name
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # Enable RBAC authorization instead of access policies
  enable_rbac_authorization = var.enable_rbac_authorization

  # Optional VM and template integration
  enabled_for_deployment          = var.enabled_for_deployment
  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  enabled_for_template_deployment = var.enabled_for_template_deployment

  # Network ACLs (Allow for baseline, restrict in production)
  network_acls {
    default_action = var.network_acls_default_action
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# Grant current user Key Vault Administrator role for initial setup
# This allows the user deploying Terraform to manage secrets
resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}
