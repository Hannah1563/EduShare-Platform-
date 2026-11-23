# Pin Terraform and provider versions so every teammate (and CI) gets the same behaviour.
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state in Azure Storage, so every teammate and the pipeline see the
  # same infrastructure. Settings live in backend.hcl:
  #   terraform init -backend-config=backend.hcl
  backend "azurerm" {}
}

# Credentials come from environment variables, never from code:
#   ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
provider "azurerm" {
  features {}

  # The service principal is Contributor on one resource group only, so it
  # cannot register resource providers for the whole subscription. The
  # subscription owner registers them once instead (see README).
  resource_provider_registrations = "none"
}
