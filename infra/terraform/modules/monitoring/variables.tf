variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

variable "log_analytics_sku" {
  description = "SKU for Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_days" {
  description = "Retention period in days for Log Analytics"
  type        = number
  default     = 30
}

variable "azure_monitor_workspace_name" {
  description = "Name of the Azure Monitor workspace for Prometheus"
  type        = string
}

variable "grafana_name" {
  description = "Name of the Azure Managed Grafana instance"
  type        = string
}

variable "grafana_sku" {
  description = "SKU for Azure Managed Grafana"
  type        = string
  default     = "Standard"
}

variable "grafana_admin_user_object_ids" {
  description = "List of Entra ID object IDs for Grafana admin users"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
