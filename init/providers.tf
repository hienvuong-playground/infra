terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0.1"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0.1"
    }
  }
  backend "local" {
  }
}

provider "azurerm" {
  features {}
}

provider "github" {
  token = var.github_token
  owner = local.github_org.name
}

data "azurerm_client_config" "current" {}