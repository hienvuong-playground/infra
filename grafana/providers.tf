terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.55.0"
    }
  }

  backend "azurerm" {
    key = "grafana.tfstate"
  }
}

# Auth comes from GRAFANA_AUTH: an Entra access token for AMG, fetched in CI (deploy.yml).
provider "grafana" {
  url = data.terraform_remote_state.cloud.outputs.managed_grafana_endpoint
}

data "terraform_remote_state" "cloud" {
  backend = "azurerm"
  config = {
    use_azuread_auth     = true
    storage_account_name = "stplaygroundinit"
    container_name       = "tfstate"
    key                  = "cloud.tfstate"
  }
}
