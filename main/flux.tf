locals {
  flux_namespace       = azurerm_kubernetes_flux_configuration.backend.namespace
  backend_namespace    = kubernetes_namespace_v1.backend.metadata[0].name
  service_account_name = kubernetes_service_account_v1.backend.metadata[0].name
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
  cluster_id     = azurerm_kubernetes_cluster.main.id
  extension_type = "microsoft.flux"
}

resource "azurerm_kubernetes_flux_configuration" "backend" {
  name       = "backend"
  cluster_id = azurerm_kubernetes_cluster.main.id
  namespace  = "flux-system"

  git_repository {
    url                    = "ssh://git@github.com/hienvuong-playground/backend"
    reference_type         = "branch"
    reference_value        = "main"
    ssh_private_key_base64 = base64encode(tls_private_key.backend.private_key_pem)
  }

  kustomizations {
    name = "backend"
    path = "./deploy"

    post_build {
      substitute = {
        target_namespace = local.backend_namespace
        id_keyvault      = azurerm_user_assigned_identity.backend.client_id
        keyvault_name    = azurerm_key_vault.main.name
        tenant_id        = data.azurerm_client_config.current.tenant_id
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.main
  ]
}

resource "azurerm_user_assigned_identity" "backend" {
  location            = azurerm_resource_group.main.location
  name                = "id-backend-${local.project_name}"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "secret_user" {
  principal_id         = azurerm_user_assigned_identity.backend.principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.main.id
}

resource "kubernetes_service_account_v1" "backend" {
  metadata {
    name      = "backend-workload"
    namespace = local.backend_namespace
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.backend.client_id
    }
  }
}

resource "azurerm_federated_identity_credential" "backend" {
  name                      = "fed-backend"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.backend.id
  subject                   = "system:serviceaccount:${local.backend_namespace}:${local.service_account_name}"
}

resource "kubernetes_namespace_v1" "backend" {
  metadata {
    name = "backend"
  }
}

resource "kubernetes_role_v1" "flux_applier" {
  metadata {
    name      = "flux-applier-role"
    namespace = local.backend_namespace
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding_v1" "flux_applier" {
  metadata {
    name      = "flux-applier-binding"
    namespace = local.backend_namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.flux_applier.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "flux-applier"
    namespace = local.flux_namespace
  }
}
