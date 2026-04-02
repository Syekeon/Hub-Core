resource "azurerm_public_ip" "nva" {
  name                = var.public_ip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_security_group" "untrust" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-https-internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ssh-internet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http-internet"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-openvpn-internet"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "1194"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_network_interface" "untrust" {
  name                 = var.nic_untrust_name
  location             = var.location
  resource_group_name  = var.resource_group_name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "untrust"
    subnet_id                     = var.subnet_untrust_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nva.id
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "untrust" {
  network_interface_id      = azurerm_network_interface.untrust.id
  network_security_group_id = azurerm_network_security_group.untrust.id
}

resource "azurerm_network_interface" "trust" {
  name                 = var.nic_trust_name
  location             = var.location
  resource_group_name  = var.resource_group_name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "trust"
    subnet_id                     = var.subnet_trust_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.trust_private_ip
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "nva" {
  name                  = var.vm_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.untrust.id,
    azurerm_network_interface.trust.id
  ]

  disable_password_authentication = var.ssh_public_key_path != null

  dynamic "admin_ssh_key" {
    for_each = var.ssh_public_key_path != null ? [1] : []
    content {
      username   = var.admin_username
      public_key = file(var.ssh_public_key_path)
    }
  }

  os_disk {
    name                 = var.os_disk_name
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 32
  }

  source_image_reference {
    publisher = "thefreebsdfoundation"
    offer     = "freebsd-14_1"
    sku       = "14_1-release-amd64-gen2-zfs"
    version   = "latest"
  }

  plan {
    name      = "14_1-release-amd64-gen2-zfs"
    product   = "freebsd-14_1"
    publisher = "thefreebsdfoundation"
  }

  boot_diagnostics {}

  tags = var.tags

  depends_on = [
    azurerm_network_interface.untrust,
    azurerm_network_interface.trust,
    azurerm_network_interface_security_group_association.untrust
  ]
}

resource "azurerm_virtual_machine_extension" "opnsense_install" {
  name                 = "opnsense-install"
  virtual_machine_id   = azurerm_linux_virtual_machine.nva.id
  publisher            = "Microsoft.OSTCExtensions"
  type                 = "CustomScriptForLinux"
  type_handler_version = "1.5"

  settings = jsonencode({
    fileUris = [
      "${var.script_base_url}configureopnsense.sh",
      "${var.script_base_url}config.xml",
      "${var.script_base_url}get_nic_gw.py",
      "${var.script_base_url}actions_waagent.conf"
    ]
  })

  protected_settings = jsonencode({
    commandToExecute = join(" ", [
      "sh configureopnsense.sh",
      var.script_base_url,
      var.opnsense_version,
      var.walinux_version,
      "TwoNics",
      var.subnet_trust_cidr,
      ""
    ])
  })

  tags = var.tags
}
