
resource "azurerm_user_assigned_identity" "otel_collector" {
  location            = azurerm_resource_group.main.location
  name                = "id-${local.project_name}-otel-collector"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_federated_identity_credential" "otel_collector" {
  name                      = "fed-otel-collector"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.otel_collector.id
  subject                   = "system:serviceaccount:observability:otel-collector"
}

resource "azurerm_role_assignment" "otel_collector_dcr_metrics_publisher" {
  principal_id         = azurerm_user_assigned_identity.otel_collector.principal_id
  role_definition_name = "Monitoring Metrics Publisher"
  scope                = azapi_resource.otlp_dcr.id
}
