locals {
  prefix = "${var.project}-${var.environment}"
  suffix = var.name_suffix != "" ? var.name_suffix : random_string.suffix[0].result

  # Every resource carries these three; anything else (owner, cost centre) is
  # supplied through var.tags. Indexing var.tags directly here would fail
  # whenever a caller leaves tags at its default of {}.
  tags = merge(
    {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
    },
    var.tags,
  )

  # Azure enforces different naming rules per resource type, so every globally
  # unique name is derived once here and passed down as a plain string. Modules
  # never invent their own names.
  resource_group_name  = "rg-${local.prefix}"
  storage_account_name = substr(lower(replace("st${var.project}${var.environment}${local.suffix}", "-", "")), 0, 24)
  servicebus_name      = "${local.prefix}-sb-${local.suffix}"
  function_app_name    = "${local.prefix}-func-${local.suffix}"
  plan_name            = "${local.prefix}-plan"
  log_analytics_name   = "log-${local.prefix}-${local.suffix}"
  app_insights_name    = "appi-${local.prefix}-${local.suffix}"

  # Partitioning is a Standard-tier feature; Premium namespaces reject the flag.
  servicebus_partitioning_supported = var.servicebus_sku != "Premium"
  servicebus_capacity               = var.servicebus_sku == "Premium" ? var.servicebus_capacity : null
}
