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

resource "azurerm_user_assigned_identity" "backend" {
  location            = azurerm_resource_group.main.location
  name                = "id-${local.project_name}-backend"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_federated_identity_credential" "backend" {
  name                      = "fed-backend"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.backend.id
  subject                   = "system:serviceaccount:backend:backend-workload"
}

resource "azurerm_role_assignment" "backend_secret_user" {
  principal_id         = azurerm_user_assigned_identity.backend.principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.main.id
}

resource "azurerm_role_assignment" "backend_servicebus_data_owner" {
  principal_id         = azurerm_user_assigned_identity.backend.principal_id
  role_definition_name = "Azure Service Bus Data Owner"
  scope                = azurerm_servicebus_namespace.main.id
}

resource "azurerm_user_assigned_identity" "keda_backend" {
  location            = azurerm_resource_group.main.location
  name                = "id-${local.project_name}-keda-backend"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_federated_identity_credential" "keda_backend" {
  name                      = "fed-keda-backend"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.keda_backend.id
  subject                   = "system:serviceaccount:kube-system:keda-operator"
}

resource "azurerm_role_assignment" "keda_backend_servicebus_data_owner" {
  principal_id         = azurerm_user_assigned_identity.keda_backend.principal_id
  role_definition_name = "Azure Service Bus Data Owner"
  scope                = azurerm_servicebus_namespace.main.id
}

resource "azurerm_user_assigned_identity" "cert_manager" {
  location            = azurerm_resource_group.main.location
  name                = "id-${local.project_name}-cert-manager"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_federated_identity_credential" "cert_manager" {
  name                      = "fed-cert-manager"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.cert_manager.id
  subject                   = "system:serviceaccount:cert-manager:cert-manager"
}

resource "azurerm_role_assignment" "cert_manager_dns_zone_contributor" {
  principal_id         = azurerm_user_assigned_identity.cert_manager.principal_id
  role_definition_name = "DNS Zone Contributor"
  scope                = data.azurerm_dns_zone.dns_zone.id
}
