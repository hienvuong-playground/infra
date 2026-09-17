resource "azurerm_static_web_app" "main" {
  name                = "stapp-${local.project_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.region

  lifecycle {
    ignore_changes = [
      repository_url,
      repository_branch,
    ]
  }
}
