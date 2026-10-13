variable "name" {
  description = "Globally unique storage account name (3-24 lowercase alphanumeric)."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "replication_type" {
  description = "Replication SKU (LRS, ZRS, GRS, ...)."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.replication_type)
    error_message = "replication_type must be a valid Azure replication SKU."
  }
}

variable "containers" {
  description = "Blob containers to create."
  type        = list(string)
  default     = []
}

variable "allowed_ip_rules" {
  description = "Public IPs/CIDRs permitted through the firewall. Empty leaves the firewall open."
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "Subnet IDs permitted through the firewall via service endpoints."
  type        = list(string)
  default     = []
}

variable "soft_delete_retention_days" {
  description = "Blob and container soft-delete retention."
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 1 && var.soft_delete_retention_days <= 365
    error_message = "soft_delete_retention_days must be between 1 and 365."
  }
}

variable "enable_lifecycle_policy" {
  description = "Attach a tiering/deletion lifecycle rule to the account."
  type        = bool
  default     = true
}

variable "lifecycle_prefix" {
  description = "Blob prefix the lifecycle rule applies to. Empty means the whole account."
  type        = string
  default     = ""
}

variable "cool_after_days" {
  description = "Days before a blob moves to Cool."
  type        = number
  default     = 30
}

variable "archive_after_days" {
  description = "Days before a blob moves to Archive."
  type        = number
  default     = 180
}

variable "delete_after_days" {
  description = "Days before a blob is deleted."
  type        = number
  default     = 730
}

variable "tags" {
  description = "Tags applied to the storage account."
  type        = map(string)
  default     = {}
}
