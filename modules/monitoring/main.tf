terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku               = "PerGB2018"
  retention_in_days = var.log_retention_days

  # Cap ingestion so a runaway loop cannot produce an unbounded bill.
  daily_quota_gb = var.daily_quota_gb

  tags = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = var.application_insights_name
  resource_group_name = var.resource_group_name
  location            = var.location

  application_type = var.application_insights_kind

  # Workspace-based Application Insights: traces, metrics and platform logs all
  # land in one place, which is what makes cross-service queries possible.
  workspace_id = azurerm_log_analytics_workspace.this.id

  # -1 disables the cap; a positive value alerts when ingestion exceeds it.
  daily_data_cap_in_gb = var.daily_quota_gb
  sampling_percentage  = var.sampling_percentage

  tags = var.tags
}
