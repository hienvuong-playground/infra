terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0.1"
    }
  }

  backend "azurerm" {
    use_azuread_auth     = true
    storage_account_name = "stplaygroundterraform"
    key                  = "terraform.tfstate"
    container_name       = "tfstate"
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}