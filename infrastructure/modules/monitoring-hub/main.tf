# ============================================================
# Action Group — único para toda la plataforma
# ============================================================
resource "azurerm_monitor_action_group" "platform_alerts" {
  name                = var.action_group_name
  resource_group_name = var.hub_resource_group_name
  short_name          = "platform"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.alert_emails
    content {
      name                    = "email-${index(var.alert_emails, email_receiver.value)}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

# ============================================================
# Alerta 1 — OPNsense VM apagada
# ============================================================
resource "azurerm_monitor_metric_alert" "opnsense_vm_down" {
  name                = "alert-hub-opnsense-vm-down"
  resource_group_name = var.hub_resource_group_name
  description         = "La VM de OPNsense (firewall/VPN) está apagada o no disponible. Toda la red privada queda sin salida a Internet."
  severity            = 0
  enabled             = true
  tags                = var.tags

  scopes = [
    "/subscriptions/${var.subscription_id}/resourceGroups/${var.hub_resource_group_name}/providers/Microsoft.Compute/virtualMachines/${var.nva_vm_name}"
  ]

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "VmAvailabilityMetric"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform_alerts.id
  }
}

# ============================================================
# Alerta 2 — VNet peering degradado
# ============================================================
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "vnet_peering_degraded" {
  name                = "alert-hub-vnet-peering-degraded"
  resource_group_name = var.hub_resource_group_name
  location            = var.location
  tags                = var.tags

  display_name         = "[Hub][CRÍTICO] VNet peering degradado"
  description          = "El peering entre el hub y el spoke está degradado o desconectado."
  severity             = 0
  enabled              = true
  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"

  scopes = [var.log_analytics_workspace_id]

  criteria {
    query = <<-QUERY
      AzureActivity
      | where ResourceProvider == "Microsoft.Network"
      | where OperationNameValue contains "virtualNetworkPeerings"
      | where ActivityStatusValue == "Failed"
      | summarize FailedOps = count() by bin(TimeGenerated, 5m)
      | where FailedOps > 0
    QUERY

    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.platform_alerts.id]
  }
}

# ============================================================
# Dashboard — Landing Zone - Infrastructure Monitoring
# ============================================================
resource "azurerm_portal_dashboard" "hub_monitoring" {
  name                = "dashboard-hub-shared-weu-01"
  resource_group_name = var.hub_resource_group_name
  location            = var.location
  tags                = merge(var.tags, { hidden-title = "Landing Zone - Infrastructure Monitoring" })

  dashboard_properties = jsonencode({
    lenses = {
      # ── Sección 1: INFRAESTRUCTURA HUB ──────────────────
      "0" = {
        order = 0
        parts = {
          # Widget 1 — Estado OPNsense
          "0" = {
            position = { x = 0, y = 0, colSpan = 4, rowSpan = 3 }
            metadata = {
              type = "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart"
              inputs = [
                {
                  name  = "resourceId"
                  value = "/subscriptions/${var.subscription_id}/resourceGroups/${var.hub_resource_group_name}/providers/Microsoft.Compute/virtualMachines/${var.nva_vm_name}"
                },
                { name = "timespan", value = { relative = { duration = 86400000 } } },
                { name = "chartType", value = 0 },
                { name = "metrics", value = [{ resourceMetadata = { id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.hub_resource_group_name}/providers/Microsoft.Compute/virtualMachines/${var.nva_vm_name}" }, name = "VmAvailabilityMetric", aggregationType = 4, metricVisualization = { displayName = "Disponibilidad VM" } }] },
                { name = "title", value = "OPNsense - Estado de disponibilidad" }
              ]
            }
          }
          # Widget 2 — CPU OPNsense
          "1" = {
            position = { x = 4, y = 0, colSpan = 4, rowSpan = 3 }
            metadata = {
              type = "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart"
              inputs = [
                {
                  name  = "resourceId"
                  value = "/subscriptions/${var.subscription_id}/resourceGroups/${var.hub_resource_group_name}/providers/Microsoft.Compute/virtualMachines/${var.nva_vm_name}"
                },
                { name = "timespan", value = { relative = { duration = 86400000 } } },
                { name = "chartType", value = 0 },
                { name = "metrics", value = [{ resourceMetadata = { id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.hub_resource_group_name}/providers/Microsoft.Compute/virtualMachines/${var.nva_vm_name}" }, name = "Percentage CPU", aggregationType = 4, metricVisualization = { displayName = "CPU (%)" } }] },
                { name = "title", value = "OPNsense - Uso de CPU (%)" }
              ]
            }
          }
          # Widget 3 — Actividad de red hub
          "2" = {
            position = { x = 8, y = 0, colSpan = 4, rowSpan = 3 }
            metadata = {
              type = "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart"
              inputs = [
                {
                  name  = "resourceId"
                  value = "/subscriptions/${var.subscription_id}/resourceGroups/${var.hub_resource_group_name}/providers/Microsoft.Compute/virtualMachines/${var.nva_vm_name}"
                },
                { name = "timespan", value = { relative = { duration = 86400000 } } },
                { name = "chartType", value = 0 },
                { name = "metrics", value = [
                  { resourceMetadata = { id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.hub_resource_group_name}/providers/Microsoft.Compute/virtualMachines/${var.nva_vm_name}" }, name = "Network In Total", aggregationType = 1, metricVisualization = { displayName = "Red Entrada (bytes)" } },
                  { resourceMetadata = { id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.hub_resource_group_name}/providers/Microsoft.Compute/virtualMachines/${var.nva_vm_name}" }, name = "Network Out Total", aggregationType = 1, metricVisualization = { displayName = "Red Salida (bytes)" } }
                ]},
                { name = "title", value = "OPNsense - Tráfico de red (bytes)" }
              ]
            }
          }
          # Widget 4 — Alertas activas en el hub
          "3" = {
            position = { x = 0, y = 3, colSpan = 12, rowSpan = 3 }
            metadata = {
              type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
              inputs = [
                { name = "resourceTypeMode", isOptional = true, value = "workspace" },
                { name = "ComponentId", isOptional = true, value = { SubscriptionId = "", ResourceGroup = var.hub_resource_group_name, Name = "", ResourceId = var.log_analytics_workspace_id } },
                {
                  name  = "Query"
                  value = "AzureActivity\n| where ResourceProvider == \"Microsoft.Network\"\n| where ActivityStatusValue == \"Failed\"\n| summarize Fallos = count() by OperationNameValue, bin(TimeGenerated, 1h)\n| order by TimeGenerated desc\n| render table"
                },
                { name = "TimeRange", value = "P1D" },
                { name = "Version", value = "2.0" },
                { name = "PartTitle", value = "Operaciones de red fallidas (últimas 24h)" },
                { name = "PartSubTitle", value = "Hub VNet · Peerings · NSG" }
              ]
            }
          }
        }
      }
    }
    metadata = {
      model = {
        timeRange = {
          value = { relative = { duration = 24, timeUnit = 1 } }
          type  = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
        filterLocale = { value = "en-us" }
        filters      = { value = { MsPortalFx_TimeRange = { model = { format = "utc", granularity = "auto", relative = "24h" }, displayCache = { name = "UTC Time", value = "Past 24 hours" }, filteredPartIds = [] } } }
      }
    }
  })
}
