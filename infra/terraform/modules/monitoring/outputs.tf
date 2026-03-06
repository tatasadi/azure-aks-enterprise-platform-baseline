output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.workspace.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.workspace.name
}

output "log_analytics_workspace_key" {
  description = "Primary shared key for Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.workspace.primary_shared_key
  sensitive   = true
}

output "azure_monitor_workspace_id" {
  description = "ID of the Azure Monitor workspace"
  value       = azurerm_monitor_workspace.prometheus.id
}

output "azure_monitor_workspace_name" {
  description = "Name of the Azure Monitor workspace"
  value       = azurerm_monitor_workspace.prometheus.name
}

output "azure_monitor_workspace_query_endpoint" {
  description = "Query endpoint for the Azure Monitor workspace"
  value       = azurerm_monitor_workspace.prometheus.query_endpoint
}

output "grafana_id" {
  description = "ID of the Azure Managed Grafana instance"
  value       = azurerm_dashboard_grafana.grafana.id
}

output "grafana_name" {
  description = "Name of the Azure Managed Grafana instance"
  value       = azurerm_dashboard_grafana.grafana.name
}

output "grafana_endpoint" {
  description = "Endpoint URL for the Grafana instance"
  value       = azurerm_dashboard_grafana.grafana.endpoint
}

output "grafana_identity_principal_id" {
  description = "Principal ID of the Grafana managed identity"
  value       = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}
