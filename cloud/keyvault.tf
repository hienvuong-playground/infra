resource "azurerm_key_vault" "main" {
  name                          = "kv-${local.project_name}-${random_string.suffix.result}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
  public_network_access_enabled = true
  rbac_authorization_enabled    = true
}

resource "azurerm_role_assignment" "current_user_kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

locals {
  # secret name => principal allowed to read it
  secrets = {
    "my-secret"   = azurerm_user_assigned_identity.backend.principal_id
    "my-secret-2" = azurerm_user_assigned_identity.backend.principal_id
  }
}

# Real value is set manually in the portal; Terraform never reads it back.
resource "azurerm_key_vault_secret" "manual" {
  for_each         = local.secrets
  name             = each.key
  value_wo         = "changeme"
  value_wo_version = 1
  key_vault_id     = azurerm_key_vault.main.id
  depends_on       = [azurerm_role_assignment.current_user_kv_admin]
}

resource "azurerm_role_assignment" "secret_user" {
  for_each             = local.secrets
  principal_id         = each.value
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault_secret.manual[each.key].resource_versionless_id
}
