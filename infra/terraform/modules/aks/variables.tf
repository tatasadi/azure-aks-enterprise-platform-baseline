variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "subnet_id" {
  description = "ID of the subnet for AKS"
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 3
}

variable "node_vm_size" {
  description = "VM size for the nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for Container Insights"
  type        = string
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for the default node pool"
  type        = bool
  default     = false
}

variable "min_count" {
  description = "Minimum number of nodes when auto-scaling is enabled"
  type        = number
  default     = 3
}

variable "max_count" {
  description = "Maximum number of nodes when auto-scaling is enabled"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
