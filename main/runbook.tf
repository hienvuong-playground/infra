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

  lifecycle {
    # azurerm never reads runbook_type back from the API, so state stays "PowerShell"
    # while Azure is already "PowerShell72". As runbook_type is ForceNew, that stale-state
    # mismatch would otherwise force a needless destroy/recreate on every plan.
    ignore_changes = [
      runbook_type,
    ]
  }
}

resource "azurerm_automation_schedule" "main" {
  name                    = "stop-aks-daily"
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  frequency               = "Day"
  interval                = 1
  # 1am Vietnam time (UTC+7). Computed dynamically so a recreate always lands
  # comfortably in the future (Azure rejects start_time < 5 minutes out).
  # timestamp() is UTC; +48h guarantees the resulting 01:00+07:00 is ~1-2 days
  # ahead regardless of the UTC hour at apply time. The schedule is daily, so
  # only the first run is offset — subsequent runs fire at 1am every day.
  start_time  = "${formatdate("YYYY-MM-DD", timeadd(timestamp(), "24h"))}T01:00:00+07:00"
  description = "Stops AKS every day at 1am Vietnam time"

  lifecycle {
    ignore_changes = [
      start_time,
    ]
  }
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
