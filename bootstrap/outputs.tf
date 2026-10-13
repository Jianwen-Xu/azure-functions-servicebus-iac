output "backend_config" {
  description = "Paste this into envs/<environment>.backend.hcl."
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.state.name}"
    use_azuread_auth     = true
  EOT
}

output "state_storage_account_id" {
  description = "Resource ID of the state storage account."
  value       = azurerm_storage_account.state.id
}

output "container_name" {
  description = "Container holding the state files."
  value       = azurerm_storage_container.state.name
}
