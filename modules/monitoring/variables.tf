variable "log_analytics_name" {
  description = "Name of the Log Analytics workspace."
  type        = string
}

variable "application_insights_name" {
  description = "Name of the Application Insights resource."
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

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730 (the PerGB2018 limits)."
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion cap in GB. Use -1 for unlimited."
  type        = number
  default     = 1
}

variable "sampling_percentage" {
  description = "Application Insights telemetry sampling percentage."
  type        = number
  default     = 100

  validation {
    condition     = var.sampling_percentage > 0 && var.sampling_percentage <= 100
    error_message = "sampling_percentage must be greater than 0 and at most 100."
  }
}

variable "application_insights_kind" {
  description = "Application Insights application type."
  type        = string
  default     = "web"
}

variable "tags" {
  description = "Tags applied to both resources."
  type        = map(string)
  default     = {}
}
