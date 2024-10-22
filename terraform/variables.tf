variable "workload_name" {
  description = "Name of the workload which is used to generate a short unique hash used in all resources."
  type        = string
  validation {
    condition     = length(var.workload_name) >= 1 && length(var.workload_name) <= 64
    error_message = "Workload name must be between 1 and 64 characters."
  }
}

variable "location" {
  description = "Primary location for all resources."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group. If empty, a unique name will be generated."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags for all resources."
  type        = map(string)
  default     = {}
}

variable "managed_identity_name" {
  description = "Name of the Managed Identity. If empty, a unique name will be generated."
  type        = string
  default     = ""
}

variable "openai_instances" {
  description = "OpenAI instances to deploy."
  type = list(object({
    name     = optional(string)
    location = string
    suffix   = string
  }))
  default = [
    {
      name     = ""
      location = "uksouth"
      suffix   = "uks"
    },
    {
      name     = ""
      location = "westus"
      suffix   = "wus"
    }
  ]

  validation {
    condition = alltrue([
      for instance in var.openai_instances :
      contains([
        "westus", "eastus", "westeurope", "southcentralus",
        "westus2", "australiaeast", "eastus2", "eastasia",
        "westus3", "swedencentral", "francecentral", "uksouth"
      ], instance.location)
    ])
    error_message = "Location must be a valid Azure region that supports OpenAI services."
  }

  validation {
    condition = alltrue([
      for instance in var.openai_instances :
      can(regex("^[a-z]{2,5}$", instance.suffix))
    ])
    error_message = "Suffix must be 2-5 lowercase letters."
  }
}

variable "openai_deployments" {
  description = "OpenAI model deployments configuration"
  type = list(object({
    name = string
    model = object({
      format  = string
      name    = string
      version = string
    })
    sku = object({
      name     = string
      capacity = number
    })
  }))
  default = [
    {
      name = "gpt-35-turbo"
      model = {
        format  = "OpenAI"
        name    = "gpt-35-turbo"
        version = "1106"
      }
      sku = {
        name     = "Standard"
        capacity = 1
      }
    },
    {
      name = "text-embedding-ada-002"
      model = {
        format  = "OpenAI"
        name    = "text-embedding-ada-002"
        version = "2"
      }
      sku = {
        name     = "Standard"
        capacity = 1
      }
    }
  ]
  validation {
    condition = alltrue([
      for deployment in var.openai_deployments :
      can(regex("^[a-zA-Z0-9-]+$", deployment.name)) &&
      length(deployment.name) <= 64 &&
      length(deployment.name) > 0
    ])
    error_message = "Deployment name must be 1-64 characters long and can only contain alphanumeric characters and hyphens."
  }

  validation {
    condition = alltrue([
      for deployment in var.openai_deployments :
      contains(["OpenAI"], deployment.model.format)
    ])
    error_message = "Model format must be 'OpenAI'."
  }

  validation {
    condition = alltrue([
      for deployment in var.openai_deployments :
      contains(["gpt-35-turbo", "text-embedding-ada-002"], deployment.model.name)
    ])
    error_message = "Model name must be either 'gpt-35-turbo' or 'text-embedding-ada-002'."
  }

  validation {
    condition = alltrue([
      for deployment in var.openai_deployments :
      deployment.model.name == "gpt-35-turbo" ? contains(["1106"], deployment.model.version) :
      deployment.model.name == "text-embedding-ada-002" ? contains(["2"], deployment.model.version) :
      false
    ])
    error_message = "Invalid model version. For gpt-35-turbo use '1106', for text-embedding-ada-002 use '2'."
  }

  validation {
    condition = alltrue([
      for deployment in var.openai_deployments :
      contains(["Standard"], deployment.sku.name)
    ])
    error_message = "SKU name must be 'Standard'."
  }

  validation {
    condition = alltrue([
      for deployment in var.openai_deployments :
      deployment.sku.capacity >= 1 && deployment.sku.capacity <= 120
    ])
    error_message = "SKU capacity must be between 1 and 120."
  }
}

variable "api_management_name" {
  description = "Name of the API Management service. If empty, a unique name will be generated."
  type        = string
  default     = ""
}

variable "api_management_publisher_email" {
  description = "Email address for the API Management service publisher."
  type        = string
}

variable "api_management_publisher_name" {
  description = "Name of the API Management service publisher."
  type        = string
}
