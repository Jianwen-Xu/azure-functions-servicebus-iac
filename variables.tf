variable "project" {
  description = "Short project slug used as the first part of every resource name."
  type        = string
  default     = "sbarch"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,10}$", var.project))
    error_message = "project must be 2-11 chars, lowercase alphanumeric, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment. Drives naming, SKUs and retention defaults."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "name_suffix" {
  description = <<-EOT
    Optional 5-character suffix appended to globally unique names (storage account,
    Service Bus namespace, Function App). Leave empty to derive a stable random
    suffix from project + environment.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.name_suffix == "" || can(regex("^[a-z0-9]{5}$", var.name_suffix))
    error_message = "name_suffix must be empty or exactly 5 lowercase alphanumeric characters."
  }
}

variable "tags" {
  description = "Additional tags merged onto every resource."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------

variable "storage_replication_type" {
  description = "Storage replication SKU for the Function App's host storage."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.storage_replication_type)
    error_message = "storage_replication_type must be a valid Azure replication SKU."
  }
}

variable "storage_allowed_ip_rules" {
  description = <<-EOT
    Public IPs (or CIDR ranges) allowed through the storage firewall. The default
    action stays "Deny" and the AzureServices bypass is enabled, so this list is
    only needed for developer machines that talk to the archive container directly.
  EOT
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Service Bus
# ---------------------------------------------------------------------------

variable "servicebus_sku" {
  description = "Service Bus namespace SKU. Premium is required for VNet integration and zone redundancy."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.servicebus_sku)
    error_message = "servicebus_sku must be Standard or Premium. Basic cannot dead-letter or use topics, so it is deliberately excluded."
  }
}

variable "servicebus_capacity" {
  description = "Messaging units. Only applied when servicebus_sku is Premium (1, 2, 4, 8, 16)."
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 2, 4, 8, 16], var.servicebus_capacity)
    error_message = "servicebus_capacity must be one of 1, 2, 4, 8, 16."
  }
}

variable "servicebus_premium_messaging_partitions" {
  description = "Messaging partitions for a Premium namespace. 0 = none, 1 or 2 = zone redundant. Ignored on Standard."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 2], var.servicebus_premium_messaging_partitions)
    error_message = "servicebus_premium_messaging_partitions must be 0, 1 or 2."
  }
}

variable "servicebus_queues" {
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

variable "servicebus_topics" {
  description = "Topics to create (keyed by name) together with their subscriptions."
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

variable "servicebus_local_auth_enabled" {
  description = <<-EOT
    Allow SAS key authentication on the namespace. Disabled by default so that
    only Entra ID (managed identity) callers can send or receive. Enable only if
    a legacy client genuinely cannot use AAD.
  EOT
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Function App
# ---------------------------------------------------------------------------

variable "function_plan_sku" {
  description = "App Service plan SKU for the Function App. Y1 = Linux Consumption, EP1-EP3 = Elastic Premium."
  type        = string
  default     = "Y1"

  validation {
    condition     = can(regex("^(Y1|EP[123])$", var.function_plan_sku))
    error_message = "function_plan_sku must be Y1 (Consumption) or EP1/EP2/EP3 (Elastic Premium)."
  }
}

variable "function_application_stack" {
  description = "Runtime stack for the Function App. Set exactly one language version."
  type = object({
    python_version = optional(string)
    dotnet_version = optional(string)
    node_version   = optional(string)
  })
  default = {
    python_version = "3.12"
  }
}

variable "function_app_settings" {
  description = "Extra application settings merged on top of the ones derived from the other modules."
  type        = map(string)
  default     = {}
}

variable "archive_container_name" {
  description = "Blob container the function writes archived messages into."
  type        = string
  default     = "archive"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])?$", var.archive_container_name))
    error_message = "container names must be 3-63 chars, lowercase alphanumeric or hyphens, and cannot start or end with a hyphen."
  }
}

variable "log_retention_days" {
  description = "Retention for the Log Analytics workspace backing Application Insights."
  type        = number
  default     = 30
}

variable "budget_amount" {
  description = "Monthly cost budget in the subscription currency. Alert only, nothing is enforced."
  type        = number
  default     = 50
}
