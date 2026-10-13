// ---------------------------------------------------------------------------
// One-time bootstrap for the Terraform remote state backend.
//
// This is deliberately a separate root module with LOCAL state: it creates the
// storage account that every other configuration stores its state in, so it
// cannot depend on remote state itself.
//
//   cd bootstrap
//   terraform init
//   terraform apply -var="state_storage_account_name=sttfstateabc12"
//   terraform output -raw backend_config_dev   # paste into envs/dev.backend.hcl
// ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

variable "location" {
  description = "Region for the state storage account."
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Resource group that holds the state storage account."
  type        = string
  default     = "rg-tfstate"
}

variable "state_storage_account_name" {
  description = "Globally unique name for the state storage account (3-24 lowercase alphanumeric)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.state_storage_account_name))
    error_message = "Storage account names must be 3-24 lowercase alphanumeric characters."
  }
}

variable "container_name" {
  description = "Blob container that stores state files."
  type        = string
  default     = "tfstate"
}

locals {
  tags = {
    purpose    = "terraform-state"
    managed_by = "terraform"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "state" {
  name                = var.state_storage_account_name
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location

  account_tier             = "Standard"
  account_replication_type = "ZRS" # state must survive a datacentre failure
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = true
  shared_access_key_enabled       = false # Entra ID auth only
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  blob_properties {
    versioning_enabled = true

    # Terraform state is the one file you never want to lose to an overwrite.
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = local.tags
}

resource "azurerm_storage_container" "state" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# Grant the operator (and CI's federated identity) blob access without keys.
resource "azurerm_role_assignment" "state_blob_owner" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_management_lock" "state" {
  name       = "protect-tfstate"
  scope      = azurerm_storage_account.state.id
  lock_level = "CanNotDelete"
  notes      = "Terraform state storage. Deleting this destroys every environment's state."
}
