module "governance" {
  source      = "../../modules/governance"
  workload    = var.workload
  environment = var.environment
  location    = var.location
  instance    = var.instance
  owner       = var.tag_owner
  cost_center = var.tag_cost_center
}

locals {
  hub_tags = {
    project     = module.governance.tags.project
    environment = "shared"
    owner       = module.governance.tags.owner
    cost_center = module.governance.tags.cost_center
  }
}

module "naming" {
  source      = "../../modules/naming"
  workload    = var.workload
  environment = var.environment
  location    = var.location
  instance    = var.instance
  hub_name    = var.hub_name
}

module "resource_groups" {
  source      = "../../modules/resource-groups"
  rg_name     = var.rg_infra_name
  location    = var.location
  tags        = local.hub_tags
}

module "observability" {
  source              = "../../modules/observability"
  resource_group_name = module.resource_groups.resource_group_name
  location            = var.location
  tags                = local.hub_tags
  names = {
    log_analytics = module.naming.hub_log_analytics_name
    app_insights  = module.naming.hub_application_insights_name
  }
}

module "hub_network" {
  source                        = "../../modules/hub-network"
  resource_group_name           = module.resource_groups.resource_group_name
  location                      = var.location
  hub_vnet_name                 = module.naming.hub_vnet_name
  hub_vnet_cidr                 = var.hub_vnet_cidr
  hub_nva_untrust_subnet_cidr   = var.hub_nva_untrust_subnet_cidr
  hub_nva_trust_subnet_cidr     = var.hub_nva_trust_subnet_cidr
  tags                          = local.hub_tags
}

module "private_dns" {
  source                   = "../../modules/private-dns"
  resource_group_name      = module.resource_groups.resource_group_name
  location                 = var.location
  hub_vnet_id              = module.hub_network.hub_vnet_id
  tags                     = local.hub_tags
}

module "nva_opnsense" {
  source              = "../../modules/nva-opnsense"
  location            = var.location
  resource_group_name = module.resource_groups.resource_group_name
  subnet_untrust_id   = module.hub_network.nva_untrust_subnet_id
  subnet_trust_id     = module.hub_network.nva_trust_subnet_id
  subnet_trust_cidr   = var.hub_nva_trust_subnet_cidr
  trust_private_ip    = var.hub_nva_trust_private_ip
  vm_size             = var.opnsense_vm_size
  admin_username      = var.opnsense_admin_username
  admin_password      = var.opnsense_admin_password
  ssh_public_key_path = null
  public_ip_name      = "${var.hub_name}-pip-nva"
  nsg_name            = "${var.hub_name}-nsg-nva-untrust"
  nic_untrust_name    = "${var.hub_name}-nic-nva-untrust"
  nic_trust_name      = "${var.hub_name}-nic-nva-trust"
  vm_name             = module.naming.nva_name
  os_disk_name        = "${var.hub_name}-disk-nva-os"
  tags                = local.hub_tags
}

module "diag_hub_vnet" {
  source                     = "../../modules/diagnostic-settings"
  name                       = "diag-hub-vnet-to-law"
  target_resource_id         = module.hub_network.hub_vnet_id
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
}

module "diag_nsg_untrust" {
  source                     = "../../modules/diagnostic-settings"
  name                       = "diag-nsg-untrust-to-law"
  target_resource_id         = module.nva_opnsense.untrust_nsg_id
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  metric_categories          = []
}

module "diag_public_ip_nva" {
  source                     = "../../modules/diagnostic-settings"
  name                       = "diag-public-ip-to-law"
  target_resource_id         = module.nva_opnsense.public_ip_id
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
}

module "policy_audit" {
  source              = "../../modules/policy-audit"
  subscription_id     = "/subscriptions/${var.subscription_id}"
  allowed_locations   = var.allowed_locations
  required_tags       = keys(module.governance.tags)
}

module "policy_require_tags_hub" {
  source        = "../../modules/policy-require-tags"
  scope_id      = module.resource_groups.resource_group_id
  required_tags = ["owner", "cost_center", "project", "environment"]
}
