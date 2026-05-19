variable "environment" {
  type        = string
  description = "Nombre del entorno (staging, prod)"
}

variable "location" {
  type        = string
  description = "Región de Azure"
}

variable "hub_resource_group_name" {
  type        = string
  description = "Resource group del hub"
}

variable "subscription_id" {
  type        = string
  description = "ID de la suscripción de Azure"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "ID del Log Analytics Workspace"
}

variable "nva_vm_name" {
  type        = string
  description = "Nombre de la VM OPNsense NVA"
  default     = "hub-vm-nva"
}

variable "hub_vnet_id" {
  type        = string
  description = "ID del Hub VNet"
}

variable "alert_emails" {
  type        = list(string)
  description = "Lista de emails que reciben alertas"
}

variable "action_group_name" {
  type        = string
  description = "Nombre del action group"
  default     = "ag-platform-alerts"
}

variable "tags" {
  type        = map(string)
  description = "Tags comunes"
}
