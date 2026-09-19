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
  namespace  = "flux"

  git_repository {
    url             = "ssh://git@github.com/hienvuong-playground/backend"
    reference_type  = "branch"
    reference_value = "main"
    ssh_private_key_base64 = base64encode(tls_private_key.backend.private_key_pem)
  }

  kustomizations {
    name = "backend"
    path = "./deploy"

    # post_build {
    #   substitute = {
    #     example_var = "substitute_with_this"
    #   }
    #   substitute_from {
    #     kind = "ConfigMap"
    #     name = "example-configmap"
    #   }
    # }
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.main
  ]
}

