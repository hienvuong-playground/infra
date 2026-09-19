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
    url             = "ssh://git@github.com/hienvuong-playground/backend"
    reference_type  = "branch"
    reference_value = "main"
    ssh_private_key_base64 = base64encode(tls_private_key.backend.private_key_pem)
  }

  kustomizations {
    name = "backend"
    path = "./deploy"

    post_build {
      substitute = {
        target_namespace = local.backend_namespace
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.main
  ]
}


resource "kubernetes_namespace_v1" "backend" {
  metadata {
    name = "backend"
  }
}

locals {
  flux_namespace = azurerm_kubernetes_flux_configuration.backend.namespace
  backend_namespace = kubernetes_namespace_v1.backend.metadata[0].name
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
