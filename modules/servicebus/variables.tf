variable "name" {
  description = "Globally unique Service Bus namespace name."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{4,48}[a-zA-Z0-9]$", var.name))
    error_message = "Service Bus namespace names must be 6-50 chars, alphanumeric and hyphens, starting with a letter."
  }
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "sku" {
  description = "Namespace SKU. Basic is rejected because it supports neither topics nor dead-lettering."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.sku)
    error_message = "sku must be Standard or Premium."
  }
}

variable "capacity" {
  description = "Messaging units for Premium namespaces. Must be null for Standard."
  type        = number
  default     = null

  validation {
    condition     = var.capacity == null || contains([1, 2, 4, 8, 16], coalesce(var.capacity, 1))
    error_message = "capacity must be null or one of 1, 2, 4, 8, 16."
  }
}

variable "premium_messaging_partitions" {
  description = "Messaging partitions for a Premium namespace. 0 = none, 1 or 2 = zone redundant. Ignored on Standard."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 2], var.premium_messaging_partitions)
    error_message = "premium_messaging_partitions must be 0, 1 or 2."
  }
}

variable "local_auth_enabled" {
  description = "Allow SAS key authentication. Disable to force Entra ID only."
  type        = bool
  default     = false
}

variable "partitioning_enabled" {
  description = "Enable partitioning on queues and topics. Ignored on Premium."
  type        = bool
  default     = true
}

variable "partitioning_supported" {
  description = "Whether the selected SKU supports partitioning. Computed by the caller from the SKU."
  type        = bool
  default     = true
}

variable "queues" {
  description = "Queues to create, keyed by queue name."
  type = map(object({
    max_delivery_count                      = optional(number, 10)
    lock_duration                           = optional(string, "PT1M")
    default_message_ttl                     = optional(string, "P14D")
    dead_lettering_on_message_expiration    = optional(bool, true)
    max_size_in_megabytes                   = optional(number, 1024)
    requires_session                        = optional(bool, false)
    requires_duplicate_detection            = optional(bool, false)
    duplicate_detection_history_time_window = optional(string, "PT10M")
  }))
  default = {}
}

variable "topics" {
  description = "Topics to create, keyed by topic name, each with its subscriptions keyed by subscription name."
  type = map(object({
    max_size_in_megabytes = optional(number, 1024)
    subscriptions = optional(map(object({
      max_delivery_count                   = optional(number, 10)
      lock_duration                        = optional(string, "PT1M")
      default_message_ttl                  = optional(string, "P14D")
      dead_lettering_on_message_expiration = optional(bool, true)
    })), {})
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to the namespace."
  type        = map(string)
  default     = {}
}
