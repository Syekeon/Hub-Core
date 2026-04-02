resource "azurerm_resource_group_policy_assignment" "required_tags" {
  for_each             = toset(var.required_tags)
  name                 = "audit-tag-${replace(each.value, "_", "-")}"
  resource_group_id    = var.scope_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  display_name         = "Audit required tag ${each.value}"

  parameters = jsonencode({
    tagName = {
      value = each.value
    }
  })
}
