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
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.main.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.main.kube_config_raw

  sensitive = true
}
