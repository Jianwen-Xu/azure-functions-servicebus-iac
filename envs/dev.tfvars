# Development environment.
#   terraform init -backend-config=envs/dev.backend.hcl
#   terraform apply -var-file=envs/dev.tfvars

project     = "sbarch"
environment = "dev"
location    = "westeurope"

tags = {
  owner = "jianwen.xu"
}

storage_replication_type      = "LRS"
servicebus_sku                = "Standard"
servicebus_local_auth_enabled = false

function_plan_sku = "Y1"

function_application_stack = {
  python_version = "3.12"
}

archive_container_name = "archive"
log_retention_days     = 30
budget_amount          = 20
