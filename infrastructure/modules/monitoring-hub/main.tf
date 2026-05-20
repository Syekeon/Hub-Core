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
# JSON exportado desde el portal y convertido al formato Terraform
# ============================================================
resource "azurerm_portal_dashboard" "hub_monitoring" {
  name                = "dashboard-hub-shared-weu-01"
  resource_group_name = var.hub_resource_group_name
  location            = var.location
  tags                = merge(var.tags, { hidden-title = "Landing Zone - Infrastructure Monitoring" })

  dashboard_properties = jsonencode({
  "lenses": {
    "0": {
      "order": 0,
      "parts": {
        "0": {
          "position": {
            "x": 0,
            "y": 0,
            "colSpan": 4,
            "rowSpan": 3
          },
          "metadata": {
            "inputs": [
              {
                "name": "options",
                "isOptional": true
              },
              {
                "name": "sharedTimeRange",
                "isOptional": true
              }
            ],
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "settings": {
              "content": {
                "options": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/e19e0ebc-a9ed-4d6f-985f-f0a9fb8b544b/resourceGroups/rg-hub/providers/Microsoft.Compute/virtualMachines/hub-vm-nva"
                        },
                        "name": "VmAvailabilityMetric",
                        "aggregationType": 4,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": {
                          "displayName": "VM Availability Metric (Preview)",
                          "resourceDisplayName": "hub-vm-nva"
                        }
                      }
                    ],
                    "title": "OPNsense - Estado de disponibilidad",
                    "titleKind": 2,
                    "visualization": {
                      "chartType": 2,
                      "legendVisualization": {
                        "isVisible": true,
                        "position": 2,
                        "hideHoverCard": false,
                        "hideLabelNames": true
                      },
                      "axisVisualization": {
                        "x": {
                          "isVisible": true,
                          "axisType": 2
                        },
                        "y": {
                          "isVisible": true,
                          "axisType": 1
                        }
                      },
                      "disablePinning": true
                    }
                  }
                }
              }
            },
            "filters": {
              "MsPortalFx_TimeRange": {
                "model": {
                  "format": "utc",
                  "granularity": "auto",
                  "absolute": {
                    "fromDate": "2026-05-18T22:55:19.355Z",
                    "toDate": "2026-05-19T22:55:19.355Z"
                  }
                }
              }
            }
          }
        },
        "1": {
          "position": {
            "x": 4,
            "y": 0,
            "colSpan": 4,
            "rowSpan": 3
          },
          "metadata": {
            "inputs": [
              {
                "name": "options",
                "isOptional": true
              },
              {
                "name": "sharedTimeRange",
                "isOptional": true
              }
            ],
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "settings": {
              "content": {
                "options": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/e19e0ebc-a9ed-4d6f-985f-f0a9fb8b544b/resourceGroups/rg-hub/providers/Microsoft.Compute/virtualMachines/hub-vm-nva"
                        },
                        "name": "Percentage CPU",
                        "aggregationType": 4,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": {
                          "displayName": "Percentage CPU",
                          "resourceDisplayName": "hub-vm-nva"
                        }
                      }
                    ],
                    "title": " OPNsense - Uso de CPU (%)",
                    "titleKind": 2,
                    "visualization": {
                      "chartType": 2,
                      "legendVisualization": {
                        "isVisible": true,
                        "position": 2,
                        "hideHoverCard": false,
                        "hideLabelNames": true
                      },
                      "axisVisualization": {
                        "x": {
                          "isVisible": true,
                          "axisType": 2
                        },
                        "y": {
                          "isVisible": true,
                          "axisType": 1
                        }
                      },
                      "disablePinning": true
                    }
                  }
                }
              }
            }
          }
        },
        "2": {
          "position": {
            "x": 8,
            "y": 0,
            "colSpan": 4,
            "rowSpan": 3
          },
          "metadata": {
            "inputs": [
              {
                "name": "options",
                "isOptional": true
              },
              {
                "name": "sharedTimeRange",
                "isOptional": true
              }
            ],
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "settings": {
              "content": {
                "options": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/e19e0ebc-a9ed-4d6f-985f-f0a9fb8b544b/resourceGroups/rg-hub/providers/Microsoft.Compute/virtualMachines/hub-vm-nva"
                        },
                        "name": "Network In Total",
                        "aggregationType": 1,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": {
                          "displayName": "Network In Total",
                          "resourceDisplayName": "hub-vm-nva"
                        }
                      },
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/e19e0ebc-a9ed-4d6f-985f-f0a9fb8b544b/resourceGroups/rg-hub/providers/Microsoft.Compute/virtualMachines/hub-vm-nva"
                        },
                        "name": "Network Out Total",
                        "aggregationType": 1,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": {
                          "displayName": "Network Out Total",
                          "resourceDisplayName": "hub-vm-nva"
                        }
                      }
                    ],
                    "title": "OPNsense - Tráfico de red (bytes)",
                    "titleKind": 2,
                    "visualization": {
                      "chartType": 2,
                      "legendVisualization": {
                        "isVisible": true,
                        "position": 2,
                        "hideHoverCard": false,
                        "hideLabelNames": true
                      },
                      "axisVisualization": {
                        "x": {
                          "isVisible": true,
                          "axisType": 2
                        },
                        "y": {
                          "isVisible": true,
                          "axisType": 1
                        }
                      },
                      "disablePinning": true
                    }
                  }
                }
              }
            }
          }
        },
        "3": {
          "position": {
            "x": 0,
            "y": 3,
            "colSpan": 12,
            "rowSpan": 4
          },
          "metadata": {
            "inputs": [
              {
                "name": "resourceTypeMode",
                "isOptional": true
              },
              {
                "name": "ComponentId",
                "isOptional": true
              },
              {
                "name": "Scope",
                "value": {
                  "resourceIds": [
                    "/subscriptions/e19e0ebc-a9ed-4d6f-985f-f0a9fb8b544b/resourceGroups/rg-hub/providers/Microsoft.OperationalInsights/workspaces/log-hub-weu-01"
                  ]
                },
                "isOptional": true
              },
              {
                "name": "PartId",
                "value": "14ed5a56-3c81-4681-9777-825ee71514be",
                "isOptional": true
              },
              {
                "name": "Version",
                "value": "2.0",
                "isOptional": true
              },
              {
                "name": "TimeRange",
                "value": "P1D",
                "isOptional": true
              },
              {
                "name": "DashboardId",
                "isOptional": true
              },
              {
                "name": "DraftRequestParameters",
                "isOptional": true
              },
              {
                "name": "Query",
                "value": "AzureActivity\n| where ResourceProvider == \"Microsoft.Network\"\n| where ActivityStatusValue == \"Failed\"\n| summarize Fallos = count() by OperationNameValue, bin(TimeGenerated, 1h)\n| order by TimeGenerated desc\n| render table\n",
                "isOptional": true
              },
              {
                "name": "ControlType",
                "value": "AnalyticsGrid",
                "isOptional": true
              },
              {
                "name": "SpecificChart",
                "isOptional": true
              },
              {
                "name": "PartTitle",
                "value": "Analytics",
                "isOptional": true
              },
              {
                "name": "PartSubTitle",
                "value": "log-hub-weu-01",
                "isOptional": true
              },
              {
                "name": "Dimensions",
                "isOptional": true
              },
              {
                "name": "LegendOptions",
                "isOptional": true
              },
              {
                "name": "IsQueryContainTimeRange",
                "value": false,
                "isOptional": true
              }
            ],
            "type": "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart",
            "settings": {},
            "partHeader": {
              "title": "Operaciones de red fallidas (Log Analytics)",
              "subtitle": ""
            }
          }
        }
      }
    }
  },
  "metadata": {
    "model": {
      "timeRange": {
        "value": {
          "relative": {
            "duration": 24,
            "timeUnit": 1
          }
        },
        "type": "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
      },
      "filterLocale": {
        "value": "en-us"
      },
      "filters": {
        "value": {
          "MsPortalFx_TimeRange": {
            "model": {
              "format": "utc",
              "granularity": "auto",
              "relative": "24h"
            },
            "displayCache": {
              "name": "UTC Time",
              "value": "Past 24 hours"
            },
            "filteredPartIds": [
              "StartboardPart-MonitorChartPart-8397a42d-7fc0-4016-8757-677c71ef2814",
              "StartboardPart-MonitorChartPart-8397a42d-7fc0-4016-8757-677c71ef2816",
              "StartboardPart-MonitorChartPart-8397a42d-7fc0-4016-8757-677c71ef2818",
              "StartboardPart-LogsDashboardPart-8397a42d-7fc0-4016-8757-677c71ef281a"
            ]
          }
        }
      }
    }
  }
})
}
