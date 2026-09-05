resource "azurerm_resource_group" "main" {
  name     = "rg-${local.project_name}"
  location = local.region
}