# Action group -> Logic App -> Teams Workflows webhook (note 0032).
# The webhook only accepts Adaptive Card / MessageCard payloads, so the Logic App reshapes the common alert schema.

locals {
  teams_alerts_batch_name = "TeamsAlerts"

  teams_alerts_get_webhook_url_inputs = {
    method = "GET"
    uri    = "${azurerm_key_vault.alerts.vault_uri}secrets/${azurerm_key_vault_secret.teams_alerts_webhook_url.name}?api-version=2025-07-01"
    authentication = {
      type     = "ManagedServiceIdentity"
      audience = "https://vault.azure.net"
    }
  }
}

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

# Prometheus alerts carry labels, so they go to the batch workflow to be grouped (note 0034).
# Terminate ends the run there. The If's status for a false condition isn't documented, so the
# single-card path runs after any status; a failed send-to-batch also falls back to a single card.
resource "azurerm_logic_app_action_custom" "teams_alerts_route" {
  name         = "is-prometheus"
  logic_app_id = azurerm_logic_app_workflow.teams_alerts.id

  body = jsonencode({
    type     = "If"
    runAfter = {}
    expression = {
      and = [{ equals = ["@triggerBody()?['data']?['essentials']?['monitoringService']", "Prometheus"] }]
    }
    actions = {
      "send-to-batch" = {
        type     = "SendToBatch"
        runAfter = {}
        inputs = {
          batchName = local.teams_alerts_batch_name
          content   = "@triggerBody()?['data']"
          host = {
            triggerName = azurerm_logic_app_trigger_custom.teams_alerts_batch.name
            workflow    = { id = azurerm_logic_app_workflow.teams_alerts_batch.id }
          }
        }
      }
      batched = {
        type     = "Terminate"
        runAfter = { "send-to-batch" = ["Succeeded"] }
        inputs   = { runStatus = "Succeeded" }
      }
    }
    else = { actions = {} }
  })
}

# Custom actions because azurerm_logic_app_action_http has no runtimeConfiguration, needed for secureData.
# secureData keeps the webhook URL out of run history.
resource "azurerm_logic_app_action_custom" "teams_alerts_get_webhook_url" {
  name         = "get-webhook-url"
  logic_app_id = azurerm_logic_app_workflow.teams_alerts.id

  body = jsonencode({
    type     = "Http"
    runAfter = { "is-prometheus" = ["Succeeded", "Failed", "Skipped", "TimedOut"] }
    runtimeConfiguration = {
      secureData = { properties = ["outputs"] }
    }
    inputs = local.teams_alerts_get_webhook_url_inputs
  })

  depends_on = [azurerm_logic_app_action_custom.teams_alerts_route]
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

# Groups Prometheus alerts like Alertmanager's group_by [alertname, cluster] and renders its
# msteamsv2 default template (note 0034). Batch releases every minute, the minimum.
resource "azurerm_logic_app_workflow" "teams_alerts_batch" {
  name                = "logic-${local.project_name}-teams-alerts-batch"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "alerts_kv_logic_app_batch" {
  scope                = azurerm_key_vault.alerts.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_logic_app_workflow.teams_alerts_batch.identity[0].principal_id
}

resource "azurerm_logic_app_trigger_custom" "teams_alerts_batch" {
  name         = "batch"
  logic_app_id = azurerm_logic_app_workflow.teams_alerts_batch.id

  body = jsonencode({
    type = "Batch"
    inputs = {
      mode = "Inline"
      configurations = {
        (local.teams_alerts_batch_name) = {
          releaseCriteria = { recurrence = { frequency = "Minute", interval = 1 } }
        }
      }
    }
  })
}

resource "azurerm_logic_app_action_custom" "teams_alerts_batch_init" {
  name         = "init-variables"
  logic_app_id = azurerm_logic_app_workflow.teams_alerts_batch.id

  body = jsonencode({
    type     = "InitializeVariable"
    runAfter = {}
    inputs = {
      variables = [
        { name = "firing-blocks", type = "Array", value = [] },
        { name = "resolved-blocks", type = "Array", value = [] },
        { name = "common-values", type = "Array", value = [] },
      ]
    }
  })

  depends_on = [azurerm_logic_app_trigger_custom.teams_alerts_batch]
}

resource "azurerm_logic_app_action_custom" "teams_alerts_batch_get_webhook_url" {
  name         = "get-webhook-url"
  logic_app_id = azurerm_logic_app_workflow.teams_alerts_batch.id

  body = jsonencode({
    type     = "Http"
    runAfter = { "init-variables" = ["Succeeded"] }
    runtimeConfiguration = {
      secureData = { properties = ["outputs"] }
    }
    inputs = local.teams_alerts_get_webhook_url_inputs
  })

  depends_on = [azurerm_logic_app_action_custom.teams_alerts_batch_init]
}

# Each batched item's content is the alert's common-schema `data` object.
resource "azurerm_logic_app_action_custom" "teams_alerts_batch_alerts" {
  name         = "alerts"
  logic_app_id = azurerm_logic_app_workflow.teams_alerts_batch.id

  body = jsonencode({
    type     = "Select"
    runAfter = { "get-webhook-url" = ["Succeeded"] }
    inputs = {
      from   = "@triggerBody()?['items']"
      select = "@item()?['content']"
    }
  })

  depends_on = [azurerm_logic_app_action_custom.teams_alerts_batch_get_webhook_url]
}

resource "azurerm_logic_app_action_custom" "teams_alerts_batch_group_keys" {
  name         = "group-keys"
  logic_app_id = azurerm_logic_app_workflow.teams_alerts_batch.id

  body = jsonencode({
    type     = "Select"
    runAfter = { "alerts" = ["Succeeded"] }
    inputs = {
      from   = "@body('alerts')"
      select = local.teams_alerts_group_key
    }
  })

  depends_on = [azurerm_logic_app_action_custom.teams_alerts_batch_alerts]
}

locals {
  teams_alerts_group_key = "@{item()?['alertContext']?['labels']?['alertname']}|@{item()?['alertContext']?['labels']?['cluster']}"

  # Alertmanager's webhook max_alerts pattern; msteamsv2 itself has no limit and Teams rejects > 28 KB.
  teams_alerts_max_alerts = 50

  # Workflow expressions have no keys() function. xml() turns the labels object into <r><name>value</name>…</r>,
  # and xpath() reads each element's name and value by position.
  teams_alerts_pairs = {
    for kind in ["labels", "annotations"] : kind => {
      json  = "@json(concat('{\"r\":', string(coalesce(items('for-each-alert')?['alertContext']?['${kind}'], json('{}'))), '}'))"
      count = "@int(string(xpath(xml(outputs('${kind}-json')), 'count(/r/*)')))"
    }
  }
}

resource "azurerm_logic_app_action_custom" "teams_alerts_batch_for_each_group" {
  name         = "for-each-group"
  logic_app_id = azurerm_logic_app_workflow.teams_alerts_batch.id

  body = jsonencode({
    type                 = "Foreach"
    foreach              = "@union(body('group-keys'), body('group-keys'))"
    runAfter             = { "group-keys" = ["Succeeded"] }
    runtimeConfiguration = { concurrency = { repetitions = 1 } }
    actions = {
      "reset-firing-blocks" = {
        type     = "SetVariable"
        runAfter = {}
        inputs   = { name = "firing-blocks", value = [] }
      }
      "reset-resolved-blocks" = {
        type     = "SetVariable"
        runAfter = { "reset-firing-blocks" = ["Succeeded"] }
        inputs   = { name = "resolved-blocks", value = [] }
      }
      "reset-common-values" = {
        type     = "SetVariable"
        runAfter = { "reset-resolved-blocks" = ["Succeeded"] }
        inputs   = { name = "common-values", value = [] }
      }
      "group-alerts" = {
        type     = "Query"
        runAfter = { "reset-common-values" = ["Succeeded"] }
        inputs = {
          from  = "@body('alerts')"
          where = "@equals(concat(item()?['alertContext']?['labels']?['alertname'], '|', item()?['alertContext']?['labels']?['cluster']), items('for-each-group'))"
        }
      }
      firing = {
        type     = "Query"
        runAfter = { "group-alerts" = ["Succeeded"] }
        inputs = {
          from  = "@body('group-alerts')"
          where = "@equals(item()?['essentials']?['monitorCondition'], 'Fired')"
        }
      }
      resolved = {
        type     = "Query"
        runAfter = { firing = ["Succeeded"] }
        inputs = {
          from  = "@body('group-alerts')"
          where = "@equals(item()?['essentials']?['monitorCondition'], 'Resolved')"
        }
      }
      shown = {
        type     = "Compose"
        runAfter = { resolved = ["Succeeded"] }
        inputs   = "@take(union(body('firing'), body('resolved')), ${local.teams_alerts_max_alerts})"
      }

      # __text_alert_list_markdown: Labels and Annotations as "  - name = value", sorted by name.
      "for-each-alert" = {
        type                 = "Foreach"
        foreach              = "@outputs('shown')"
        runAfter             = { shown = ["Succeeded"] }
        runtimeConfiguration = { concurrency = { repetitions = 1 } }
        actions = merge(
          merge([
            for kind, p in local.teams_alerts_pairs : {
              "${kind}-json" = {
                type     = "Compose"
                runAfter = kind == "labels" ? {} : { "labels-lines" = ["Succeeded"] }
                inputs   = p.json
              }
              "${kind}-count" = {
                type     = "Compose"
                runAfter = { "${kind}-json" = ["Succeeded"] }
                inputs   = p.count
              }
              # range() needs a positive count, so take() trims range(1, 1) back to empty for no elements.
              "${kind}-pairs" = {
                type     = "Select"
                runAfter = { "${kind}-count" = ["Succeeded"] }
                inputs = {
                  from = "@take(range(1, max(outputs('${kind}-count'), 1)), outputs('${kind}-count'))"
                  select = {
                    name  = "@xpath(xml(outputs('${kind}-json')), concat('name(/r/*[', string(item()), '])'))"
                    value = "@xpath(xml(outputs('${kind}-json')), concat('string(/r/*[', string(item()), '])'))"
                  }
                }
              }
              "${kind}-lines" = {
                type     = "Select"
                runAfter = { "${kind}-pairs" = ["Succeeded"] }
                inputs = {
                  from   = "@sort(body('${kind}-pairs'), 'name')"
                  select = "  - @{item()?['name']} = @{item()?['value']}\n"
                }
              }
            }
          ]...),
          {
            block = {
              type     = "Compose"
              runAfter = { "annotations-lines" = ["Succeeded"] }
              inputs   = "\nLabels:\n@{join(body('labels-lines'), '')}\nAnnotations:\n@{join(body('annotations-lines'), '')}"
            }
            "is-firing" = {
              type     = "If"
              runAfter = { block = ["Succeeded"] }
              expression = {
                and = [{ equals = ["@items('for-each-alert')?['essentials']?['monitorCondition']", "Fired"] }]
              }
              actions = {
                "append-firing" = {
                  type     = "AppendToArrayVariable"
                  runAfter = {}
                  inputs   = { name = "firing-blocks", value = "@outputs('block')" }
                }
              }
              else = {
                actions = {
                  "append-resolved" = {
                    type     = "AppendToArrayVariable"
                    runAfter = {}
                    inputs   = { name = "resolved-blocks", value = "@outputs('block')" }
                  }
                }
              }
            }
          }
        )
      }

      # __subject's "(CommonLabels minus GroupLabels)": labels with the same value on every alert in the group.
      "first-json" = {
        type     = "Compose"
        runAfter = { "for-each-alert" = ["Succeeded"] }
        inputs   = "@json(concat('{\"r\":', string(first(body('group-alerts'))?['alertContext']?['labels']), '}'))"
      }
      "first-count" = {
        type     = "Compose"
        runAfter = { "first-json" = ["Succeeded"] }
        inputs   = "@int(string(xpath(xml(outputs('first-json')), 'count(/r/*)')))"
      }
      "first-pairs" = {
        type     = "Select"
        runAfter = { "first-count" = ["Succeeded"] }
        inputs = {
          from = "@take(range(1, max(outputs('first-count'), 1)), outputs('first-count'))"
          select = {
            name  = "@xpath(xml(outputs('first-json')), concat('name(/r/*[', string(item()), '])'))"
            value = "@xpath(xml(outputs('first-json')), concat('string(/r/*[', string(item()), '])'))"
          }
        }
      }
      "for-each-label" = {
        type                 = "Foreach"
        foreach              = "@sort(body('first-pairs'), 'name')"
        runAfter             = { "first-pairs" = ["Succeeded"] }
        runtimeConfiguration = { concurrency = { repetitions = 1 } }
        actions = {
          mismatches = {
            type     = "Query"
            runAfter = {}
            inputs = {
              from  = "@body('group-alerts')"
              where = "@not(equals(item()?['alertContext']?['labels']?[items('for-each-label')?['name']], items('for-each-label')?['value']))"
            }
          }
          "is-common" = {
            type     = "If"
            runAfter = { mismatches = ["Succeeded"] }
            expression = {
              and = [
                { equals = ["@length(body('mismatches'))", 0] },
                { not = { equals = ["@items('for-each-label')?['name']", "alertname"] } },
                { not = { equals = ["@items('for-each-label')?['name']", "cluster"] } },
              ]
            }
            actions = {
              "append-common" = {
                type     = "AppendToArrayVariable"
                runAfter = {}
                inputs   = { name = "common-values", value = "@items('for-each-label')?['value']" }
              }
            }
            else = { actions = {} }
          }
        }
      }

      # msteamsv2.default.title = __subject
      title = {
        type     = "Compose"
        runAfter = { "for-each-label" = ["Succeeded"] }
        inputs   = "[@{if(greater(length(body('firing')), 0), concat('FIRING:', string(length(body('firing')))), 'RESOLVED')}] @{first(body('group-alerts'))?['alertContext']?['labels']?['alertname']} @{first(body('group-alerts'))?['alertContext']?['labels']?['cluster']} @{if(empty(variables('common-values')), '', concat('(', join(variables('common-values'), ' '), ')'))}"
      }

      # msteamsv2.default.text, without "Source:" (the common schema has no GeneratorURL).
      "firing-section" = {
        type     = "Compose"
        runAfter = { title = ["Succeeded"] }
        inputs   = "\n# Alerts Firing:\n@{join(variables('firing-blocks'), '')}\n"
      }
      "resolved-section" = {
        type     = "Compose"
        runAfter = { "firing-section" = ["Succeeded"] }
        inputs   = "\n# Alerts Resolved:\n@{join(variables('resolved-blocks'), '')}\n"
      }
      "truncated-line" = {
        type     = "Compose"
        runAfter = { "resolved-section" = ["Succeeded"] }
        inputs   = "\n… @{sub(length(body('group-alerts')), length(outputs('shown')))} alerts truncated\n"
      }
      text = {
        type     = "Compose"
        runAfter = { "truncated-line" = ["Succeeded"] }
        inputs   = "@{if(empty(variables('firing-blocks')), '', outputs('firing-section'))}@{if(empty(variables('resolved-blocks')), '', outputs('resolved-section'))}@{if(greater(length(body('group-alerts')), length(outputs('shown'))), outputs('truncated-line'), '')}"
      }

      # Card layout from Alertmanager's notify/msteamsv2/msteamsv2.go.
      "post-to-teams" = {
        type                 = "Http"
        runAfter             = { text = ["Succeeded"] }
        runtimeConfiguration = { secureData = { properties = ["inputs"] } }
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
                    text   = "@{outputs('title')}"
                    weight = "Bolder"
                    size   = "Medium"
                    wrap   = true
                    style  = "heading"
                    color  = "@{if(greater(length(body('firing')), 0), 'Attention', 'Good')}"
                  },
                  {
                    type = "TextBlock"
                    text = "@{outputs('text')}"
                    wrap = true
                  },
                ]
                msteams = { width = "full" }
              }
            }]
          }
        }
      }
    }
  })

  depends_on = [
    azurerm_logic_app_action_custom.teams_alerts_batch_group_keys,
    azurerm_role_assignment.alerts_kv_logic_app_batch,
  ]
}
# temp