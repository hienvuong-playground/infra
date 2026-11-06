resource "azurerm_automation_account" "main" {
  name                = "aa-${local.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "runbook_contributor" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.main.identity[0].principal_id
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

locals {
  aks_stop_time = "02:00" # Vietnam time (UTC+7)
}

# start_time is ignored after creation (it is computed from timestamp()), so a new stop time
# only takes effect by recreating the schedule.
resource "terraform_data" "aks_stop_time" {
  input = local.aks_stop_time
}

resource "azurerm_automation_schedule" "main" {
  name                    = "stop-aks-daily"
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  frequency               = "Day"
  interval                = 1
  # UTC date + 48h at the stop time, so a recreate always lands 1-2 days in the future whatever the
  # UTC hour at apply (Azure rejects start_time < 5 minutes out). Daily, so only the first run is offset.
  start_time  = "${formatdate("YYYY-MM-DD", timeadd(timestamp(), "48h"))}T${local.aks_stop_time}:00+07:00"
  description = "Stops AKS every day at ${local.aks_stop_time} Vietnam time"

  lifecycle {
    ignore_changes       = [start_time]
    replace_triggered_by = [terraform_data.aks_stop_time]
  }
}

resource "azurerm_automation_job_schedule" "link" {
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  schedule_name           = azurerm_automation_schedule.main.name
  runbook_name            = azurerm_automation_runbook.stop_aks.name

  parameters = {
    resourcegroup = azurerm_resource_group.main.name
    clustername   = azurerm_kubernetes_cluster.main.name
  }

  # Deleting the schedule drops its job link in Azure.
  lifecycle {
    replace_triggered_by = [azurerm_automation_schedule.main.id]
  }
}
