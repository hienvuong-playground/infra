terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.4.1"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13.0"
    }
  }

  backend "azurerm" {
    use_azuread_auth     = true
    storage_account_name = "stplaygroundinit"
    key                  = "terraform.tfstate"
    container_name       = "tfstate"
  }
}

provider "azurerm" {
  features {}
}

provider "github" {
  owner = "hienvuong-playground"

  app_auth {
    id              = "4998541"
    installation_id = "162938087"
    pem_file        =  var.github_app_pem
  }
}

data "azurerm_client_config" "current" {}