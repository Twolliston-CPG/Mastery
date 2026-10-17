# Exercise 1: Prometheus Monitoring Setup

## Objective

Deploy and configure a production-ready Prometheus monitoring stack using kube-prometheus-stack, including custom metrics collection, alerting rules, and Grafana dashboards.

## Prerequisites

- Running Kubernetes cluster
- Helm 3 installed
- At least 8GB of cluster memory available

## Tasks

### Task 1: Install kube-prometheus-stack

```bash
# Add Prometheus community Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install with custom values
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values.yaml
```

**prometheus-values.yaml:**
```yaml
# Prometheus configuration
prometheus:
  prometheusSpec:
    replicas: 2
    retention: 15d
    retentionSize: "50GB"

    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi

    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

    # Scrape interval
    scrapeInterval: 30s
    evaluationInterval: 30s

    # External labels for multi-cluster setup
    externalLabels:
      cluster: production
      environment: prod

    # Pod anti-affinity for HA
    affinity:
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app.kubernetes.io/name: prometheus
          topologyKey: kubernetes.io/hostname

# Alertmanager configuration
alertmanager:
  alertmanagerSpec:
    replicas: 3
    storage:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

# Grafana configuration
grafana:
  replicas: 2
  adminPassword: "change-me-in-production"

  persistence:
    enabled: true
    size: 10Gi

  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Default dashboards
  defaultDashboardsEnabled: true
  defaultDashboardsTimezone: UTC

  # Additional data sources
  additionalDataSources:
  - name: Loki
    type: loki
    url: http://loki:3100
    access: proxy

# Node exporter
nodeExporter:
  enabled: true

# Kube-state-metrics
kubeStateMetrics:
  enabled: true
```

### Task 2: Create ServiceMonitor for Custom Application

```yaml
# servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-metrics
  namespace: monitoring
  labels:
    release: monitoring  # Must match Prometheus selector
spec:
  selector:
    matchLabels:
      app: myapp
  namespaceSelector:
    matchNames:
    - production
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    scheme: http
    tlsConfig:
      insecureSkipVerify: true
    relabelings:
    - sourceLabels: [__meta_kubernetes_pod_name]
      targetLabel: pod
    - sourceLabels: [__meta_kubernetes_namespace]
      targetLabel: namespace
```

### Task 3: Create PodMonitor for Sidecars

```yaml
# podmonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: envoy-sidecar
  namespace: monitoring
spec:
  selector:
    matchLabels:
      sidecar: envoy
  namespaceSelector:
    any: true
  podMetricsEndpoints:
  - port: envoy-admin
    path: /stats/prometheus
    interval: 15s
```

### Task 4: Configure Alerting Rules

```yaml
# alerting-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: application-alerts
  namespace: monitoring
  labels:
    release: monitoring
spec:
  groups:
  - name: application
    rules:
    # High error rate
    - alert: HighErrorRate
      expr: |
        sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
        /
        sum(rate(http_requests_total[5m])) by (service)
        > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate on {{ $labels.service }}"
        description: "Error rate is {{ $value | humanizePercentage }} for {{ $labels.service }}"

    # High latency
    - alert: HighLatency
      expr: |
        histogram_quantile(0.99,
          sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
        ) > 1
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "High latency on {{ $labels.service }}"
        description: "P99 latency is {{ $value | humanizeDuration }} for {{ $labels.service }}"

    # Pod not ready
    - alert: PodNotReady
      expr: |
        kube_pod_status_ready{condition="true"} == 0
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} not ready"
        description: "Pod has been not ready for more than 15 minutes"

    # Container restarts
    - alert: ContainerRestarts
      expr: |
        increase(kube_pod_container_status_restarts_total[1h]) > 5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Container {{ $labels.container }} restarting frequently"
        description: "Container has restarted {{ $value }} times in the last hour"

  - name: infrastructure
    rules:
    # Node CPU high
    - alert: NodeCPUHigh
      expr: |
        100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage on {{ $labels.instance }}"
        description: "CPU usage is {{ $value | humanize }}%"

    # Node memory high
    - alert: NodeMemoryHigh
      expr: |
        (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 85
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage on {{ $labels.instance }}"
        description: "Memory usage is {{ $value | humanize }}%"

    # Disk space low
    - alert: DiskSpaceLow
      expr: |
        (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes) * 100 > 80
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "Low disk space on {{ $labels.instance }}"
        description: "Disk usage is {{ $value | humanize }}% on {{ $labels.mountpoint }}"

    # PVC almost full
    - alert: PVCAlmostFull
      expr: |
        kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.85
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "PVC {{ $labels.persistentvolumeclaim }} almost full"
        description: "PVC is {{ $value | humanizePercentage }} full"
```

### Task 5: Configure Alertmanager Routing

```yaml
# alertmanager-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-monitoring-alertmanager
  namespace: monitoring
stringData:
  alertmanager.yaml: |
    global:
      resolve_timeout: 5m
      slack_api_url: 'https://hooks.slack.com/services/xxx/xxx/xxx'

    route:
      receiver: 'default'
      group_by: ['alertname', 'namespace', 'service']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h

      routes:
      # Critical alerts go to PagerDuty
      - match:
          severity: critical
        receiver: pagerduty
        continue: true

      # All alerts go to Slack
      - match_re:
          severity: critical|warning
        receiver: slack

    receivers:
    - name: 'default'
      webhook_configs:
      - url: 'http://alertmanager-webhook:8080/alerts'

    - name: 'slack'
      slack_configs:
      - channel: '#alerts'
        send_resolved: true
        title: '{{ template "slack.title" . }}'
        text: '{{ template "slack.text" . }}'

    - name: 'pagerduty'
      pagerduty_configs:
      - service_key: 'your-pagerduty-service-key'
        send_resolved: true

    inhibit_rules:
    - source_match:
        severity: 'critical'
      target_match:
        severity: 'warning'
      equal: ['alertname', 'namespace']
```

### Task 6: Create Custom Grafana Dashboard

```yaml
# grafana-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  custom-dashboard.json: |
    {
      "dashboard": {
        "title": "Application Overview",
        "uid": "app-overview",
        "panels": [
          {
            "title": "Request Rate",
            "type": "graph",
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
            "targets": [
              {
                "expr": "sum(rate(http_requests_total[5m])) by (service)",
                "legendFormat": "{{ service }}"
              }
            ]
          },
          {
            "title": "Error Rate",
            "type": "graph",
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) by (service) / sum(rate(http_requests_total[5m])) by (service) * 100",
                "legendFormat": "{{ service }}"
              }
            ]
          },
          {
            "title": "P99 Latency",
            "type": "graph",
            "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8},
            "targets": [
              {
                "expr": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))",
                "legendFormat": "{{ service }}"
              }
            ]
          }
        ]
      }
    }
```

## Validation

```bash
# Check Prometheus is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Access Prometheus UI
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# Access Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# Default credentials: admin / <password from values>

# Check targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'

# Check alerts
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts'
```

## Success Criteria

- [ ] Prometheus stack deployed with 2 replicas
- [ ] Alertmanager deployed with 3 replicas
- [ ] Grafana accessible with dashboards
- [ ] ServiceMonitors discovering targets
- [ ] Custom alerting rules active
- [ ] Alertmanager routing configured
- [ ] Metrics persisted to storage

## Next Exercise

Continue to [Exercise 2: Logging with Loki](01-observability-stack-exercises-02-loki-logging.md) to set up centralized logging.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Install kube-prometheus-stack
- Create ServiceMonitor for Custom Application
- Create PodMonitor for Sidecars
- Configure Alerting Rules

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Kubernetes schedules the pod."* |
| ✓ | *"The scheduler watches for pods with no `nodeName`, filters nodes by predicates, scores the survivors, and writes `nodeName` into the pod spec. The kubelet on that node is watching the API for pods bound to it, and starts the containers."* |

**Trace it:** `kubectl apply -f pod.yaml` → a running container. Name every component that acts, in order, and what each one writes.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — one weekend, and "the control plane" stops being a word.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#kubernetes)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
