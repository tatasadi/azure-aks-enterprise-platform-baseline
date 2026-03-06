output "keyvault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.keyvault.id
}

output "keyvault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.keyvault.name
}

output "keyvault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.keyvault.vault_uri
}

output "keyvault_tenant_id" {
  description = "Tenant ID for the Key Vault"
  value       = azurerm_key_vault.keyvault.tenant_id
}
