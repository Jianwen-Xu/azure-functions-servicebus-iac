output "id" {
  description = "Function App resource ID."
  value       = azurerm_linux_function_app.this.id
}

output "name" {
  description = "Function App name."
  value       = azurerm_linux_function_app.this.name
}

output "default_hostname" {
  description = "Default hostname, e.g. myapp.azurewebsites.net."
  value       = azurerm_linux_function_app.this.default_hostname
}

output "principal_id" {
  description = "Object ID of the system-assigned managed identity, used as the RBAC principal."
  value       = azurerm_linux_function_app.this.identity[0].principal_id
}

output "service_plan_id" {
  description = "App Service plan resource ID."
  value       = azurerm_service_plan.this.id
}

output "outbound_ip_addresses" {
  description = "Possible outbound IPs, useful when allow-listing this app upstream."
  value       = azurerm_linux_function_app.this.possible_outbound_ip_addresses
}
