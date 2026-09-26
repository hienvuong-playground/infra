resource "azurerm_resource_group" "main" {
  name     = "rg-${local.project_name}"
  location = local.region
  tags = {
    CREATED_BY = "Hien Vuong"
  }
}