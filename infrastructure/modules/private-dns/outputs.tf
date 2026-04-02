output "private_dns_zone_ids" {
  value = { for k, v in azurerm_private_dns_zone.this : k => v.id }
}

output "private_dns_zone_names" {
  value = { for k, v in azurerm_private_dns_zone.this : k => v.name }
}
