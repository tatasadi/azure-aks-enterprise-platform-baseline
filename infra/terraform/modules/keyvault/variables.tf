variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "keyvault_name" {
  description = "Name of the Key Vault (must be globally unique)"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "sku_name" {
  description = "SKU name for Key Vault"
  type        = string
  default     = "standard"
}

variable "enabled_for_deployment" {
  description = "Enable Azure VMs to retrieve certificates"
  type        = bool
  default     = false
}

variable "enabled_for_disk_encryption" {
  description = "Enable Azure Disk Encryption to retrieve secrets"
  type        = bool
  default     = false
}

variable "enabled_for_template_deployment" {
  description = "Enable ARM templates to retrieve secrets"
  type        = bool
  default     = false
}

variable "enable_rbac_authorization" {
  description = "Use RBAC for authorization instead of access policies"
  type        = bool
  default     = true
}

variable "purge_protection_enabled" {
  description = "Enable purge protection (cannot be disabled once enabled)"
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted items"
  type        = number
  default     = 90
}

variable "network_acls_default_action" {
  description = "Default action for network ACLs"
  type        = string
  default     = "Allow"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
