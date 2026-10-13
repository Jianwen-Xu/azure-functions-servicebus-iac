terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_storage_account" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = "Standard"
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  # The Function runtime keeps its own keys private; application code never
  # sees them because it authenticates with the managed identity instead.
  public_network_access_enabled = true
  shared_access_key_enabled     = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.soft_delete_retention_days
    }
  }

  network_rules {
    # Deny by default. "AzureServices" lets platform services (including the
    # Function App) reach the account; ip_rules are for developer machines.
    default_action             = var.allowed_ip_rules == [] && var.allowed_subnet_ids == [] ? "Allow" : "Deny"
    bypass                     = ["AzureServices", "Logging", "Metrics"]
    ip_rules                   = var.allowed_ip_rules
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  tags = var.tags
}

resource "azurerm_storage_container" "this" {
  for_each = toset(var.containers)

  name                  = each.value
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# Keep the cheap tier for ageing archives, then retire them. Without this the
# archive container grows at full hot-tier cost forever.
resource "azurerm_storage_management_policy" "this" {
  count = var.enable_lifecycle_policy && var.lifecycle_prefix == "" ? 1 : 0

  storage_account_id = azurerm_storage_account.this.id

  rule {
    name    = "archive-tiering"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = var.cool_after_days
        tier_to_archive_after_days_since_modification_greater_than = var.archive_after_days
        delete_after_days_since_modification_greater_than          = var.delete_after_days
      }

      snapshot {
        delete_after_days_since_creation_greater_than = var.delete_after_days
      }
    }
  }
}
