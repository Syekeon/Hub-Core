locals {
  region_short = var.location == "westeurope" ? "weu" : var.location

  hub_vnet_name = "${var.hub_name}-vnet"
  nva_name      = "${var.hub_name}-vm-nva"
  hub_log_analytics_name      = "log-${var.hub_name}-${local.region_short}-${var.instance}"
  hub_application_insights_name = "appi-${var.hub_name}-${local.region_short}-${var.instance}"
}
