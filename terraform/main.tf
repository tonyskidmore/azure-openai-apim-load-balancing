terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "random" {
  # Configuration options
}

data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

data "azurerm_role_definition" "cognitive_services_openai_user" {
  role_definition_id = local.roles.cognitiveServicesOpenAIUser
  scope              = data.azurerm_subscription.current.id
}

resource "random_string" "token" {
  length  = 13
  special = false
  upper   = false
  lower   = true
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_user_assigned_identity" "main" {
  name                = local.managed_identity_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

resource "azurerm_cognitive_account" "openai" {
  for_each = { for instance in var.openai_instances : instance.suffix => instance }

  name                = local.openai_names[each.key]
  location            = each.value.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "OpenAI"

  sku_name = "S0"

  custom_subdomain_name = lower(local.openai_names[each.key])
  tags                  = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  timeouts {
    create = "2h"
    update = "2h"
    read   = "30m"
    delete = "2h"
  }
}

resource "azurerm_cognitive_deployment" "openai" {
  for_each = {
    for config in flatten([
      for instance in var.openai_instances : [
        for deployment in var.openai_deployments : {
          instance_suffix = instance.suffix
          model_name      = deployment.name
          model           = deployment.model
          sku             = deployment.sku
        }
      ]
    ]) : "${config.instance_suffix}-${config.model_name}" => config
  }

  name                 = each.value.model_name
  cognitive_account_id = azurerm_cognitive_account.openai[each.value.instance_suffix].id

  model {
    format  = each.value.model.format
    name    = each.value.model.name
    version = each.value.model.version
  }

  scale {
    type     = each.value.sku.name
    capacity = each.value.sku.capacity
  }

  timeouts {
    create = "2h"
    update = "2h"
    read   = "30m"
    delete = "2h"
  }
}

resource "azurerm_api_management" "main" {
  name                = local.api_management_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = var.api_management_publisher_name
  publisher_email     = var.api_management_publisher_email

  sku_name = "Developer_1"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  tags = var.tags

  timeouts {
    create = "3h"
    update = "2h"
    read   = "30m"
    delete = "3h"
  }
}

resource "azurerm_api_management_named_value" "managed_identity" {
  name                = "MANAGED-IDENTITY-CLIENT-ID"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  display_name        = "MANAGED-IDENTITY-CLIENT-ID"
  value               = azurerm_user_assigned_identity.main.client_id
}

resource "azurerm_api_management_api" "openai" {
  name                = "openai"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "OpenAI"
  path                = "openai"
  protocols           = ["https"]

  import {
    content_format = "openapi-link"
    content_value  = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview/2024-03-01-preview/inference.json"
  }
}

resource "azurerm_api_management_subscription" "openai" {
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  display_name        = "OpenAI API Subscription"
  state               = "active"
  api_id              = azurerm_api_management_api.openai.id
}

resource "azurerm_api_management_backend" "openai" {
  for_each = { for instance in var.openai_instances : instance.suffix => instance }

  name                = "OPENAI${upper(each.key)}"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = azurerm_cognitive_account.openai[each.key].endpoint
}

resource "azurerm_api_management_api_policy" "load_balancing" {
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  xml_content = file("${path.module}/policies/round-robin-policy.xml")
}

resource "azurerm_role_assignment" "openai_cognitive_services" {
  for_each = { for instance in var.openai_instances : instance.suffix => instance }

  scope              = azurerm_cognitive_account.openai[each.key].id
  role_definition_id = data.azurerm_role_definition.cognitive_services_openai_user.id
  principal_id       = azurerm_user_assigned_identity.main.principal_id
}
