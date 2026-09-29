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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2.1"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10.0"
    }
  }

  backend "azurerm" {
    key = "k8s.tfstate"
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

provider "azuread" {}

provider "github" {
  owner = "hienvuong-playground"

  app_auth {
    id              = "4998541"
    installation_id = "162938087"
    pem_file        = var.github_app_pem
  }
}

data "azurerm_client_config" "current" {}