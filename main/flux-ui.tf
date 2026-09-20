resource "helm_release" "flux_web" {
  name             = "flux-web"
  namespace        = "flux-system" #temp
  repository       = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart            = "flux-operator"
  create_namespace = false

  set = [
    { name = "fullnameOverride", value = "flux-web" },
    { name = "web.serverOnly", value = "true" },
    { name = "installCRDs", value = "true" },
  ]

  depends_on = [
    azurerm_kubernetes_cluster_extension.main
  ]
}
