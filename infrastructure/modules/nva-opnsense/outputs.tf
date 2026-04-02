output "public_ip" {
  value = azurerm_public_ip.nva.ip_address
}

output "public_ip_id" {
  value = azurerm_public_ip.nva.id
}

output "untrust_nsg_id" {
  value = azurerm_network_security_group.untrust.id
}

output "untrust_private_ip" {
  value = azurerm_network_interface.untrust.private_ip_address
}

output "trust_private_ip" {
  value = azurerm_network_interface.trust.private_ip_address
}

output "vm_id" {
  value = azurerm_linux_virtual_machine.nva.id
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.nva.name
}

output "ssh_command" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.nva.ip_address}"
}

output "web_ui_url" {
  value = "https://${azurerm_public_ip.nva.ip_address}"
}
