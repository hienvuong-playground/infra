resource "azurerm_postgresql_flexible_server" "main" {
  name                          = "psql-${local.project_name}-${random_string.suffix.result}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  version                       = "17"
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  public_network_access_enabled = true

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  # Azure picks the zone when unset
  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "storefront" {
  name      = "storefront"
  server_id = azurerm_postgresql_flexible_server.main.id
}

# 0.0.0.0 = allow Azure services; access is still gated by Entra tokens
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "backend" {
  server_name         = azurerm_postgresql_flexible_server.main.name
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = azurerm_user_assigned_identity.backend.principal_id
  principal_name      = azurerm_user_assigned_identity.backend.name
  principal_type      = "ServicePrincipal"
}

data "azuread_group" "devops" {
  display_name = "DevOps Engineers"
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "devops" {
  server_name         = azurerm_postgresql_flexible_server.main.name
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azuread_group.devops.object_id
  principal_name      = data.azuread_group.devops.display_name
  principal_type      = "Group"
}
