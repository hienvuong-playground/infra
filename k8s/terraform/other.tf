data "terraform_remote_state" "cloud" {
  backend = "azurerm"
  config = {
    use_azuread_auth     = true
    storage_account_name = "stplaygroundinit"
    container_name       = "tfstate"
    key                  = "cloud.tfstate"
  }
}

data "azuread_group" "grafana_admins" {
  display_name = "DevOps Engineers"
}

data "azuread_group" "grafana_developers" {
  display_name = "CL Playground"
}
