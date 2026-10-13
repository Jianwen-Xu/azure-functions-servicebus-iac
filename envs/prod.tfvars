# Production environment.
#   terraform init -backend-config=envs/prod.backend.hcl
#   terraform apply -var-file=envs/prod.tfvars
#
# Differences from dev that matter: zone-redundant storage, a Premium Service Bus
# namespace, Elastic Premium hosting so the app is always warm, and longer log
# retention.

project     = "sbarch"
environment = "prod"
location    = "westeurope"

tags = {
  owner = "jianwen.xu"
}

# ZRS keeps the archive available through a single datacentre failure.
storage_replication_type = "ZRS"

# Premium gives VNet integration, predictable throughput and no shared capacity.
servicebus_sku                = "Premium"
servicebus_capacity           = 1
servicebus_local_auth_enabled = false

# Spread the namespace across availability zones. Premium-only setting.
servicebus_premium_messaging_partitions = 1

# Elastic Premium: no cold start on the ingest path.
function_plan_sku = "EP1"

function_application_stack = {
  python_version = "3.12"
}

function_app_settings = {
  ARCHIVE_BATCH_SIZE = "500"
  LOG_LEVEL          = "WARNING"
}

archive_container_name = "archive"
log_retention_days     = 90
budget_amount          = 200
