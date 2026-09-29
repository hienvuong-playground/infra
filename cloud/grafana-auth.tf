resource "azuread_application" "grafana" {
  display_name            = "app-${local.project_name}-grafana"
  sign_in_audience        = "AzureADMyOrg"
  owners                  = [data.azurerm_client_config.current.object_id]
  group_membership_claims = ["SecurityGroup"]

  web {
    redirect_uris = ["https://grafana.${data.azurerm_dns_zone.dns_zone.name}/login/azuread"]
  }
}

resource "azuread_service_principal" "grafana" {
  client_id = azuread_application.grafana.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "grafana" {
  application_id = azuread_application.grafana.id
  display_name   = "fed-grafana"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject        = "system:serviceaccount:observability:observability-grafana"
}
