output "aks_cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "rg_manual_name" {
  value = data.azurerm_resource_group.rg_manual.name
}

output "domain_name" {
  value = data.azurerm_dns_zone.dns_zone.name
}

output "grafana_client_id" {
  value = azuread_application.grafana.client_id
}

output "oauth2_proxy_client_id" {
  value = azuread_application.oauth2_proxy.client_id
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "gateway_pip_name" {
  value = azurerm_public_ip.gateway.name
}

output "observability_storage_account_name" {
  value = azurerm_storage_account.observability.name
}

output "servicebus_namespace_name" {
  value = azurerm_servicebus_namespace.main.name
}

output "servicebus_queue_name" {
  value = azurerm_servicebus_queue.main.name
}

output "identity_client_ids" {
  value = {
    backend        = azurerm_user_assigned_identity.backend.client_id
    keda_backend   = azurerm_user_assigned_identity.keda_backend.client_id
    cert_manager   = azurerm_user_assigned_identity.cert_manager.client_id
    loki           = azurerm_user_assigned_identity.loki.client_id
    tempo          = azurerm_user_assigned_identity.tempo.client_id
    thanos         = azurerm_user_assigned_identity.thanos.client_id
    otel_collector = azurerm_user_assigned_identity.otel_collector.client_id
  }
}

output "amw_query_endpoint" {
  value = azurerm_monitor_workspace.main.query_endpoint
}

output "azmon_otlp_traces_endpoint" {
  value = local.azmon_otlp_traces_endpoint
}

output "azmon_otlp_logs_endpoint" {
  value = local.azmon_otlp_logs_endpoint
}

output "azmon_otlp_metrics_endpoint" {
  value = local.azmon_otlp_metrics_endpoint
}
