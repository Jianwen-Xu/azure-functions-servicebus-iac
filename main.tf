resource "random_string" "suffix" {
  # Created only when the caller did not pin an explicit suffix. The keepers make
  # the generated value stable across re-applies, so resource names never churn.
  count = var.name_suffix == "" ? 1 : 0

  length  = 5
  lower   = true
  upper   = false
  numeric = true
  special = false

  keepers = {
    project     = var.project
    environment = var.environment
  }
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------

module "monitoring" {
  source = "./modules/monitoring"

  log_analytics_name        = local.log_analytics_name
  application_insights_name = local.app_insights_name
  resource_group_name       = azurerm_resource_group.this.name
  location                  = azurerm_resource_group.this.location
  log_retention_days        = var.log_retention_days
  application_insights_kind = "web"
  tags                      = local.tags
}

# ---------------------------------------------------------------------------
# Data plane: storage + messaging
# ---------------------------------------------------------------------------

module "storage" {
  source = "./modules/storage"

  name                = local.storage_account_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  replication_type    = var.storage_replication_type
  containers          = [var.archive_container_name]
  allowed_ip_rules    = var.storage_allowed_ip_rules
  tags                = local.tags
}

module "servicebus" {
  source = "./modules/servicebus"

  name                         = local.servicebus_name
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location
  sku                          = var.servicebus_sku
  capacity                     = local.servicebus_capacity
  premium_messaging_partitions = var.servicebus_premium_messaging_partitions
  local_auth_enabled           = var.servicebus_local_auth_enabled
  partitioning_supported       = local.servicebus_partitioning_supported
  queues                       = var.servicebus_queues
  topics                       = var.servicebus_topics
  tags                         = local.tags
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------

module "function_app" {
  source = "./modules/function_app"

  name                       = local.function_app_name
  plan_name                  = local.plan_name
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  plan_sku                   = var.function_plan_sku
  application_stack          = var.function_application_stack
  storage_account_name       = module.storage.name
  storage_account_access_key = module.storage.primary_access_key

  application_insights_connection_string = module.monitoring.application_insights_connection_string

  # Setting the fully-qualified namespace (instead of a connection string) makes
  # the Service Bus extension authenticate with the Function App's managed
  # identity for every trigger and binding.
  app_settings = merge(
    {
      ServiceBusConnection__fullyQualifiedNamespace = module.servicebus.fully_qualified_namespace
      SERVICEBUS_QUEUE_NAME                         = module.servicebus.primary_queue_name
      STORAGE_BLOB_ENDPOINT                         = module.storage.primary_blob_endpoint
      ARCHIVE_CONTAINER                             = var.archive_container_name
      ARCHIVE_CONTAINER_URL                         = "${module.storage.primary_blob_endpoint}/${var.archive_container_name}"
    },
    var.function_app_settings,
  )

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Role assignments: grant the Function App's system-assigned identity the
# minimum data-plane roles it needs. No keys are handed to the application.
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "function_servicebus_receiver" {
  scope                = module.servicebus.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = module.function_app.principal_id
  principal_type       = "ServicePrincipal"
  description          = "Function App consumes messages from the ingest queue."
}

resource "azurerm_role_assignment" "function_servicebus_sender" {
  scope                = module.servicebus.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = module.function_app.principal_id
  principal_type       = "ServicePrincipal"
  description          = "Function App publishes to downstream topics."
}

resource "azurerm_role_assignment" "function_storage_blob_contributor" {
  scope                = module.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.function_app.principal_id
  principal_type       = "ServicePrincipal"
  description          = "Function App writes archived payloads into the archive container."
}

# Send diagnostic logs from the messaging namespace into the same workspace that
# backs Application Insights, so a message trace and its function logs line up.
resource "azurerm_monitor_diagnostic_setting" "servicebus" {
  name                       = "${local.servicebus_name}-diag"
  target_resource_id         = module.servicebus.id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# ---------------------------------------------------------------------------
# Cost guard rail
# ---------------------------------------------------------------------------

resource "azurerm_consumption_budget_resource_group" "this" {
  name              = "budget-${local.prefix}"
  resource_group_id = azurerm_resource_group.this.id
  amount            = var.budget_amount
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_roles = ["Owner"]
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}
