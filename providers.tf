provider "azurerm" {
  # Authentication is intentionally left to the ambient credential chain:
  #   - locally: `az login` / Azure CLI credential
  #   - CI:      GitHub OIDC federated credential (no client secret stored)
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}
