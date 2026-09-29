resource "azuread_application" "grafana" {
  display_name     = "app-${local.project_name}-grafana"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azurerm_client_config.current.object_id]

  web {
    redirect_uris = ["https://grafana.${data.azurerm_dns_zone.dns_zone.name}/oauth2/callback"]
  }
}

resource "azuread_service_principal" "grafana" {
  client_id = azuread_application.grafana.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "grafana_oauth2_proxy" {
  application_id = azuread_application.grafana.id
  display_name   = "fed-grafana-oauth2-proxy"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject        = "system:serviceaccount:observability:grafana-oauth2-proxy"
}

resource "random_password" "grafana_oauth2_proxy_cookie_secret" {
  length           = 32
  override_special = "-_"
}

resource "azurerm_key_vault_secret" "grafana_oauth2_proxy_cookie_secret" {
  name         = "grafana-oauth2-proxy-cookie-secret"
  value        = random_password.grafana_oauth2_proxy_cookie_secret.result
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.current_user_kv_admin]
}

resource "azurerm_role_assignment" "grafana_oauth2_proxy_cookie_secret_user" {
  principal_id         = azuread_service_principal.grafana.object_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault_secret.grafana_oauth2_proxy_cookie_secret.resource_versionless_id
}
