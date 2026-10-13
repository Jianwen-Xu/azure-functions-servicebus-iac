output "resource_group_name" {
  description = "Resource group holding every resource in this stack."
  value       = azurerm_resource_group.this.name
}

output "function_app_name" {
  description = "Name of the deployed Function App."
  value       = module.function_app.name
}

output "function_app_hostname" {
  description = "Default hostname of the Function App."
  value       = module.function_app.default_hostname
}

output "function_plan_sku" {
  description = "App Service plan SKU, used by the deploy workflow to pick the right Functions publishing SKU."
  value       = var.function_plan_sku
}

output "function_app_principal_id" {
  description = "Object ID of the Function App's system-assigned managed identity."
  value       = module.function_app.principal_id
}

output "storage_account_name" {
  description = "Name of the storage account holding the archive container."
  value       = module.storage.name
}

output "archive_container_url" {
  description = "URL of the container the function writes archived messages into."
  value       = "${module.storage.primary_blob_endpoint}/${var.archive_container_name}"
}

output "servicebus_namespace" {
  description = "Fully qualified Service Bus namespace hostname."
  value       = module.servicebus.fully_qualified_namespace
}

output "servicebus_queue_names" {
  description = "Queues created in the namespace."
  value       = module.servicebus.queue_names
}

output "servicebus_topic_names" {
  description = "Topics created in the namespace."
  value       = module.servicebus.topic_names
}

output "application_insights_connection_string" {
  description = "Application Insights connection string."
  value       = module.monitoring.application_insights_connection_string
  sensitive   = true
}

output "servicebus_primary_connection_string" {
  description = "SAS connection string. Empty when local (SAS) auth is disabled, which is the default."
  value       = module.servicebus.primary_connection_string
  sensitive   = true
}
