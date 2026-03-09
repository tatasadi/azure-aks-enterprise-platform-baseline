variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "acr_name" {
  description = "Name of the Azure Container Registry (must be globally unique, alphanumeric only)"
  type        = string
}

variable "sku" {
  description = "SKU for Azure Container Registry (Basic, Standard, Premium)"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be Basic, Standard, or Premium."
  }
}

variable "admin_enabled" {
  description = "Enable admin user for ACR (not recommended for production)"
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Allow public network access to ACR"
  type        = bool
  default     = true
}

variable "aks_principal_id" {
  description = "Principal ID of AKS cluster managed identity (for AcrPull role assignment)"
  type        = string
  default     = null
}

variable "retention_days" {
  description = "Number of days to retain untagged manifests (Premium SKU only)"
  type        = number
  default     = 7
}

variable "retention_policy_enabled" {
  description = "Enable retention policy for untagged manifests (Premium SKU only)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
