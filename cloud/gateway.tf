resource "azurerm_public_ip" "gateway" {
  name                = "pip-${local.project_name}-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# AKS control plane must be able to attach a PIP that lives outside the node resource group
resource "azurerm_role_assignment" "aks_gateway_pip" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

resource "azurerm_dns_a_record" "wildcard" {
  name                = "*"
  zone_name           = data.azurerm_dns_zone.dns_zone.name
  resource_group_name = data.azurerm_resource_group.rg_manual.name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.gateway.id
}
