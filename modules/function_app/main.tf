terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_service_plan" "this" {
  name                = var.plan_name
  resource_group_name = var.resource_group_name
  location            = var.location

  os_type  = "Linux"
  sku_name = var.plan_sku

  # Consumption plans are scaled by the platform; a fixed worker count is only
  # meaningful for Elastic Premium.
  worker_count = var.plan_sku == "Y1" ? null : var.worker_count

  tags = var.tags
}

resource "azurerm_linux_function_app" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  service_plan_id            = azurerm_service_plan.this.id
  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_access_key

  https_only                    = true
  functions_extension_version   = "~4"
  public_network_access_enabled = var.public_network_access_enabled

  # System-assigned identity only: the app is deleted with its identity, so
  # there is no orphaned principal to clean up.
  identity {
    type = "SystemAssigned"
  }

  site_config {
    # Consumption plans cannot stay warm; Premium can.
    always_on                              = var.plan_sku != "Y1"
    ftps_state                             = "Disabled"
    minimum_tls_version                    = "1.2"
    http2_enabled                          = true
    application_insights_connection_string = var.application_insights_connection_string

    # Single runtime stack selected by the caller.
    application_stack {
      python_version = var.application_stack.python_version
      dotnet_version = var.application_stack.dotnet_version
      node_version   = var.application_stack.node_version
    }

    dynamic "ip_restriction" {
      for_each = var.allowed_ip_ranges
      content {
        name       = "allow-${ip_restriction.key}"
        ip_address = ip_restriction.value
        action     = "Allow"
        priority   = 100 + ip_restriction.key
      }
    }
  }

  app_settings = merge(
    {
      # Deploy by zip: the artifact is mounted read-only and the runtime does not
      # unpack into wwwroot, which makes deploys atomic.
      WEBSITE_RUN_FROM_PACKAGE              = "1"
      APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights_connection_string
      FUNCTIONS_EXTENSION_VERSION           = "~4"
      # Sampling is a host setting, not a site_config attribute.
      APPLICATIONINSIGHTS_SAMPLING_PERCENTAGE = tostring(var.application_insights_sampling_percentage)
      # Disable the shared-secret surface for the Functions host.
      WEBSITE_CONTENTOVERVNET = "0"
    },
    var.app_settings,
  )

  lifecycle {
    # `func azure functionapp publish` and the GitHub deploy action rewrite this
    # to a versioned blob SAS URL. Tracking it here would fight the deployer.
    ignore_changes = [app_settings["WEBSITE_RUN_FROM_PACKAGE"]]
  }

  tags = var.tags
}
