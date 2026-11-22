# Ported unchanged from https://aka.ms/azureprometheus-recommendedmetricalerts
# (Azure/prometheus-collector GeneratedMonitoringArtifacts/Default/recommendedMetricAlerts.json).

resource "azurerm_monitor_alert_prometheus_rule_group" "kubernetes_alerts_cluster" {
  name                = "KubernetesAlert-RecommendedMetricAlerts${azurerm_kubernetes_cluster.main.name}-Cluster-level"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  cluster_name        = azurerm_kubernetes_cluster.main.name
  description         = "Kubernetes Alert RuleGroup-RecommendedMetricAlerts - 0.1"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [azurerm_monitor_workspace.main.id, azurerm_kubernetes_cluster.main.id]

  rule {
    alert       = "KubeCPUQuotaOvercommit"
    enabled     = true
    for         = "PT5M"
    severity    = 3
    expression  = <<EOF
sum(min without(resource) (kube_resourcequota{job="kube-state-metrics", type="hard", resource=~"(cpu|requests.cpu)"}))  /sum(kube_node_status_allocatable{resource="cpu", job="kube-state-metrics"})  > 1.5
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Cluster {{ $labels.cluster}} has overcommitted CPU resource requests for Namespaces. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeMemoryQuotaOvercommit"
    enabled     = true
    for         = "PT5M"
    severity    = 3
    expression  = <<EOF
sum(min without(resource) (kube_resourcequota{job="kube-state-metrics", type="hard", resource=~"(memory|requests.memory)"}))  /sum(kube_node_status_allocatable{resource="memory", job="kube-state-metrics"})  > 1.5
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Cluster {{ $labels.cluster}} has overcommitted memory resource requests for Namespaces. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeContainerOOMKilledCount"
    enabled     = true
    for         = "PT5M"
    severity    = 4
    expression  = <<EOF
sum by (cluster,container,controller,namespace)(kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} * on(cluster,namespace,pod) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)")) > 0
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Number of OOM killed containers is greater than 0. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeClientErrors"
    enabled     = true
    for         = "PT15M"
    severity    = 3
    expression  = <<EOF
(sum(rate(rest_client_requests_total{code=~"5.."}[5m])) by (cluster, instance, job, namespace)  / sum(rate(rest_client_requests_total[5m])) by (cluster, instance, job, namespace)) > 0.01
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance }}' is experiencing {{ $value | humanizePercentage }} errors. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubePersistentVolumeFillingUp"
    enabled     = true
    for         = "PT60M"
    severity    = 4
    expression  = <<EOF
kubelet_volume_stats_available_bytes{job="kubelet"}/kubelet_volume_stats_capacity_bytes{job="kubelet"} < 0.15 and kubelet_volume_stats_used_bytes{job="kubelet"} > 0 and predict_linear(kubelet_volume_stats_available_bytes{job="kubelet"}[6h], 4 * 24 * 3600) < 0 unless on(namespace, persistentvolumeclaim) kube_persistentvolumeclaim_access_mode{ access_mode="ReadOnlyMany"} == 1 unless on(namespace, persistentvolumeclaim) kube_persistentvolumeclaim_labels{label_excluded_from_alerts="true"} == 1
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Based on recent sampling, the PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in Namespace {{ $labels.namespace }} is expected to fill up within four days. Currently {{ $value | humanizePercentage }} is available. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT15M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubePersistentVolumeInodesFillingUp"
    enabled     = true
    for         = "PT15M"
    severity    = 4
    expression  = <<EOF
kubelet_volume_stats_inodes_free{job="kubelet"} / kubelet_volume_stats_inodes{job="kubelet"} < 0.03
EOF
    labels      = { severity = "warning" }
    annotations = { description = "The PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in Namespace {{ $labels.namespace }} only has {{ $value | humanizePercentage }} free inodes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubePersistentVolumeErrors"
    enabled     = true
    for         = "PT05M"
    severity    = 4
    expression  = <<EOF
kube_persistentvolume_status_phase{phase=~"Failed|Pending",job="kube-state-metrics"} > 0
EOF
    labels      = { severity = "warning" }
    annotations = { description = "The persistent volume {{ $labels.persistentvolume }} has status {{ $labels.phase }}. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeContainerWaiting"
    enabled     = true
    for         = "PT60M"
    severity    = 3
    expression  = <<EOF
sum by (namespace, pod, container, cluster) (kube_pod_container_status_waiting_reason{job="kube-state-metrics"}) > 0
EOF
    labels      = { severity = "warning" }
    annotations = { description = "pod/{{ $labels.pod }} in namespace {{ $labels.namespace }} on container {{ $labels.container}} has been in waiting state for longer than 1 hour. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeDaemonSetNotScheduled"
    enabled     = true
    for         = "PT15M"
    severity    = 3
    expression  = <<EOF
kube_daemonset_status_desired_number_scheduled{job="kube-state-metrics"} - kube_daemonset_status_current_number_scheduled{job="kube-state-metrics"} > 0
EOF
    labels      = { severity = "warning" }
    annotations = { description = "{{ $value }} Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset }} are not scheduled. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeDaemonSetMisScheduled"
    enabled     = true
    for         = "PT15M"
    severity    = 3
    expression  = <<EOF
kube_daemonset_status_number_misscheduled{job="kube-state-metrics"} > 0
EOF
    labels      = { severity = "warning" }
    annotations = { description = "{{ $value }} Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset }} are running where they are not supposed to run. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeQuotaAlmostFull"
    enabled     = true
    for         = "PT15M"
    severity    = 3
    expression  = <<EOF
kube_resourcequota{job="kube-state-metrics", type="used"}  / ignoring(instance, job, type)(kube_resourcequota{job="kube-state-metrics", type="hard"} > 0)  > 0.9 < 1
EOF
    labels      = { severity = "warning" }
    annotations = { description = "{{ $value | humanizePercentage }} usage of {{ $labels.resource }} in namespace {{ $labels.namespace }} in {{ $labels.cluster}}. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "kubernetes_alerts_node" {
  name                = "KubernetesAlert-RecommendedMetricAlerts${azurerm_kubernetes_cluster.main.name}-Node-level"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  cluster_name        = azurerm_kubernetes_cluster.main.name
  description         = "Kubernetes Alert RuleGroup-RecommendedMetricAlerts - 0.1"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [azurerm_monitor_workspace.main.id, azurerm_kubernetes_cluster.main.id]

  rule {
    alert       = "KubeNodeUnreachable"
    enabled     = true
    for         = "PT15M"
    severity    = 3
    expression  = <<EOF
(kube_node_spec_taint{job="kube-state-metrics",key="node.kubernetes.io/unreachable",effect="NoSchedule"} unless ignoring(key,value) kube_node_spec_taint{job="kube-state-metrics",key=~"ToBeDeletedByClusterAutoscaler|cloud.google.com/impending-node-termination|aws-node-termination-handler/spot-itn"}) == 1
EOF
    labels      = { severity = "warning" }
    annotations = { description = "{{ $labels.node }} in {{ $labels.cluster}} is unreachable and some workloads may be rescheduled. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/node-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeNodeReadinessFlapping"
    enabled     = true
    for         = "PT15M"
    severity    = 3
    expression  = <<EOF
sum(changes(kube_node_status_condition{status="true",condition="Ready"}[15m])) by (cluster, node) > 2
EOF
    labels      = { severity = "warning" }
    annotations = { description = "The readiness status of node {{ $labels.node }} in {{ $labels.cluster}} has changed more than 2 times in the last 15 minutes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/node-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeNodeDiskUsageHigh"
    enabled     = true
    for         = "PT15M"
    severity    = 3
    expression  = <<EOF
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100) > 80
EOF
    labels      = { severity = "warning" }
    annotations = { description = "The disk usage on node {{ $labels.instance }} in {{ $labels.job }} has exceeded 80% and current usage is {{ $value | humanizePercentage }}%). For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/node-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "kubernetes_alerts_pod" {
  name                = "KubernetesAlert-RecommendedMetricAlerts${azurerm_kubernetes_cluster.main.name}-Pod-level"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  cluster_name        = azurerm_kubernetes_cluster.main.name
  description         = "Kubernetes Alert RuleGroup-RecommendedMetricAlerts - 0.1"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [azurerm_monitor_workspace.main.id, azurerm_kubernetes_cluster.main.id]

  rule {
    alert       = "KubePodCrashLooping"
    enabled     = true
    for         = "PT15M"
    severity    = 4
    expression  = <<EOF
max_over_time(kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff", job="kube-state-metrics"}[5m]) >= 1
EOF
    labels      = { severity = "warning" }
    annotations = { description = "{{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container }}) in {{ $labels.cluster}} is restarting {{ printf \"%.2f\" $value }} / second. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeJobStale"
    enabled     = true
    for         = "PT360M"
    severity    = 4
    expression  = <<EOF
sum by(namespace,cluster)(kube_job_spec_completions{job="kube-state-metrics"}) - sum by(namespace,cluster)(kube_job_status_succeeded{job="kube-state-metrics"})  > 0 
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Number of stale jobs older than six hours is greater than 0. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT15M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubePodContainerRestart"
    enabled     = true
    for         = "PT15M"
    severity    = 4
    expression  = <<EOF
sum by (namespace, controller, container, cluster)(increase(kube_pod_container_status_restarts_total{job="kube-state-metrics"}[1h])* on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)")) > 0
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Pod container restarted in the last 1 hour. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubePodReadyStateLow"
    enabled     = true
    for         = "PT5M"
    severity    = 4
    expression  = <<EOF
sum by (cluster,namespace,deployment)(kube_deployment_status_replicas_ready) / sum by (cluster,namespace,deployment)(kube_deployment_spec_replicas) <.8 or sum by (cluster,namespace,daemonset)(kube_daemonset_status_number_ready) / sum by (cluster,namespace,daemonset)(kube_daemonset_status_desired_number_scheduled) <.8 
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Ready state of pods is less than 80%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT15M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubePodFailedState"
    enabled     = true
    for         = "PT5M"
    severity    = 4
    expression  = <<EOF
sum by (cluster, namespace, controller) (kube_pod_status_phase{phase="failed"} * on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)"))  > 0
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Number of pods in failed state are greater than 0. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT15M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubePodNotReadyByController"
    enabled     = true
    for         = "PT15M"
    severity    = 3
    expression  = <<EOF
sum by (namespace, controller, cluster) (max by(namespace, pod, cluster) (kube_pod_status_phase{job="kube-state-metrics", phase=~"Pending|Unknown"}  ) * on(namespace, pod, cluster) group_left(controller)label_replace(kube_pod_owner,"controller","$1","owner_name","(.*)")) > 0
EOF
    labels      = { severity = "warning" }
    annotations = { description = "{{ $labels.namespace }}/{{ $labels.pod }} in {{ $labels.cluster}} by controller is not ready. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeStatefulSetGenerationMismatch"
    enabled     = true
    for         = "PT15M"
    severity    = 3
    expression  = <<EOF
kube_statefulset_status_observed_generation{job="kube-state-metrics"} != kube_statefulset_metadata_generation{job="kube-state-metrics"}
EOF
    labels      = { severity = "warning" }
    annotations = { description = "StatefulSet generation for {{ $labels.namespace }}/{{ $labels.statefulset }} does not match, this indicates that the StatefulSet has failed but has not been rolled back. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeJobFailed"
    enabled     = true
    for         = "PT15M"
    severity    = 3
    expression  = <<EOF
kube_job_failed{job="kube-state-metrics"}  > 0
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Job {{ $labels.namespace }}/{{ $labels.job_name }} in {{ $labels.cluster}} failed to complete. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeContainerAverageCPUHigh"
    enabled     = true
    for         = "PT5M"
    severity    = 4
    expression  = <<EOF
sum (rate(container_cpu_usage_seconds_total{image!="", container!="POD"}[5m])) by (pod,cluster,container,namespace) / sum(container_spec_cpu_quota{image!="", container!="POD"}/container_spec_cpu_period{image!="", container!="POD"}) by (pod,cluster,container,namespace) > .95
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Average CPU usage per container is greater than 95%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT15M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeContainerAverageMemoryHigh"
    enabled     = true
    for         = "PT10M"
    severity    = 4
    expression  = <<EOF
avg by (namespace, controller, container, cluster)(((container_memory_working_set_bytes{container!="", image!="", container!="POD"} / on(namespace,cluster,pod,container) group_left kube_pod_container_resource_limits{resource="memory", node!=""})*on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)")) > .95)
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Average Memory usage per container is greater than 95%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeletPodStartUpLatencyHigh"
    enabled     = true
    for         = "PT10M"
    severity    = 4
    expression  = <<EOF
histogram_quantile(0.99, sum(rate(kubelet_pod_worker_duration_seconds_bucket{job="kubelet"}[5m])) by (cluster, instance, le)) * on(cluster, instance) group_left(node) kubelet_node_name{job="kubelet"} > 60
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Kubelet Pod startup latency is too high. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubePVUsageHigh"
    enabled     = true
    for         = "PT15M"
    severity    = 3
    expression  = <<EOF
avg by (namespace, controller, container, cluster)(((kubelet_volume_stats_used_bytes{job="kubelet"} / on(namespace,cluster,pod,container) group_left kubelet_volume_stats_capacity_bytes{job="kubelet"}) * on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)"))) > .8
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Average PV usage on pod {{ $labels.pod }} in container {{ $labels.container }}  is greater than 80%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeDeploymentReplicasMismatch"
    enabled     = true
    for         = "PT15M"
    severity    = 4
    expression  = <<EOF
(  kube_deployment_spec_replicas{job="kube-state-metrics"}    >  kube_deployment_status_replicas_available{job="kube-state-metrics"}) and (  changes(kube_deployment_status_replicas_updated{job="kube-state-metrics"}[10m])    ==  0)
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} in {{ $labels.cluster}} replica mismatch. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT15M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeStatefulSetReplicasMismatch"
    enabled     = true
    for         = "PT15M"
    severity    = 4
    expression  = <<EOF
(  kube_statefulset_status_replicas_ready{job="kube-state-metrics"}    !=  kube_statefulset_status_replicas{job="kube-state-metrics"}) and (  changes(kube_statefulset_status_replicas_updated{job="kube-state-metrics"}[10m])    ==  0)
EOF
    labels      = { severity = "warning" }
    annotations = { description = "StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} in {{ $labels.cluster}} replica mismatch. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeHpaReplicasMismatch"
    enabled     = true
    for         = "PT15M"
    severity    = 4
    expression  = <<EOF
(kube_horizontalpodautoscaler_status_desired_replicas{job="kube-state-metrics"}  !=kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"})  and(kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}  >kube_horizontalpodautoscaler_spec_min_replicas{job="kube-state-metrics"})  and(kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}  <kube_horizontalpodautoscaler_spec_max_replicas{job="kube-state-metrics"})  and changes(kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}[15m]) == 0
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Horizontal Pod Autoscaler in {{ $labels.cluster}} has not matched the desired number of replicas for longer than 15 minutes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT15M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }

  rule {
    alert       = "KubeHpaMaxedOut"
    enabled     = true
    for         = "PT15M"
    severity    = 4
    expression  = <<EOF
kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}  ==kube_horizontalpodautoscaler_spec_max_replicas{job="kube-state-metrics"}
EOF
    labels      = { severity = "warning" }
    annotations = { description = "Horizontal Pod Autoscaler in {{ $labels.cluster}} has been running at max replicas for longer than 15 minutes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts)." }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT15M"
    }

    action {
      action_group_id = azurerm_monitor_action_group.teams.id
    }
  }
}

# The two platform metric rules from the same recommended set. Microsoft's templates don't include them (portal toggle only),
# so the definitions come from AMBA: services/ContainerService/managedClusters/alerts.yaml.
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

resource "azurerm_monitor_metric_alert" "kubernetes_platform" {
  for_each            = local.kubernetes_platform_alerts
  name                = "${each.key}-${azurerm_kubernetes_cluster.main.name}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_kubernetes_cluster.main.id]
  description         = each.value.description
  severity            = 3
  window_size         = "PT5M"
  frequency           = "PT5M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = each.value.metric
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = each.value.threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.teams.id
  }
}
