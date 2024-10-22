locals {

  resource_group_name   = var.resource_group_name != "" ? var.resource_group_name : "${local.abbreviations.resourceGroup}${var.workload_name}"
  managed_identity_name = var.managed_identity_name != "" ? var.managed_identity_name : "${local.abbreviations.managedIdentity}${random_string.token.result}"
  api_management_name   = var.api_management_name != "" ? var.api_management_name : "${local.abbreviations.apiManagementService}${random_string.token.result}"

  openai_names = {
    for instance in var.openai_instances :
    instance.suffix => instance.name != "" ? instance.name : "${local.abbreviations.openAIService}${random_string.token.result}-${instance.suffix}"
  }

  abbreviations = jsondecode(file("${path.module}/abbreviations.json"))
  roles         = jsondecode(file("${path.module}/roles.json"))
}
