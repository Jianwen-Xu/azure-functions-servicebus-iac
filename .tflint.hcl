tflint {
  required_version = ">= 0.50"
}

config {
  call_module_type = "all"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Naming is derived centrally in locals.tf; enforcing tflint's regex rules on
# every resource would fight that design.
rule "azurerm_resource_missing_tags" {
  enabled = true
  tags    = ["project", "environment", "managed_by"]
}
