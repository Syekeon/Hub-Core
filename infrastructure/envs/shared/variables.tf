variable "subscription_id" {
  type = string
}

variable "location" {
  type = string
}

variable "location_short" {
  type = string
}

variable "allowed_locations" {
  type = list(string)
}

variable "workload" {
  type = string
}

variable "environment" {
  type = string
}

variable "environment_short" {
  type = string
}

variable "instance" {
  type = string
}

variable "hub_name" {
  type = string
}

variable "rg_infra_name" {
  type = string
}

variable "hub_vnet_cidr" {
  type = string
}

variable "hub_nva_untrust_subnet_cidr" {
  type = string
}

variable "hub_nva_trust_subnet_cidr" {
  type = string
}

variable "hub_nva_trust_private_ip" {
  type = string
}

variable "opnsense_vm_size" {
  type = string
}

variable "opnsense_admin_username" {
  type = string
}

variable "opnsense_admin_password" {
  type      = string
  sensitive = true
}

variable "tag_owner" {
  type = string
}

variable "tag_cost_center" {
  type = string
}

variable "monitoring_alert_emails" {
  type        = list(string)
  description = "Lista de emails que reciben alertas de la plataforma"
}
