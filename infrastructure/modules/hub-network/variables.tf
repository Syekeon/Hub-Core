variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "hub_vnet_name" { type = string }
variable "hub_vnet_cidr" { type = string }
variable "hub_nva_untrust_subnet_cidr" { type = string }
variable "hub_nva_trust_subnet_cidr" { type = string }
variable "tags" { type = map(string) }
