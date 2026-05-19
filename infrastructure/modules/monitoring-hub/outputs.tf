output "action_group_id" {
  value       = azurerm_monitor_action_group.platform_alerts.id
  description = "ID del Action Group ag-platform-alerts — usar en MLOps-Platform"
}

output "action_group_name" {
  value       = azurerm_monitor_action_group.platform_alerts.name
  description = "Nombre del Action Group"
}

output "dashboard_id" {
  value       = azurerm_portal_dashboard.hub_monitoring.id
  description = "ID del dashboard de infraestructura"
}
