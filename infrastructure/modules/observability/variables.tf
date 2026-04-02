variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

variable "names" {
  type = object({
    log_analytics = string
    app_insights  = string
  })
}
