terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Backend configuration for Azure Storage
  backend "azurerm" {
    resource_group_name  = "rg-terraform"
    storage_account_name = "sttfstateta"
    container_name       = "tfstate"
    key                  = "azure-aks-dev.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Data source for current Azure client configuration
data "azurerm_client_config" "current" {}

# Local variables for resource naming
locals {
  resource_group_name          = "${var.project_name}-${var.environment}-rg"
  vnet_name                    = "${var.project_name}-${var.environment}-vnet"
  aks_cluster_name             = "${var.project_name}-${var.environment}-aks"
  log_analytics_workspace_name = "${var.project_name}-${var.environment}-law"
  azure_monitor_workspace_name = "${var.project_name}-${var.environment}-amw"
  grafana_name                 = "${var.project_name}-${var.environment}-grafana"
  keyvault_name                = "${var.project_name}${var.environment}kv"  # No dashes, max 24 chars
  acr_name                     = "${var.project_name}${var.environment}acr" # No dashes, alphanumeric only
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  vnet_name           = local.vnet_name
  tags                = var.tags
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  log_analytics_workspace_name  = local.log_analytics_workspace_name
  azure_monitor_workspace_name  = local.azure_monitor_workspace_name
  grafana_name                  = local.grafana_name
  grafana_admin_user_object_ids = var.grafana_admin_user_object_ids
  tags                          = var.tags
}

# AKS Module
module "aks" {
  source = "../../modules/aks"

  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  cluster_name               = local.aks_cluster_name
  dns_prefix                 = "${var.project_name}-${var.environment}"
  kubernetes_version         = var.kubernetes_version
  subnet_id                  = module.networking.aks_subnet_id
  node_count                 = var.aks_node_count
  node_vm_size               = var.aks_node_vm_size
  enable_auto_scaling        = var.enable_auto_scaling
  min_count                  = var.min_node_count
  max_count                  = var.max_node_count
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = var.tags

  depends_on = [module.networking, module.monitoring]
}

# Key Vault Module
module "keyvault" {
  source = "../../modules/keyvault"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  keyvault_name       = local.keyvault_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = var.tags
}

# Azure Container Registry Module
module "acr" {
  source = "../../modules/acr"

  resource_group_name            = azurerm_resource_group.rg.name
  location                       = azurerm_resource_group.rg.location
  acr_name                       = local.acr_name
  sku                            = var.acr_sku
  aks_kubelet_identity_object_id = module.aks.kubelet_identity_object_id
  tags                           = var.tags

  depends_on = [module.aks]
}

# Workload Identity for demo application
module "demo_app_workload_identity" {
  source = "../../modules/workload-identity"

  identity_name        = "${var.project_name}-${var.environment}-demo-app-wi"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  oidc_issuer_url      = module.aks.oidc_issuer_url
  namespace            = "demo-app"
  service_account_name = "demo-sa"
  keyvault_id          = module.keyvault.keyvault_id
  tags                 = var.tags

  depends_on = [module.aks, module.keyvault]
}

# Enable Azure Monitor managed Prometheus for AKS
resource "azurerm_monitor_data_collection_endpoint" "dce" {
  name                = "${local.aks_cluster_name}-dce"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  tags                = var.tags
}

resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                        = "${local.aks_cluster_name}-dcr"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dce.id

  destinations {
    monitor_account {
      monitor_account_id = module.monitoring.azure_monitor_workspace_id
      name               = "MonitoringAccount"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }

  tags = var.tags
}

# Associate the data collection rule with the AKS cluster
resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                    = "${local.aks_cluster_name}-dcra"
  target_resource_id      = module.aks.cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
}
