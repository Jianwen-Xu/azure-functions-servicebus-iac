output "id" {
  description = "Namespace resource ID, used as the scope for RBAC assignments."
  value       = azurerm_servicebus_namespace.this.id
}

output "name" {
  description = "Namespace name."
  value       = azurerm_servicebus_namespace.this.name
}

output "fully_qualified_namespace" {
  description = "Hostname used by AAD-authenticated clients, e.g. mynamespace.servicebus.windows.net."
  value       = "${azurerm_servicebus_namespace.this.name}.servicebus.windows.net"
}

output "queue_names" {
  description = "Names of the queues created."
  value       = sort(keys(azurerm_servicebus_queue.this))
}

output "queue_ids" {
  description = "Map of queue name to resource ID."
  value       = { for k, q in azurerm_servicebus_queue.this : k => q.id }
}

output "topic_names" {
  description = "Names of the topics created."
  value       = sort(keys(azurerm_servicebus_topic.this))
}

output "primary_queue_name" {
  description = "Convenience output: the first queue, which the Function trigger is bound to."
  value       = try(sort(keys(azurerm_servicebus_queue.this))[0], "")
}

output "primary_connection_string" {
  description = "SAS connection string for the send/listen rule. Empty when local auth is disabled."
  value       = var.local_auth_enabled ? azurerm_servicebus_namespace_authorization_rule.send_listen[0].primary_connection_string : ""
  sensitive   = true
}
