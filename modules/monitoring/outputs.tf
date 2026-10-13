output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID, used as a diagnostic setting target."
  value       = azurerm_log_analytics_workspace.this.id
}

output "application_insights_id" {
  description = "Application Insights resource ID."
  value       = azurerm_application_insights.this.id
}

output "application_insights_connection_string" {
  description = "Connection string injected into the Function App as APPLICATIONINSIGHTS_CONNECTION_STRING."
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}

output "application_insights_instrumentation_key" {
  description = "Legacy instrumentation key, still consumed by older SDKs."
  value       = azurerm_application_insights.this.instrumentation_key
  sensitive   = true
}
