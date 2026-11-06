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

resource "azurerm_federated_identity_credential" "repo" {
  for_each                  = local.github_repo_ids
  name                      = each.key
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.main.id
  subject                   = "repo:${local.github_org.name}@${local.github_org.id}/${each.key}@${each.value}:ref:refs/heads/main"
}

moved {
  from = azurerm_federated_identity_credential.infra
  to   = azurerm_federated_identity_credential.repo["infra"]
}

moved {
  from = azurerm_federated_identity_credential.frontend
  to   = azurerm_federated_identity_credential.repo["frontend"]
}

moved {
  from = azurerm_federated_identity_credential.backend
  to   = azurerm_federated_identity_credential.repo["backend"]
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

resource "azuread_directory_role" "application_administrator" {
  display_name = "Application Administrator"
}

resource "azuread_directory_role_assignment" "application_administrator" {
  role_id             = azuread_directory_role.application_administrator.template_id
  principal_object_id = azurerm_user_assigned_identity.main.principal_id
}

resource "azuread_directory_role" "directory_readers" {
  display_name = "Directory Readers"
}

resource "azuread_directory_role_assignment" "directory_readers" {
  role_id             = azuread_directory_role.directory_readers.template_id
  principal_object_id = azurerm_user_assigned_identity.main.principal_id
}

resource "github_actions_organization_variable" "client_id" {
  variable_name = "AZURE_CLIENT_ID"
  visibility    = "all"
  value         = azurerm_user_assigned_identity.main.client_id
}

resource "github_actions_organization_variable" "tenant_id" {
  variable_name = "AZURE_TENANT_ID"
  visibility    = "all"
  value         = data.azurerm_client_config.current.tenant_id
}

resource "github_actions_organization_variable" "subscription_id" {
  variable_name = "AZURE_SUBSCRIPTION_ID"
  visibility    = "all"
  value         = data.azurerm_client_config.current.subscription_id
}

resource "github_actions_organization_secret" "gh_app_pem" {
  secret_name = "GH_APP_PEM"
  visibility  = "selected"
  value       = var.github_app_pem
}

resource "github_actions_organization_secret_repositories" "gh_app_pem" {
  secret_name             = github_actions_organization_secret.gh_app_pem.secret_name
  selected_repository_ids = [local.github_repo_ids.infra]
}

# Created by hand: Cloudflare doesn't let a token created via the API manage other tokens (ADR 0018).
resource "github_actions_organization_secret" "cloudflare_api_token" {
  secret_name = "CLOUDFLARE_API_TOKEN"
  visibility  = "selected"
  value       = var.cloudflare_api_token
}

resource "github_actions_organization_secret_repositories" "cloudflare_api_token" {
  secret_name             = github_actions_organization_secret.cloudflare_api_token.secret_name
  selected_repository_ids = [local.github_repo_ids.infra]
}

data "azuread_client_config" "current" {}

resource "azuread_group" "admin" {
  display_name     = "Hien Test Group Admin"
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
  members          = [data.azuread_client_config.current.object_id]
}

resource "azuread_group" "dev" {
  display_name     = "Hien Test Group Dev"
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
}

# Lets build-push in backend/frontend open and merge the deploy PR with GITHUB_TOKEN (ADR 0004).
resource "github_actions_organization_workflow_permissions" "main" {
  organization_slug                = local.github_org.name
  default_workflow_permissions     = "read"
  can_approve_pull_request_reviews = true
}

resource "github_workflow_repository_permissions" "deploy_pr" {
  for_each                         = toset(["backend", "frontend"])
  repository                       = each.key
  default_workflow_permissions     = "read"
  can_approve_pull_request_reviews = true
  depends_on                       = [github_actions_organization_workflow_permissions.main]
}
