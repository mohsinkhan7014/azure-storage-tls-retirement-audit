variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}





variable "tenant_id" {
  type        = string
  description = "Azure tenant ID"
  sensitive   = true
}

variable "client_id" {
  type        = string
  description = "Azure client ID"
  sensitive   = true
}

variable "client_secret" {
  type        = string
  description = "Azure client secret"
  sensitive   = true
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  
}

variable "location" {
  description = "Location of the rg"
  type = string
}