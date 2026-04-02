variable "name" { type = string }
variable "target_resource_id" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "log_category_groups" {
  type    = list(string)
  default = ["allLogs"]
}
variable "log_categories" {
  type    = list(string)
  default = []
}
variable "metric_categories" {
  type    = list(string)
  default = ["AllMetrics"]
}
