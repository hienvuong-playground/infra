data "azurerm_resource_group" "rg_manual" {
  name = "rg-${local.project_name}-manual"
}

data "azurerm_dns_zone" "dns_zone" {
  name                = "playground.hienvuong.com"
  resource_group_name = data.azurerm_resource_group.rg_manual.name
}
