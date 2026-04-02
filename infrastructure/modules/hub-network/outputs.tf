output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "nva_trust_subnet_id" {
  value = azurerm_subnet.nva_trust.id
}

output "nva_untrust_subnet_id" {
  value = azurerm_subnet.nva_untrust.id
}
