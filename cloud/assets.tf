# Public content images. Blob names are content hashes, so a blob never changes
# in place and can be cached as immutable; see general/adr/0006.
locals {
  asset_content_types = {
    jpg  = "image/jpeg"
    png  = "image/png"
    webp = "image/webp"
  }
}

resource "azurerm_storage_account" "assets" {
  name                            = "st${local.project_name}assets"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = true
}

resource "azurerm_storage_container" "assets" {
  name                  = "assets"
  storage_account_id    = azurerm_storage_account.assets.id
  container_access_type = "blob"
}

resource "azurerm_role_assignment" "current_user_assets_blob_contributor" {
  scope                = azurerm_storage_container.assets.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_blob" "assets" {
  for_each = fileset("${path.module}/assets", "*")

  name                 = "images/${substr(filesha256("${path.module}/assets/${each.value}"), 0, 12)}.${split(".", each.value)[1]}"
  storage_container_id = azurerm_storage_container.assets.id
  type                 = "Block"
  source               = "${path.module}/assets/${each.value}"
  content_type         = local.asset_content_types[split(".", each.value)[1]]
  cache_control        = "public, max-age=31536000, immutable"

  depends_on = [azurerm_role_assignment.current_user_assets_blob_contributor]
}
