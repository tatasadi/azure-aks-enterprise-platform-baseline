# AKS Cluster with OIDC Issuer and Workload Identity
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  # Enable OIDC issuer for Workload Identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                 = "system"
    node_count           = var.enable_auto_scaling ? null : var.node_count
    vm_size              = var.node_vm_size
    vnet_subnet_id       = var.subnet_id
    auto_scaling_enabled = var.enable_auto_scaling
    min_count            = var.enable_auto_scaling ? var.min_count : null
    max_count            = var.enable_auto_scaling ? var.max_count : null
    os_disk_size_gb      = 100
    type                 = "VirtualMachineScaleSets"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Use managed identity
  identity {
    type = "SystemAssigned"
  }

  # Network configuration
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    service_cidr      = "10.1.0.0/16"
    dns_service_ip    = "10.1.0.10"
    load_balancer_sku = "standard"
  }

  # Enable Azure Monitor for containers (Container Insights)
  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = null
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # Enable Azure Policy add-on
  azure_policy_enabled = true

  # Enable Secrets Store CSI Driver
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # Enable Web Application Routing (NGINX ingress)
  web_app_routing {
    dns_zone_ids = []
  }

  tags = var.tags
}

# Role assignment for AKS to manage network resources
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
