output "client_id" {
  description = "Client ID of the workload identity (use this in ServiceAccount annotation)"
  value       = azurerm_user_assigned_identity.workload_identity.client_id
}

output "principal_id" {
  description = "Principal ID (Object ID) of the workload identity"
  value       = azurerm_user_assigned_identity.workload_identity.principal_id
}

output "identity_id" {
  description = "Azure Resource ID of the workload identity"
  value       = azurerm_user_assigned_identity.workload_identity.id
}

output "identity_name" {
  description = "Name of the workload identity"
  value       = azurerm_user_assigned_identity.workload_identity.name
}

output "tenant_id" {
  description = "Tenant ID of the workload identity"
  value       = azurerm_user_assigned_identity.workload_identity.tenant_id
}
