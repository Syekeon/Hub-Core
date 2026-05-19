output "hub_vnet_id" {
  value = module.hub_network.hub_vnet_id
}

output "hub_vnet_name" {
  value = module.hub_network.hub_vnet_name
}

output "hub_resource_group_name" {
  value = module.resource_groups.resource_group_name
}

output "hub_firewall_private_ip" {
  value = module.nva_opnsense.trust_private_ip
}

output "private_dns_zone_ids" {
  value = module.private_dns.private_dns_zone_ids
}

output "private_dns_zone_names" {
  value = module.private_dns.private_dns_zone_names
}

output "nva_public_ip" {
  value = module.nva_opnsense.public_ip
}

output "nva_vm_name" {
  value = module.nva_opnsense.vm_name
}

output "log_analytics_workspace_id" {
  value = module.observability.log_analytics_workspace_id
}

output "application_insights_id" {
  value = module.observability.application_insights_id
}

output "action_group_id" {
  value       = module.monitoring_hub.action_group_id
  description = "ID del Action Group ag-platform-alerts"
}
