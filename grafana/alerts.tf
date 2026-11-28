# Alerting moved here from Azure Monitor (note 0035).
#
# Microsoft's recommended Kubernetes alerts (note 0033), from
# https://aka.ms/azureprometheus-recommendedmetricalerts (Azure/prometheus-collector
# GeneratedMonitoringArtifacts/Default/recommendedMetricAlerts.json). Every rule in the template
# has severity label "warning" and autoResolved = true, so those are set in the resource.
locals {
  kubernetes_alert_groups = {
    "Cluster-level" = [
      {
        alert           = "KubeCPUQuotaOvercommit"
        for             = "5m"
        keep_firing_for = "10m"
        description     = "Cluster {{ $labels.cluster}} has overcommitted CPU resource requests for Namespaces. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)."
        expr            = <<-EOT
          sum(min without(resource) (kube_resourcequota{job="kube-state-metrics", type="hard", resource=~"(cpu|requests.cpu)"}))  /sum(kube_node_status_allocatable{resource="cpu", job="kube-state-metrics"})  > 1.5
        EOT
      },
      {
        alert           = "KubeMemoryQuotaOvercommit"
        for             = "5m"
        keep_firing_for = "10m"
        description     = "Cluster {{ $labels.cluster}} has overcommitted memory resource requests for Namespaces. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)."
        expr            = <<-EOT
          sum(min without(resource) (kube_resourcequota{job="kube-state-metrics", type="hard", resource=~"(memory|requests.memory)"}))  /sum(kube_node_status_allocatable{resource="memory", job="kube-state-metrics"})  > 1.5
        EOT
      },
      {
        alert           = "KubeContainerOOMKilledCount"
        for             = "5m"
        keep_firing_for = "10m"
        description     = "Number of OOM killed containers is greater than 0. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)."
        expr            = <<-EOT
          sum by (cluster,container,controller,namespace)(kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} * on(cluster,namespace,pod) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)")) > 0
        EOT
      },
      {
        alert           = "KubeClientErrors"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance }}' is experiencing {{ $value | humanizePercentage }} errors. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)."
        expr            = <<-EOT
          (sum(rate(rest_client_requests_total{code=~"5.."}[5m])) by (cluster, instance, job, namespace)  / sum(rate(rest_client_requests_total[5m])) by (cluster, instance, job, namespace)) > 0.01
        EOT
      },
      {
        alert           = "KubePersistentVolumeFillingUp"
        for             = "60m"
        keep_firing_for = "15m"
        description     = "Based on recent sampling, the PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in Namespace {{ $labels.namespace }} is expected to fill up within four days. Currently {{ $value | humanizePercentage }} is available. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)."
        expr            = <<-EOT
          kubelet_volume_stats_available_bytes{job="kubelet"}/kubelet_volume_stats_capacity_bytes{job="kubelet"} < 0.15 and kubelet_volume_stats_used_bytes{job="kubelet"} > 0 and predict_linear(kubelet_volume_stats_available_bytes{job="kubelet"}[6h], 4 * 24 * 3600) < 0 unless on(namespace, persistentvolumeclaim) kube_persistentvolumeclaim_access_mode{ access_mode="ReadOnlyMany"} == 1 unless on(namespace, persistentvolumeclaim) kube_persistentvolumeclaim_labels{label_excluded_from_alerts="true"} == 1
        EOT
      },
      {
        alert           = "KubePersistentVolumeInodesFillingUp"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "The PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in Namespace {{ $labels.namespace }} only has {{ $value | humanizePercentage }} free inodes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)."
        expr            = <<-EOT
          kubelet_volume_stats_inodes_free{job="kubelet"} / kubelet_volume_stats_inodes{job="kubelet"} < 0.03
        EOT
      },
      {
        alert           = "KubePersistentVolumeErrors"
        for             = "5m"
        keep_firing_for = "10m"
        description     = "The persistent volume {{ $labels.persistentvolume }} has status {{ $labels.phase }}. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)."
        expr            = <<-EOT
          kube_persistentvolume_status_phase{phase=~"Failed|Pending",job="kube-state-metrics"} > 0
        EOT
      },
      {
        alert           = "KubeContainerWaiting"
        for             = "60m"
        keep_firing_for = "10m"
        description     = "pod/{{ $labels.pod }} in namespace {{ $labels.namespace }} on container {{ $labels.container}} has been in waiting state for longer than 1 hour. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)."
        expr            = <<-EOT
          sum by (namespace, pod, container, cluster) (kube_pod_container_status_waiting_reason{job="kube-state-metrics"}) > 0
        EOT
      },
      {
        alert           = "KubeDaemonSetNotScheduled"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "{{ $value }} Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset }} are not scheduled. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)."
        expr            = <<-EOT
          kube_daemonset_status_desired_number_scheduled{job="kube-state-metrics"} - kube_daemonset_status_current_number_scheduled{job="kube-state-metrics"} > 0
        EOT
      },
      {
        alert           = "KubeDaemonSetMisScheduled"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "{{ $value }} Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset }} are running where they are not supposed to run. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)."
        expr            = <<-EOT
          kube_daemonset_status_number_misscheduled{job="kube-state-metrics"} > 0
        EOT
      },
      {
        alert           = "KubeQuotaAlmostFull"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "{{ $value | humanizePercentage }} usage of {{ $labels.resource }} in namespace {{ $labels.namespace }} in {{ $labels.cluster}}. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)."
        expr            = <<-EOT
          kube_resourcequota{job="kube-state-metrics", type="used"}  / ignoring(instance, job, type)(kube_resourcequota{job="kube-state-metrics", type="hard"} > 0)  > 0.9 < 1
        EOT
      },
    ]
    "Node-level" = [
      {
        alert           = "KubeNodeUnreachable"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "{{ $labels.node }} in {{ $labels.cluster}} is unreachable and some workloads may be rescheduled. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/node-level-recommended-alerts)."
        expr            = <<-EOT
          (kube_node_spec_taint{job="kube-state-metrics",key="node.kubernetes.io/unreachable",effect="NoSchedule"} unless ignoring(key,value) kube_node_spec_taint{job="kube-state-metrics",key=~"ToBeDeletedByClusterAutoscaler|cloud.google.com/impending-node-termination|aws-node-termination-handler/spot-itn"}) == 1
        EOT
      },
      {
        alert           = "KubeNodeReadinessFlapping"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "The readiness status of node {{ $labels.node }} in {{ $labels.cluster}} has changed more than 2 times in the last 15 minutes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/node-level-recommended-alerts)."
        expr            = <<-EOT
          sum(changes(kube_node_status_condition{status="true",condition="Ready"}[15m])) by (cluster, node) > 2
        EOT
      },
      {
        alert           = "KubeNodeDiskUsageHigh"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "The disk usage on node {{ $labels.instance }} in {{ $labels.job }} has exceeded 80% and current usage is {{ $value | humanizePercentage }}%). For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/node-level-recommended-alerts)."
        expr            = <<-EOT
          100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100) > 80
        EOT
      },
    ]
    "Pod-level" = [
      {
        alert           = "KubePodCrashLooping"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "{{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container }}) in {{ $labels.cluster}} is restarting {{ printf \"%.2f\" $value }} / second. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          max_over_time(kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff", job="kube-state-metrics"}[5m]) >= 1
        EOT
      },
      {
        alert           = "KubeJobStale"
        for             = "360m"
        keep_firing_for = "15m"
        description     = "Number of stale jobs older than six hours is greater than 0. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          sum by(namespace,cluster)(kube_job_spec_completions{job="kube-state-metrics"}) - sum by(namespace,cluster)(kube_job_status_succeeded{job="kube-state-metrics"})  > 0 
        EOT
      },
      {
        alert           = "KubePodContainerRestart"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "Pod container restarted in the last 1 hour. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          sum by (namespace, controller, container, cluster)(increase(kube_pod_container_status_restarts_total{job="kube-state-metrics"}[1h])* on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)")) > 0
        EOT
      },
      {
        alert           = "KubePodReadyStateLow"
        for             = "5m"
        keep_firing_for = "15m"
        description     = "Ready state of pods is less than 80%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          sum by (cluster,namespace,deployment)(kube_deployment_status_replicas_ready) / sum by (cluster,namespace,deployment)(kube_deployment_spec_replicas) <.8 or sum by (cluster,namespace,daemonset)(kube_daemonset_status_number_ready) / sum by (cluster,namespace,daemonset)(kube_daemonset_status_desired_number_scheduled) <.8 
        EOT
      },
      {
        alert           = "KubePodFailedState"
        for             = "5m"
        keep_firing_for = "15m"
        description     = "Number of pods in failed state are greater than 0. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          sum by (cluster, namespace, controller) (kube_pod_status_phase{phase="failed"} * on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)"))  > 0
        EOT
      },
      {
        alert           = "KubePodNotReadyByController"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "{{ $labels.namespace }}/{{ $labels.pod }} in {{ $labels.cluster}} by controller is not ready. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          sum by (namespace, controller, cluster) (max by(namespace, pod, cluster) (kube_pod_status_phase{job="kube-state-metrics", phase=~"Pending|Unknown"}  ) * on(namespace, pod, cluster) group_left(controller)label_replace(kube_pod_owner,"controller","$1","owner_name","(.*)")) > 0
        EOT
      },
      {
        alert           = "KubeStatefulSetGenerationMismatch"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "StatefulSet generation for {{ $labels.namespace }}/{{ $labels.statefulset }} does not match, this indicates that the StatefulSet has failed but has not been rolled back. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          kube_statefulset_status_observed_generation{job="kube-state-metrics"} != kube_statefulset_metadata_generation{job="kube-state-metrics"}
        EOT
      },
      {
        alert           = "KubeJobFailed"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "Job {{ $labels.namespace }}/{{ $labels.job_name }} in {{ $labels.cluster}} failed to complete. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          kube_job_failed{job="kube-state-metrics"}  > 0
        EOT
      },
      {
        alert           = "KubeContainerAverageCPUHigh"
        for             = "5m"
        keep_firing_for = "15m"
        description     = "Average CPU usage per container is greater than 95%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          sum (rate(container_cpu_usage_seconds_total{image!="", container!="POD"}[5m])) by (pod,cluster,container,namespace) / sum(container_spec_cpu_quota{image!="", container!="POD"}/container_spec_cpu_period{image!="", container!="POD"}) by (pod,cluster,container,namespace) > .95
        EOT
      },
      {
        alert           = "KubeContainerAverageMemoryHigh"
        for             = "10m"
        keep_firing_for = "10m"
        description     = "Average Memory usage per container is greater than 95%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          avg by (namespace, controller, container, cluster)(((container_memory_working_set_bytes{container!="", image!="", container!="POD"} / on(namespace,cluster,pod,container) group_left kube_pod_container_resource_limits{resource="memory", node!=""})*on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)")) > .95)
        EOT
      },
      {
        alert           = "KubeletPodStartUpLatencyHigh"
        for             = "10m"
        keep_firing_for = "10m"
        description     = "Kubelet Pod startup latency is too high. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          histogram_quantile(0.99, sum(rate(kubelet_pod_worker_duration_seconds_bucket{job="kubelet"}[5m])) by (cluster, instance, le)) * on(cluster, instance) group_left(node) kubelet_node_name{job="kubelet"} > 60
        EOT
      },
      # Not Microsoft's expression: theirs joins on `pod`, which kubelet_volume_stats_* don't have, so it
      # can never fire (empty, or "many-to-many matching" with 2+ PVCs in a namespace). Note 0035.
      {
        alert           = "KubePVUsageHigh"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "Average PV usage of PVC {{ $labels.persistentvolumeclaim }} in namespace {{ $labels.namespace }} is greater than 80%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          kubelet_volume_stats_used_bytes{job="kubelet"} / kubelet_volume_stats_capacity_bytes{job="kubelet"} > .8
        EOT
      },
      {
        alert           = "KubeDeploymentReplicasMismatch"
        for             = "15m"
        keep_firing_for = "15m"
        description     = "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} in {{ $labels.cluster}} replica mismatch. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          (  kube_deployment_spec_replicas{job="kube-state-metrics"}    >  kube_deployment_status_replicas_available{job="kube-state-metrics"}) and (  changes(kube_deployment_status_replicas_updated{job="kube-state-metrics"}[10m])    ==  0)
        EOT
      },
      {
        alert           = "KubeStatefulSetReplicasMismatch"
        for             = "15m"
        keep_firing_for = "10m"
        description     = "StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} in {{ $labels.cluster}} replica mismatch. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          (  kube_statefulset_status_replicas_ready{job="kube-state-metrics"}    !=  kube_statefulset_status_replicas{job="kube-state-metrics"}) and (  changes(kube_statefulset_status_replicas_updated{job="kube-state-metrics"}[10m])    ==  0)
        EOT
      },
      {
        alert           = "KubeHpaReplicasMismatch"
        for             = "15m"
        keep_firing_for = "15m"
        description     = "Horizontal Pod Autoscaler in {{ $labels.cluster}} has not matched the desired number of replicas for longer than 15 minutes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          (kube_horizontalpodautoscaler_status_desired_replicas{job="kube-state-metrics"}  !=kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"})  and(kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}  >kube_horizontalpodautoscaler_spec_min_replicas{job="kube-state-metrics"})  and(kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}  <kube_horizontalpodautoscaler_spec_max_replicas{job="kube-state-metrics"})  and changes(kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}[15m]) == 0
        EOT
      },
      {
        alert           = "KubeHpaMaxedOut"
        for             = "15m"
        keep_firing_for = "15m"
        description     = "Horizontal Pod Autoscaler in {{ $labels.cluster}} has been running at max replicas for longer than 15 minutes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)."
        expr            = <<-EOT
          kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}  ==kube_horizontalpodautoscaler_spec_max_replicas{job="kube-state-metrics"}
        EOT
      },
    ]
  }
}

data "grafana_data_source" "managed_prometheus" {
  uid = "amw-playground"
}

data "grafana_data_source" "azure_monitor" {
  uid = "azure-monitor-oob"
}

# Same shape as Grafana's own Prometheus import (pkg/services/ngalert/prom/convert.go): the math node
# turns every returned series into 1, so a rule fires on any result and an empty result is Normal.
# One difference: exec_err_state is Error, not OK, so a failing query (AMW down, or a broken rule)
# raises DatasourceError instead of staying silent.
resource "grafana_rule_group" "kubernetes" {
  for_each         = local.kubernetes_alert_groups
  name             = each.key
  folder_uid       = grafana_folder.observability.uid
  interval_seconds = 60

  dynamic "rule" {
    for_each = each.value
    content {
      name                            = rule.value.alert
      condition                       = "threshold"
      for                             = rule.value.for
      keep_firing_for                 = rule.value.keep_firing_for
      no_data_state                   = "OK"
      exec_err_state                  = "Error"
      missing_series_evals_to_resolve = 1
      labels                          = { severity = "warning" }
      annotations                     = { description = rule.value.description }

      data {
        ref_id         = "query"
        datasource_uid = data.grafana_data_source.managed_prometheus.uid
        # Instant query: evaluated once at `to` (now-1m, the import's 1m offset so the latest samples are
        # ingested), using the newest sample of the last 5 minutes (Prometheus lookback). `from` has no
        # effect; 660 = the import's 600s default + offset, kept so the rule matches the import exactly.
        relative_time_range {
          from = 660
          to   = 60
        }
        model = jsonencode({
          datasource = { type = data.grafana_data_source.managed_prometheus.type, uid = data.grafana_data_source.managed_prometheus.uid }
          expr       = chomp(rule.value.expr)
          instant    = true
          range      = false
          refId      = "query"
        })
      }

      data {
        ref_id         = "prometheus_math"
        datasource_uid = "__expr__"
        relative_time_range {
          from = 0
          to   = 0
        }
        model = jsonencode({
          type       = "math"
          expression = "is_number($query) || is_nan($query) || is_inf($query)"
          refId      = "prometheus_math"
        })
      }

      data {
        ref_id         = "threshold"
        datasource_uid = "__expr__"
        relative_time_range {
          from = 0
          to   = 0
        }
        model = jsonencode({
          type       = "threshold"
          expression = "prometheus_math"
          conditions = [{ evaluator = { type = "gt", params = [0] } }]
          refId      = "threshold"
        })
      }
    }
  }
}

# The two platform metric rules of the same recommended set, defined as in AMBA
# (services/ContainerService/managedClusters/alerts.yaml): Average over 5 minutes, checked every 5 minutes.
locals {
  kubernetes_platform_alerts = {
    node-cpu-usage-percentage = {
      metric      = "node_cpu_usage_percentage"
      threshold   = 95
      description = "The node CPU percentage is greater than 95% for the last 5 minutes."
    }
    node-memory-working-set-percentage = {
      metric      = "node_memory_working_set_percentage"
      threshold   = 100
      description = "The node memory working set percentage is greater than 100% for the last 5 minutes."
    }
  }
}

resource "grafana_rule_group" "kubernetes_platform" {
  name             = "Platform"
  folder_uid       = grafana_folder.observability.uid
  interval_seconds = 300

  dynamic "rule" {
    for_each = local.kubernetes_platform_alerts
    content {
      name           = rule.key
      condition      = "threshold"
      no_data_state  = "OK"
      exec_err_state = "Error"
      annotations    = { description = rule.value.description }

      data {
        ref_id         = "query"
        datasource_uid = data.grafana_data_source.azure_monitor.uid
        query_type     = "Azure Monitor"
        # A series over the last 5 minutes; the reduce node averages it (AMBA: Average over PT5M).
        relative_time_range {
          from = 300
          to   = 0
        }
        model = jsonencode({
          datasource   = { type = data.grafana_data_source.azure_monitor.type, uid = data.grafana_data_source.azure_monitor.uid }
          queryType    = "Azure Monitor"
          subscription = data.terraform_remote_state.cloud.outputs.subscription_id
          azureMonitor = {
            resources = [{
              subscription    = data.terraform_remote_state.cloud.outputs.subscription_id
              resourceGroup   = data.terraform_remote_state.cloud.outputs.resource_group_name
              resourceName    = data.terraform_remote_state.cloud.outputs.aks_cluster_name
              metricNamespace = "Microsoft.ContainerService/managedClusters"
            }]
            metricNamespace = "Microsoft.ContainerService/managedClusters"
            metricName      = rule.value.metric
            aggregation     = "Average"
            timeGrain       = "PT1M"
          }
          refId = "query"
        })
      }

      data {
        ref_id         = "reduce"
        datasource_uid = "__expr__"
        relative_time_range {
          from = 0
          to   = 0
        }
        model = jsonencode({
          type       = "reduce"
          expression = "query"
          reducer    = "mean"
          settings   = { mode = "dropNN" }
          refId      = "reduce"
        })
      }

      data {
        ref_id         = "threshold"
        datasource_uid = "__expr__"
        relative_time_range {
          from = 0
          to   = 0
        }
        model = jsonencode({
          type       = "threshold"
          expression = "reduce"
          conditions = [{ evaluator = { type = "gt", params = [rule.value.threshold] } }]
          refId      = "threshold"
        })
      }
    }
  }
}

resource "grafana_contact_point" "teams" {
  name = "teams"

  teams {
    url = var.teams_alerts_webhook_url
  }
}

# Same grouping as Alertmanager's example and the old Logic App batch (note 0034). Timers are Grafana's defaults.
resource "grafana_notification_policy" "main" {
  contact_point = grafana_contact_point.teams.name
  group_by      = ["alertname", "cluster"]
}
