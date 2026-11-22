# Action group -> Logic App -> Teams Workflows webhook (note 0031).
# The webhook only accepts Adaptive Card / MessageCard payloads, so the Logic App reshapes the common alert schema.

# Own vault: Microsoft recommends one vault per application with roles at vault scope, not per secret.
resource "azurerm_key_vault" "alerts" {
  name                          = "kv-alerts-${random_string.suffix.result}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
  public_network_access_enabled = true
  rbac_authorization_enabled    = true
}

resource "azurerm_role_assignment" "alerts_kv_terraform" {
  scope                = azurerm_key_vault.alerts.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Write-only: the URL stays out of state. Bump the version after changing the URL, Terraform can't see the change.
resource "azurerm_key_vault_secret" "teams_alerts_webhook_url" {
  name             = "teams-alerts-webhook-url"
  value_wo         = var.teams_alerts_webhook_url
  value_wo_version = 1
  key_vault_id     = azurerm_key_vault.alerts.id
  depends_on       = [azurerm_role_assignment.alerts_kv_terraform]
}

resource "azurerm_logic_app_workflow" "teams_alerts" {
  name                = "logic-${local.project_name}-teams-alerts"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "alerts_kv_logic_app" {
  scope                = azurerm_key_vault.alerts.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_logic_app_workflow.teams_alerts.identity[0].principal_id
}

# Schema copied from https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-logic-apps#set-up-a-trigger
resource "azurerm_logic_app_trigger_http_request" "teams_alerts" {
  name         = "alert"
  logic_app_id = azurerm_logic_app_workflow.teams_alerts.id

  schema = jsonencode({
    type = "object"
    properties = {
      schemaId = { type = "string" }
      data = {
        type = "object"
        properties = {
          essentials = {
            type = "object"
            properties = {
              alertId             = { type = "string" }
              alertRule           = { type = "string" }
              severity            = { type = "string" }
              signalType          = { type = "string" }
              monitorCondition    = { type = "string" }
              monitoringService   = { type = "string" }
              alertTargetIDs      = { type = "array", items = { type = "string" } }
              originAlertId       = { type = "string" }
              firedDateTime       = { type = "string" }
              resolvedDateTime    = { type = "string" }
              description         = { type = "string" }
              essentialsVersion   = { type = "string" }
              alertContextVersion = { type = "string" }
            }
          }
          alertContext = { type = "object", properties = {} }
        }
      }
    }
  })
}

# Custom actions because azurerm_logic_app_action_http has no runtimeConfiguration, needed for secureData.
# secureData keeps the webhook URL out of run history.
resource "azurerm_logic_app_action_custom" "teams_alerts_get_webhook_url" {
  name         = "get-webhook-url"
  logic_app_id = azurerm_logic_app_workflow.teams_alerts.id

  body = jsonencode({
    type     = "Http"
    runAfter = {}
    runtimeConfiguration = {
      secureData = { properties = ["outputs"] }
    }
    inputs = {
      method = "GET"
      uri    = "${azurerm_key_vault.alerts.vault_uri}secrets/${azurerm_key_vault_secret.teams_alerts_webhook_url.name}?api-version=2025-07-01"
      authentication = {
        type     = "ManagedServiceIdentity"
        audience = "https://vault.azure.net"
      }
    }
  })
}

resource "azurerm_logic_app_action_custom" "teams_alerts_post" {
  name         = "post-to-teams"
  logic_app_id = azurerm_logic_app_workflow.teams_alerts.id

  body = jsonencode({
    type     = "Http"
    runAfter = { "get-webhook-url" = ["Succeeded"] }
    runtimeConfiguration = {
      secureData = { properties = ["inputs"] }
    }
    inputs = {
      method = "POST"
      uri    = "@body('get-webhook-url')?['value']"
      body = {
        type = "message"
        attachments = [{
          contentType = "application/vnd.microsoft.card.adaptive"
          contentUrl  = null
          content = {
            "$schema" = "http://adaptivecards.io/schemas/adaptive-card.json"
            type      = "AdaptiveCard"
            version   = "1.2"
            body = [
              {
                type   = "TextBlock"
                size   = "Medium"
                weight = "Bolder"
                wrap   = true
                text   = "@{triggerBody()?['data']?['essentials']?['monitorCondition']}: @{triggerBody()?['data']?['essentials']?['alertRule']}"
              },
              {
                # Prometheus rules carry their text in annotations, other alert types in essentials.
                type = "TextBlock"
                wrap = true
                text = "@{coalesce(triggerBody()?['data']?['alertContext']?['annotations']?['description'], triggerBody()?['data']?['essentials']?['description'])}"
              },
              {
                type = "FactSet"
                facts = [
                  { title = "Severity", value = "@{triggerBody()?['data']?['essentials']?['severity']}" },
                  { title = "Fired", value = "@{triggerBody()?['data']?['essentials']?['firedDateTime']}" },
                  { title = "Resolved", value = "@{triggerBody()?['data']?['essentials']?['resolvedDateTime']}" },
                  { title = "Target", value = "@{join(coalesce(triggerBody()?['data']?['essentials']?['alertTargetIDs'], createArray()), ', ')}" },
                ]
              },
            ]
          }
        }]
      }
    }
  })

  depends_on = [azurerm_logic_app_action_custom.teams_alerts_get_webhook_url]
}

resource "azurerm_monitor_action_group" "teams" {
  name                = "ag-${local.project_name}-teams"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "teams"

  logic_app_receiver {
    name                    = "teams"
    resource_id             = azurerm_logic_app_workflow.teams_alerts.id
    callback_url            = azurerm_logic_app_trigger_http_request.teams_alerts.callback_url
    use_common_alert_schema = true
  }
}
