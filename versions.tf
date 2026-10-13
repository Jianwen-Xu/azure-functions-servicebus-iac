terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Partial configuration: connection details for the state backend are supplied
  # at init time so that no storage account keys ever land in version control.
  #
  #   terraform init -backend-config=envs/dev.backend.hcl
  #
  # See envs/dev.backend.hcl.example and bootstrap/ for the one-time setup.
  backend "azurerm" {}
}
