output "assignment_ids" {
  value = { for k, v in azurerm_resource_group_policy_assignment.required_tags : k => v.id }
}
