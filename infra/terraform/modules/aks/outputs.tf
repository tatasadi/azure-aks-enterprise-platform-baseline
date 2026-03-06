output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "kube_config" {
  description = "Kubernetes configuration for cluster access"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "kube_config_host" {
  description = "Kubernetes API server host"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].host
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity"
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity"
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "cluster_identity_principal_id" {
  description = "Principal ID of the cluster managed identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "cluster_identity_tenant_id" {
  description = "Tenant ID of the cluster managed identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].tenant_id
}

output "ingress_application_gateway_identity_object_id" {
  description = "Object ID of the Application Gateway ingress identity"
  value       = try(azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id, null)
}

output "web_app_routing_identity_object_id" {
  description = "Object ID of the Web App Routing identity"
  value       = try(azurerm_kubernetes_cluster.aks.web_app_routing[0].web_app_routing_identity[0].object_id, null)
}
