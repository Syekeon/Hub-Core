resource "azurerm_virtual_network" "hub" {
  name                = var.hub_vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.hub_vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "nva_untrust" {
  name                 = "snet-nva-untrust"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_nva_untrust_subnet_cidr]
}

resource "azurerm_subnet" "nva_trust" {
  name                 = "snet-nva-trust"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_nva_trust_subnet_cidr]
}
