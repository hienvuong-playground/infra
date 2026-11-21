resource "azurerm_dashboard_grafana" "main" {
  name                  = "amg-${local.project_name}"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  grafana_major_version = "13"

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.main.id
  }
}

resource "azurerm_role_assignment" "managed_grafana_monitoring_reader" {
  principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id
  role_definition_name = "Monitoring Reader"
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

resource "azurerm_role_assignment" "managed_grafana_monitoring_data_reader" {
  principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id
  role_definition_name = "Monitoring Data Reader"
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

resource "azurerm_role_assignment" "managed_grafana_admin_devops" {
  principal_id         = data.azuread_group.devops.object_id
  role_definition_name = "Grafana Admin"
  scope                = azurerm_dashboard_grafana.main.id
}

resource "azurerm_role_assignment" "managed_grafana_admin_terraform" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Grafana Admin"
  scope                = azurerm_dashboard_grafana.main.id
}

data "azuread_group" "dev" {
  display_name = "Hien Test Group Dev"
}

resource "azurerm_role_assignment" "managed_grafana_viewer_dev" {
  principal_id         = data.azuread_group.dev.object_id
  role_definition_name = "Grafana Viewer"
  scope                = azurerm_dashboard_grafana.main.id
}
