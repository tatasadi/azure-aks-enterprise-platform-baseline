# Azure Container Registry for AKS workloads
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  admin_enabled       = var.admin_enabled

  # Public network access (can be restricted in production)
  public_network_access_enabled = var.public_network_access_enabled

  # Content trust and vulnerability scanning (Premium SKU only)
  # Uncomment for production with Premium SKU
  # trust_policy {
  #   enabled = true
  # }

  # Retention policy for untagged manifests (Premium SKU only)
  # retention_policy {
  #   days    = var.retention_days
  #   enabled = var.retention_policy_enabled
  # }

  tags = var.tags
}

# Grant AKS kubelet identity pull access to ACR
# This allows AKS nodes to pull images without authentication
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = var.aks_kubelet_identity_object_id != null ? 1 : 0
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = var.aks_kubelet_identity_object_id
}
