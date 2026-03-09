variable "identity_name" {
  description = "Name of the User Assigned Managed Identity"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the identity"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL from AKS cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the service account exists"
  type        = string
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
}

variable "keyvault_id" {
  description = "ID of the Key Vault to grant access to (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the identity"
  type        = map(string)
  default     = {}
}
