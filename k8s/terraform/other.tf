data "azurerm_user_assigned_identity" "keda_backend" {
  name                = "id-${local.project_name}-keda-backend"
  resource_group_name = "rg-${local.project_name}"
}

data "azurerm_servicebus_namespace" "main" {
  name                = "sbns-playground-gw2y5h"
  resource_group_name = "rg-${local.project_name}"
}

data "azurerm_servicebus_queue" "example" {
  name         = "sbq-${local.project_name}"
  namespace_id = data.azurerm_servicebus_namespace.main.id
}

data "azurerm_user_assigned_identity" "backend" {
  name                = "id-${local.project_name}-backend"
  resource_group_name = "rg-${local.project_name}"
}
