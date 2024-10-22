output "resource_group_info" {
  value = {
    id       = azurerm_resource_group.main.id
    name     = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
  }
}

output "managed_identity_info" {
  value = {
    id           = azurerm_user_assigned_identity.main.id
    name         = azurerm_user_assigned_identity.main.name
    principal_id = azurerm_user_assigned_identity.main.principal_id
    client_id    = azurerm_user_assigned_identity.main.client_id
  }
}

output "openai_info" {
  value = [
    for instance in var.openai_instances : {
      id       = azurerm_cognitive_account.openai[instance.suffix].id
      name     = azurerm_cognitive_account.openai[instance.suffix].name
      endpoint = azurerm_cognitive_account.openai[instance.suffix].endpoint
      location = instance.location
      suffix   = instance.suffix
    }
  ]
}

output "api_management_info" {
  value = {
    id              = azurerm_api_management.main.id
    name            = azurerm_api_management.main.name
    gateway_url     = azurerm_api_management.main.gateway_url
    subscription_id = azurerm_api_management_subscription.openai.id
  }
}
