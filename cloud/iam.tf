resource "azurerm_role_assignment" "hien_external_aks_rbac_cluster_admin" {
  principal_id         = "1089f4cb-a8ca-41ab-9bda-684ca1dea96f"
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

resource "azurerm_role_assignment" "hien_external_reader" {
  principal_id         = "1089f4cb-a8ca-41ab-9bda-684ca1dea96f"
  role_definition_name = "Reader"
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}
