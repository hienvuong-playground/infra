data "azuread_application" "grafana" {
  display_name = "app-${local.project_name}-grafana"
}

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

data "azurerm_user_assigned_identity" "cert_manager" {
  name                = "id-${local.project_name}-cert-manager"
  resource_group_name = "rg-${local.project_name}"
}

data "azurerm_public_ip" "gateway" {
  name                = "pip-${local.project_name}-gateway"
  resource_group_name = "rg-${local.project_name}"
}

data "azurerm_resource_group" "manual" {
  name = "rg-${local.project_name}-manual"
}

data "azurerm_dns_zone" "dns_zone" {
  name                = "playground.hienvuong.com"
  resource_group_name = data.azurerm_resource_group.manual.name
}

data "azurerm_user_assigned_identity" "loki" {
  name                = "id-${local.project_name}-loki"
  resource_group_name = "rg-${local.project_name}"
}

data "azurerm_user_assigned_identity" "tempo" {
  name                = "id-${local.project_name}-tempo"
  resource_group_name = "rg-${local.project_name}"
}

data "azurerm_user_assigned_identity" "thanos" {
  name                = "id-${local.project_name}-thanos"
  resource_group_name = "rg-${local.project_name}"
}

data "azurerm_storage_account" "observability" {
  name                = "st${local.project_name}obs"
  resource_group_name = "rg-${local.project_name}"
}
data "azurerm_user_assigned_identity" "otel_collector" {
  name                = "id-${local.project_name}-otel-collector"
  resource_group_name = "rg-${local.project_name}"
}

data "azurerm_resource_group" "main" {
  name = "rg-${local.project_name}"
}

data "azapi_resource" "otlp_dce" {
  type                   = "Microsoft.Insights/dataCollectionEndpoints@2024-03-11"
  name                   = "dce-${local.project_name}-otlp"
  parent_id              = data.azurerm_resource_group.main.id
  response_export_values = ["properties.logsIngestion.endpoint", "properties.metricsIngestion.endpoint"]
}

data "azapi_resource" "otlp_dcr" {
  type                   = "Microsoft.Insights/dataCollectionRules@2024-03-11"
  name                   = "dcr-${local.project_name}-otlp"
  parent_id              = data.azurerm_resource_group.main.id
  response_export_values = ["properties.immutableId"]
}
