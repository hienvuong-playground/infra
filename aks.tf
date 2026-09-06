resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${local.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = local.project_name

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "standard_d2als_v7"
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
output "kube_config" {
  value     = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}
