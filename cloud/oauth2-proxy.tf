locals {
  oauth2_proxy_hosts = ["flux"]
}

resource "azuread_application" "oauth2_proxy" {
  display_name     = "app-${local.project_name}-oauth2-proxy"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azurerm_client_config.current.object_id]

  web {
    redirect_uris = [for host in local.oauth2_proxy_hosts : "https://${host}.${data.azurerm_dns_zone.dns_zone.name}/oauth2/callback"]
  }
}

resource "azuread_service_principal" "oauth2_proxy" {
  client_id = azuread_application.oauth2_proxy.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "oauth2_proxy" {
  application_id = azuread_application.oauth2_proxy.id
  display_name   = "fed-oauth2-proxy"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject        = "system:serviceaccount:oauth2-proxy:oauth2-proxy"
}

ephemeral "random_password" "oauth2_proxy_cookie_secret" {
  length           = 32
  override_special = "-_"
}

resource "azurerm_key_vault_secret" "oauth2_proxy_cookie_secret" {
  name             = "oauth2-proxy-cookie-secret"
  value_wo         = ephemeral.random_password.oauth2_proxy_cookie_secret.result
  value_wo_version = 1
  key_vault_id     = azurerm_key_vault.main.id
  depends_on       = [azurerm_role_assignment.current_user_kv_admin]
}

resource "azurerm_role_assignment" "oauth2_proxy_cookie_secret_user" {
  principal_id         = azuread_service_principal.oauth2_proxy.object_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault_secret.oauth2_proxy_cookie_secret.resource_versionless_id
}
