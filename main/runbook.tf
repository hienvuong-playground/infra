resource "azurerm_automation_account" "main" {
  name                = "aa-${local.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_definition" "aks_start_stop" {
  name        = "AKS Start Stop - ${local.project_name}"
  scope       = azurerm_kubernetes_cluster.main.id
  description = "Allows starting, stopping, and reading AKS managed clusters"

  permissions {
    actions = [
      "Microsoft.ContainerService/managedClusters/start/action",
      "Microsoft.ContainerService/managedClusters/stop/action",
      "Microsoft.ContainerService/managedClusters/read",
    ]
    not_actions = []
  }

  assignable_scopes = [
    azurerm_kubernetes_cluster.main.id,
  ]
}

resource "azurerm_role_assignment" "runbook_aks_start_stop" {
  scope              = azurerm_kubernetes_cluster.main.id
  role_definition_id = azurerm_role_definition.aks_start_stop.role_definition_resource_id
  principal_id       = azurerm_automation_account.main.identity[0].principal_id
}

resource "azurerm_automation_runbook" "stop_aks" {
  name                    = "Stop-AKS-Cluster"
  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = false
  log_progress            = true
  runbook_type            = "PowerShell72"

  content = file("${path.module}/scripts/stop-aks.ps1")
}

resource "azurerm_automation_schedule" "main" {
  name                    = "stop-aks-daily"
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  frequency               = "Day"
  interval                = 1
  start_time              = "2026-09-20T01:00:00+07:00"
  description             = "Stops AKS every day at 1am Vietnam time"
}

resource "azurerm_automation_job_schedule" "link" {
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  schedule_name           = azurerm_automation_schedule.main.name
  runbook_name            = azurerm_automation_runbook.stop_aks.name

  parameters = {
    resourcegroupname = azurerm_resource_group.main.name
    aksclustername    = azurerm_kubernetes_cluster.main.name
  }
}
