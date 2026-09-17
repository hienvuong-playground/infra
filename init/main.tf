resource "azurerm_resource_group" "main" {
  name     = "rg-${local.project_name}"
  location = local.region
  tags = {
    CREATED_BY = "Hien Vuong"
  }
}

resource "azurerm_storage_account" "main" {
  name                      = "st${local.project_name_no_dash}"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = local.region
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  shared_access_key_enabled = false
}

resource "azurerm_storage_container" "main" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_user_assigned_identity" "main" {
  location            = azurerm_resource_group.main.location
  name                = "id-${local.project_name}"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_federated_identity_credential" "infra" {
  name                      = "infra"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.main.id
  subject                   = "repo:hienvuong-playground@325346053/infra@1358361523:ref:refs/heads/main"
}

resource "azurerm_federated_identity_credential" "frontend" {
  name                      = "frontend"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.main.id
  subject                   = "repo:hienvuong-playground@325346053/frontend@1358357400:ref:refs/heads/main"
}

resource "azurerm_role_assignment" "owner" {
  principal_id         = azurerm_user_assigned_identity.main.principal_id
  role_definition_name = "Owner"
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  principal_id         = azurerm_user_assigned_identity.main.principal_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = azurerm_storage_account.main.id
}

resource "github_actions_organization_variable" "client_id" {
  variable_name = "AZURE_CLIENT_ID"
  visibility    = "all"
  value         = "${azurerm_user_assigned_identity.main.client_id}"
}

resource "github_actions_organization_variable" "tenant_id" {
  variable_name = "AZURE_TENANT_ID"
  visibility    = "all"
  value         = "${data.azurerm_client_config.current.tenant_id}"
}

resource "github_actions_organization_variable" "subscription_id" {
  variable_name = "AZURE_SUBSCRIPTION_ID"
  visibility    = "all"
  value         = "${data.azurerm_client_config.current.subscription_id}"
}
