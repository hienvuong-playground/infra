resource "tls_private_key" "backend" {
  algorithm = "ED25519"
}

resource "github_repository_deploy_key" "backend" {
  title      = "flux-backend"
  repository = "backend"
  key        = tls_private_key.backend.public_key_openssh
  read_only  = true
}

resource "azurerm_kubernetes_cluster_extension" "main" {
  name           = "flux"
  cluster_id     = local.cloud.aks_cluster_id
  extension_type = "microsoft.flux"
}

resource "tls_private_key" "infra" {
  algorithm = "ED25519"
}


resource "github_repository_deploy_key" "infra" {
  title      = "flux-infra"
  repository = "infra"
  key        = tls_private_key.infra.public_key_openssh
  read_only  = true
}

resource "azurerm_kubernetes_flux_configuration" "infra" {
  name       = "flux-config"
  cluster_id = local.cloud.aks_cluster_id
  namespace  = "flux-system"
  scope      = "cluster"

  git_repository {
    url                      = "ssh://git@github.com/hienvuong-playground/infra"
    reference_type           = "branch"
    reference_value          = "main"
    ssh_private_key_base64   = base64encode(tls_private_key.infra.private_key_pem)
    sync_interval_in_seconds = 60
  }

  kustomizations {
    name                       = "cluster"
    path                       = "./k8s/gitops/clusters"
    garbage_collection_enabled = true
    sync_interval_in_seconds   = 60

    post_build {
      substitute = {
        RG_MANUAL                     = local.cloud.rg_manual_name
        DOMAIN_NAME                   = local.cloud.domain_name
        AZURE_SUBSCRIPTION_ID         = data.azurerm_client_config.current.subscription_id
        AZURE_TENANT_ID               = data.azurerm_client_config.current.tenant_id
        ID_GRAFANA                    = local.cloud.grafana_client_id
        GRAFANA_ADMINS_GROUP_ID       = data.azuread_group.grafana_admins.object_id
        GRAFANA_DEVELOPERS_GROUP_ID   = data.azuread_group.grafana_developers.object_id
        ID_OAUTH2_PROXY               = local.cloud.oauth2_proxy_client_id
        KEYVAULT_NAME                 = local.cloud.key_vault_name
        MI_CERT_MANAGER               = local.cloud.identity_client_ids.cert_manager
        GATEWAY_PIP_NAME              = local.cloud.gateway_pip_name
        RG_MAIN                       = local.cloud.resource_group_name
        ID_LOKI                       = local.cloud.identity_client_ids.loki
        ID_TEMPO                      = local.cloud.identity_client_ids.tempo
        ID_THANOS                     = local.cloud.identity_client_ids.thanos
        OBSERVABILITY_STORAGE_ACCOUNT = local.cloud.observability_storage_account_name
        ID_OTEL_COLLECTOR             = local.cloud.identity_client_ids.otel_collector
        AZMON_OTLP_TRACES_ENDPOINT    = local.cloud.azmon_otlp_traces_endpoint
        AZMON_OTLP_LOGS_ENDPOINT      = local.cloud.azmon_otlp_logs_endpoint
        AZMON_OTLP_METRICS_ENDPOINT   = local.cloud.azmon_otlp_metrics_endpoint
        AMW_QUERY_ENDPOINT            = local.cloud.amw_query_endpoint
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.main
  ]
}

resource "azurerm_kubernetes_flux_configuration" "backend" {
  name       = "backend"
  cluster_id = local.cloud.aks_cluster_id
  namespace  = "backend"

  git_repository {
    url                      = "ssh://git@github.com/hienvuong-playground/backend"
    reference_type           = "branch"
    reference_value          = "main"
    ssh_private_key_base64   = base64encode(tls_private_key.backend.private_key_pem)
    sync_interval_in_seconds = 60
  }

  kustomizations {
    name                       = "backend"
    path                       = "./deploy"
    garbage_collection_enabled = true
    sync_interval_in_seconds   = 60
    timeout_in_seconds         = 180
    retry_interval_in_seconds  = 60
    post_build {
      substitute = {
        ID_KEDA_BACKEND       = local.cloud.identity_client_ids.keda_backend
        SERVICE_BUS_NAMESPACE = local.cloud.servicebus_namespace_name
        SERVICE_BUS_QUEUE     = local.cloud.servicebus_queue_name
        SERVICE_BUS_HOSTNAME  = "${local.cloud.servicebus_namespace_name}.servicebus.windows.net"
        ID_BACKEND            = local.cloud.identity_client_ids.backend
        KEYVAULT_NAME         = local.cloud.key_vault_name
        AZURE_TENANT_ID       = data.azurerm_client_config.current.tenant_id
        DOMAIN_NAME           = local.cloud.domain_name
        POSTGRES_HOST         = local.cloud.postgres_fqdn
        POSTGRES_DB           = local.cloud.postgres_database
        POSTGRES_USER         = local.cloud.postgres_user
        STATIC_WEB_APP_HOST   = local.cloud.static_web_app_host
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.main
  ]
}
