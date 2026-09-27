resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_workspace" "main" {
  name                = "amw-${local.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${local.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "other"
}

# azurerm's DCR resource has no otel* directDataSources, hence azapi.
# Ported from https://github.com/microsoft/AzureMonitorCommunity/blob/master/Azure%20Services/Azure%20Monitor/OpenTelemetry/OTLP_DCE_DCR_ARM_Template.txt
resource "azapi_resource" "otlp_dce" {
  type      = "Microsoft.Insights/dataCollectionEndpoints@2024-03-11"
  name      = "dce-${local.project_name}-otlp"
  location  = azurerm_resource_group.main.location
  parent_id = azurerm_resource_group.main.id

  body = {
    properties = {
      networkAcls = {
        publicNetworkAccess = "Enabled"
      }
    }
  }
}

resource "azapi_resource" "otlp_dcr" {
  type      = "Microsoft.Insights/dataCollectionRules@2024-03-11"
  name      = "dcr-${local.project_name}-otlp"
  location  = azurerm_resource_group.main.location
  parent_id = azurerm_resource_group.main.id

  body = {
    properties = {
      dataCollectionEndpointId = azapi_resource.otlp_dce.id
      references = {
        applicationInsights = [{
          resourceId = azurerm_application_insights.main.id
          name       = "appi"
        }]
      }
      directDataSources = {
        otelMetrics = [{
          name                         = "otelMetrics"
          streams                      = ["Custom-Metrics-Otel"]
          enrichWithResourceAttributes = ["*"]
          enrichWithReference          = "appi"
        }]
        otelLogs = [{
          name                           = "otelLogs"
          streams                        = ["Microsoft-OTel-Logs"]
          enrichWithResourceAttributes   = ["*"]
          enrichWithReference            = "appi"
          replaceResourceIdWithReference = true
        }]
        otelTraces = [{
          name = "otelTraces"
          streams = [
            "Microsoft-OTel-Traces-Spans",
            "Microsoft-OTel-Traces-Events",
            "Microsoft-OTel-Traces-Resources",
          ]
          enrichWithResourceAttributes   = ["*"]
          enrichWithReference            = "appi"
          replaceResourceIdWithReference = true
        }]
      }
      destinations = {
        monitoringAccounts = [{
          accountResourceId = azurerm_monitor_workspace.main.id
          name              = "amw"
        }]
        logAnalytics = [{
          workspaceResourceId = azurerm_log_analytics_workspace.main.id
          name                = "law"
        }]
      }
      dataFlows = [
        {
          streams      = ["Custom-Metrics-Otel"]
          destinations = ["amw"]
        },
        {
          streams = [
            "Microsoft-OTel-Logs",
            "Microsoft-OTel-Traces-Spans",
            "Microsoft-OTel-Traces-Events",
            "Microsoft-OTel-Traces-Resources",
          ]
          destinations = ["law"]
        },
      ]
    }
  }
}
