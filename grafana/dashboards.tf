resource "grafana_folder" "observability" {
  uid   = "observability"
  title = "Observability"
}

resource "grafana_dashboard" "application_metrics" {
  folder      = grafana_folder.observability.uid
  config_json = file("${path.module}/dashboards/application-metrics.json")
}

resource "grafana_dashboard" "application_logs" {
  folder      = grafana_folder.observability.uid
  config_json = file("${path.module}/dashboards/application-logs.json")
}

# Copies of the AMG built-in Kubernetes dashboards, so they can be changed.
resource "grafana_dashboard" "infrastructure" {
  for_each    = fileset("${path.module}/dashboards", "infrastructure-*.json")
  folder      = grafana_folder.observability.uid
  config_json = file("${path.module}/dashboards/${each.value}")
}

resource "grafana_dashboard" "home" {
  config_json = file("${path.module}/dashboards/home.json")
}

resource "grafana_organization_preferences" "main" {
  home_dashboard_uid = grafana_dashboard.home.uid
}
