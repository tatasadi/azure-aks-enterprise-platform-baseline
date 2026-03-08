variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "westeurope"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "aksplatform"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.33"
}

variable "aks_node_count" {
  description = "Number of nodes in the AKS default node pool"
  type        = number
  default     = 3
}

variable "aks_node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for AKS node pool"
  type        = bool
  default     = false
}

variable "min_node_count" {
  description = "Minimum node count when auto-scaling is enabled"
  type        = number
  default     = 3
}

variable "max_node_count" {
  description = "Maximum node count when auto-scaling is enabled"
  type        = number
  default     = 5
}

variable "grafana_admin_user_object_ids" {
  description = "List of Azure AD object IDs for Grafana admin users"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "AKS Enterprise Platform Baseline"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}
