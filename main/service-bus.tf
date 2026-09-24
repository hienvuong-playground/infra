resource "azurerm_servicebus_namespace" "main" {
  name                = "sb-${local.project_name}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Basic"
}

resource "azurerm_user_assigned_identity" "keda" {
  location            = azurerm_resource_group.main.location
  name                = "id-${local.project_name}-keda"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_federated_identity_credential" "keda" {
  name                      = "fed-keda"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.keda.id
  subject                   = "system:serviceaccount:kube-system:keda-operator"
}

# Temp to test only
resource "azurerm_federated_identity_credential" "temp" {
  name                      = "fed-temp"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.keda.id
  subject                   = "system:serviceaccount:default:temp"
}

resource "azurerm_role_assignment" "keda_servicebus_data_owner" {
  principal_id         = azurerm_user_assigned_identity.keda.principal_id
  role_definition_name = "Azure Service Bus Data Owner"
  scope                = azurerm_servicebus_namespace.main.id
}