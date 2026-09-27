locals {
  project_name = "playground"

  azmon_dcr_path              = "datacollectionRules/${data.azapi_resource.otlp_dcr.output.properties.immutableId}/streams"
  azmon_logs_ingestion        = data.azapi_resource.otlp_dce.output.properties.logsIngestion.endpoint
  azmon_otlp_traces_endpoint  = "${local.azmon_logs_ingestion}/${local.azmon_dcr_path}/Microsoft-OTLP-Traces/otlp/v1/traces"
  azmon_otlp_logs_endpoint    = "${local.azmon_logs_ingestion}/${local.azmon_dcr_path}/Microsoft-OTLP-Logs/otlp/v1/logs"
  azmon_otlp_metrics_endpoint = "${data.azapi_resource.otlp_dce.output.properties.metricsIngestion.endpoint}/${local.azmon_dcr_path}/Custom-Metrics-Otel/otlp/v1/metrics"
}
