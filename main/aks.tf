resource "azurerm_kubernetes_cluster" "main" {
  name                      = "aks-${local.project_name}"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  dns_prefix                = local.project_name
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled = false
  }

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "standard_d2als_v7"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  node_provisioning_profile {
    default_node_pools = "Auto"
    mode               = "Manual"
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  local_account_disabled = true
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# resource "azurerm_role_assignment" "aks_csi_secrets_user" {
#   scope                = azurerm_key_vault.main.id
#   role_definition_name = "Key Vault Secrets User"
#   # This is the managed identity automatically created by the AKS Key Vault CSI addon.
#   principal_id = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id
# }
