resource "azurerm_user_assigned_identity" "k8s" {
  location            = azurerm_resource_group.main.location
  name                = "id-${local.project_name}-k8s"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_federated_identity_credential" "k8s" {
  name                      = "k8s"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.k8s.id
  subject                   = "repo:hienvuong-playground@325346053/k8s@1378931138:ref:refs/heads/main"
}

resource "azurerm_role_assignment" "k8s_rbac_cluster_admin" {
  principal_id         = azurerm_user_assigned_identity.k8s.principal_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = azurerm_kubernetes_cluster.main.id
}

# To allow write on flux extensions, too lazy to create custom role
resource "azurerm_role_assignment" "k8s_contributor" {
  principal_id         = azurerm_user_assigned_identity.k8s.principal_id
  role_definition_name = "Contributor"
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}
