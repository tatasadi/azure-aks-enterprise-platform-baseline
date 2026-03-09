# Resource Group
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.rg.location
}

# Networking
output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.networking.vnet_id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = module.networking.aks_subnet_id
}

# AKS
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = module.aks.cluster_id
}

output "aks_kube_config" {
  description = "Kubeconfig for the AKS cluster"
  value       = module.aks.kube_config
  sensitive   = true
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for the AKS cluster (for Workload Identity)"
  value       = module.aks.oidc_issuer_url
}

output "aks_cluster_identity_principal_id" {
  description = "Principal ID of the AKS cluster managed identity"
  value       = module.aks.cluster_identity_principal_id
}

# Monitoring
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.monitoring.log_analytics_workspace_id
}

output "azure_monitor_workspace_id" {
  description = "ID of the Azure Monitor workspace"
  value       = module.monitoring.azure_monitor_workspace_id
}

output "grafana_endpoint" {
  description = "Endpoint URL for Azure Managed Grafana"
  value       = module.monitoring.grafana_endpoint
}

output "grafana_id" {
  description = "ID of the Azure Managed Grafana instance"
  value       = module.monitoring.grafana_id
}

# Key Vault
output "keyvault_name" {
  description = "Name of the Key Vault"
  value       = module.keyvault.keyvault_name
}

output "keyvault_uri" {
  description = "URI of the Key Vault"
  value       = module.keyvault.keyvault_uri
}

output "keyvault_id" {
  description = "ID of the Key Vault"
  value       = module.keyvault.keyvault_id
}

# Azure Container Registry
output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.acr.acr_name
}

output "acr_login_server" {
  description = "Login server URL for the Azure Container Registry"
  value       = module.acr.acr_login_server
}

output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = module.acr.acr_id
}

# Workload Identity (Demo App)
output "demo_app_workload_identity_client_id" {
  description = "Client ID of the demo app workload identity (use in ServiceAccount annotation)"
  value       = module.demo_app_workload_identity.client_id
}

output "demo_app_workload_identity_name" {
  description = "Name of the demo app workload identity"
  value       = module.demo_app_workload_identity.identity_name
}

# Instructions
output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT

    ========================================
    AKS Enterprise Platform Baseline - Dev Environment
    ========================================

    Deployment completed successfully!

    Next Steps:

    1. Get AKS credentials:
       az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${module.aks.cluster_name}

    2. Verify cluster access:
       kubectl get nodes

    3. Access Grafana:
       URL: ${module.monitoring.grafana_endpoint}
       (Use Azure AD authentication)

    4. OIDC Issuer URL (for Workload Identity):
       ${module.aks.oidc_issuer_url}

    5. Key Vault URI:
       ${module.keyvault.keyvault_uri}

    6. Azure Container Registry:
       ${module.acr.acr_login_server}

       Log in to ACR:
       az acr login --name ${module.acr.acr_name}

    ========================================
  EOT
}
