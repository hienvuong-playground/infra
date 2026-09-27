# Shared blob storage for observability backends (Loki logs, Tempo traces).
# Containers are prefixed per tool so each identity can be scoped to its own.
resource "azurerm_storage_account" "observability" {
  name                      = "st${local.project_name}obs"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  shared_access_key_enabled = false
}

resource "azurerm_storage_container" "loki_chunks" {
  name               = "loki-chunks"
  storage_account_id = azurerm_storage_account.observability.id
}

resource "azurerm_storage_container" "loki_ruler" {
  name               = "loki-ruler"
  storage_account_id = azurerm_storage_account.observability.id
}

resource "azurerm_storage_container" "tempo_traces" {
  name               = "tempo-traces"
  storage_account_id = azurerm_storage_account.observability.id
}
