# Pin Terraform and provider versions so every teammate (and CI) gets the same behaviour.
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# The azurerm v4 provider needs a subscription ID. We read it from the
# ARM_SUBSCRIPTION_ID environment variable instead of hardcoding it:
#   export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
provider "azurerm" {
  features {
    resource_group {
      # Let `terraform destroy` remove the group even if Azure added
      # helper resources to it (e.g. NetworkWatcher).
      prevent_deletion_if_contains_resources = false
    }
  }
}
