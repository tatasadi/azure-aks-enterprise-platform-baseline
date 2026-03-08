# Log Analytics Workspace for Container Insights
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_days

  tags = var.tags
}

# Log Analytics Solutions for Container Insights
resource "azurerm_log_analytics_solution" "container_insights" {
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.workspace.id
  workspace_name        = azurerm_log_analytics_workspace.workspace.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = var.tags
}

# Azure Monitor Workspace for Managed Prometheus
resource "azurerm_monitor_workspace" "prometheus" {
  name                = var.azure_monitor_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Azure Managed Grafana
resource "azurerm_dashboard_grafana" "grafana" {
  name                  = var.grafana_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  sku                   = var.grafana_sku
  grafana_major_version = 11

  # Enable Azure Monitor Workspace integration
  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.prometheus.id
  }

  # Enable managed identity for Grafana
  identity {
    type = "SystemAssigned"
  }

  # Disable public network access in production (optional for baseline)
  public_network_access_enabled = true

  # Deterministic outbound IPs (helpful for firewall rules)
  deterministic_outbound_ip_enabled = true

  tags = var.tags
}

# Role assignment: Grafana Monitoring Reader on Azure Monitor workspace
resource "azurerm_role_assignment" "grafana_monitoring_reader" {
  scope                = azurerm_monitor_workspace.prometheus.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}

# Role assignment: Grafana Admin for specified users
resource "azurerm_role_assignment" "grafana_admin" {
  for_each = toset(var.grafana_admin_user_object_ids)

  scope                = azurerm_dashboard_grafana.grafana.id
  role_definition_name = "Grafana Admin"
  principal_id         = each.value
}
