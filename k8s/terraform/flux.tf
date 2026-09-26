data "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${local.project_name}"
  resource_group_name = "rg-${local.project_name}"
}

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
  cluster_id     = data.azurerm_kubernetes_cluster.main.id
  extension_type = "microsoft.flux"
}

resource "tls_private_key" "k8s" {
  algorithm = "ED25519"
}


resource "github_repository_deploy_key" "k8s" {
  title      = "flux-k8s"
  repository = "k8s"
  key        = tls_private_key.k8s.public_key_openssh
  read_only  = true
}

resource "azurerm_kubernetes_flux_configuration" "k8s" {
  name       = "flux-config"
  cluster_id = data.azurerm_kubernetes_cluster.main.id
  namespace  = "flux-system"
  scope      = "cluster"

  git_repository {
    url                    = "ssh://git@github.com/hienvuong-playground/k8s"
    reference_type         = "branch"
    reference_value        = "main"
    ssh_private_key_base64 = base64encode(tls_private_key.k8s.private_key_pem)
  }

  kustomizations {
    name                       = "cluster"
    path                       = "./gitops/clusters"
    garbage_collection_enabled = true

    post_build {
      substitute = {
        RG_MANUAL = data.azurerm_resource_group.manual.name
        DOMAIN_NAME = data.azurerm_dns_zone.dns_zone.name
        AZURE_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
        MI_CERT_MANAGER = data.azurerm_user_assigned_identity.cert_manager.client_id
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.main
  ]
}

resource "azurerm_kubernetes_flux_configuration" "backend" {
  name       = "backend"
  cluster_id = data.azurerm_kubernetes_cluster.main.id
  namespace  = "backend"

  git_repository {
    url                    = "ssh://git@github.com/hienvuong-playground/backend"
    reference_type         = "branch"
    reference_value        = "main"
    ssh_private_key_base64 = base64encode(tls_private_key.backend.private_key_pem)
  }

  kustomizations {
    name = "backend"
    path = "./deploy"
    garbage_collection_enabled = true
    post_build {
      substitute = {
        ID_KEDA_BACKEND = data.azurerm_user_assigned_identity.keda_backend.client_id
        SERVICE_BUS_NAMESPACE = data.azurerm_servicebus_namespace.main.name
        SERVICE_BUS_QUEUE = data.azurerm_servicebus_queue.example.name
        SERVICE_BUS_HOSTNAME = "${data.azurerm_servicebus_namespace.main.name}.servicebus.windows.net"
        ID_BACKEND = data.azurerm_user_assigned_identity.backend.client_id
        AZURE_TENANT_ID = data.azurerm_client_config.current.tenant_id
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.main
  ]
}
