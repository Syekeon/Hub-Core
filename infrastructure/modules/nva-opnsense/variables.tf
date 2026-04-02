variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_untrust_id" {
  type = string
}

variable "subnet_trust_id" {
  type = string
}

variable "subnet_trust_cidr" {
  type = string
}

variable "trust_private_ip" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "ssh_public_key_path" {
  type    = string
  default = null
}

variable "script_base_url" {
  type    = string
  default = "https://raw.githubusercontent.com/dmauser/opnazure/master/scripts/"
}

variable "opnsense_version" {
  type    = string
  default = "25.1"
}

variable "walinux_version" {
  type    = string
  default = "2.12.0.4"
}

variable "public_ip_name" {
  type = string
}

variable "nsg_name" {
  type = string
}

variable "nic_untrust_name" {
  type = string
}

variable "nic_trust_name" {
  type = string
}

variable "vm_name" {
  type = string
}

variable "os_disk_name" {
  type = string
}

variable "tags" {
  type = map(string)
}
