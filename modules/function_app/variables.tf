variable "name" {
  description = "Globally unique Function App name."
  type        = string
}

variable "plan_name" {
  description = "Name of the App Service plan that hosts the app."
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

variable "plan_sku" {
  description = "App Service plan SKU. Y1 is Linux Consumption; EP1-EP3 is Elastic Premium."
  type        = string
  default     = "Y1"

  validation {
    condition     = can(regex("^(Y1|EP[123])$", var.plan_sku))
    error_message = "plan_sku must be Y1, EP1, EP2 or EP3."
  }
}

variable "worker_count" {
  description = "Fixed worker count for Elastic Premium plans. Ignored on Consumption."
  type        = number
  default     = 1
}

variable "application_stack" {
  description = "Runtime stack. Set exactly one language version."
  type = object({
    python_version = optional(string)
    dotnet_version = optional(string)
    node_version   = optional(string)
  })
  default = {
    python_version = "3.12"
  }

  validation {
    condition = length([
      for v in [
        var.application_stack.python_version,
        var.application_stack.dotnet_version,
        var.application_stack.node_version,
      ] : v if v != null
    ]) == 1
    error_message = "Exactly one of python_version, dotnet_version or node_version must be set."
  }
}

variable "storage_account_name" {
  description = "Storage account backing the Functions host (queues, timers, deployment package)."
  type        = string
}

variable "storage_account_access_key" {
  description = "Access key for the host storage account."
  type        = string
  sensitive   = true
}

variable "application_insights_connection_string" {
  description = "Application Insights connection string."
  type        = string
  sensitive   = true
  default     = ""
}

variable "application_insights_sampling_percentage" {
  description = "Sampling rate applied by the Functions host."
  type        = number
  default     = 100
}

variable "app_settings" {
  description = "Application settings merged over the module defaults."
  type        = map(string)
  default     = {}
}

variable "allowed_ip_ranges" {
  description = "CIDR ranges allowed inbound to the Function App. Empty leaves the platform default (public)."
  type        = list(string)
  default     = []
}

variable "public_network_access_enabled" {
  description = "Expose the Function App on a public endpoint. Disable only behind a private endpoint."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the plan and the app."
  type        = map(string)
  default     = {}
}
