resource "azurerm_static_web_app" "main" {
  name                = "stapp-${local.project_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = "East Asia"
}
