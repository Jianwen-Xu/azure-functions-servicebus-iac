terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_servicebus_namespace" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku      = var.sku
  capacity = var.capacity

  minimum_tls_version = "1.2"

  # Entra ID only by default: no SAS keys to leak, no rotation runbook needed.
  local_auth_enabled = var.local_auth_enabled

  # Premium-only: 0 = no zone redundancy, 1 or 2 = spread across availability
  # zones. Must be null (not 0) for Standard namespaces.
  premium_messaging_partitions = var.sku == "Premium" ? var.premium_messaging_partitions : null

  tags = var.tags
}

resource "azurerm_servicebus_queue" "this" {
  for_each = var.queues

  name         = each.key
  namespace_id = azurerm_servicebus_namespace.this.id

  max_delivery_count                   = each.value.max_delivery_count
  lock_duration                        = each.value.lock_duration
  default_message_ttl                  = each.value.default_message_ttl
  dead_lettering_on_message_expiration = each.value.dead_lettering_on_message_expiration
  max_size_in_megabytes                = each.value.max_size_in_megabytes
  requires_session                     = each.value.requires_session
  requires_duplicate_detection         = each.value.requires_duplicate_detection

  duplicate_detection_history_time_window = each.value.requires_duplicate_detection ? each.value.duplicate_detection_history_time_window : null

  # Partitioning is not offered on the Premium tier.
  partitioning_enabled = var.partitioning_supported ? var.partitioning_enabled : false

  # Surface stuck messages instead of letting them accumulate silently.
  status = "Active"
}

resource "azurerm_servicebus_topic" "this" {
  for_each = var.topics

  name         = each.key
  namespace_id = azurerm_servicebus_namespace.this.id

  max_size_in_megabytes = each.value.max_size_in_megabytes

  partitioning_enabled = var.partitioning_supported ? var.partitioning_enabled : false
}

resource "azurerm_servicebus_subscription" "this" {
  # Flatten the nested topic -> subscriptions map into a single keyed set.
  for_each = merge([
    for topic_name, topic in var.topics : {
      for sub_name, sub in topic.subscriptions :
      "${topic_name}/${sub_name}" => merge(sub, { topic_name = topic_name })
    }
  ]...)

  name     = element(split("/", each.key), 1)
  topic_id = azurerm_servicebus_topic.this[each.value.topic_name].id

  max_delivery_count                   = each.value.max_delivery_count
  lock_duration                        = each.value.lock_duration
  default_message_ttl                  = each.value.default_message_ttl
  dead_lettering_on_message_expiration = each.value.dead_lettering_on_message_expiration
}

# Only created when SAS auth is explicitly enabled, so the default deployment
# has no key material at all.
resource "azurerm_servicebus_namespace_authorization_rule" "send_listen" {
  count = var.local_auth_enabled ? 1 : 0

  name         = "send-listen"
  namespace_id = azurerm_servicebus_namespace.this.id
  listen       = true
  send         = true
  manage       = false
}
