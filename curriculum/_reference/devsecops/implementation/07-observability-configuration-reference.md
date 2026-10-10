# Configuration Reference

## Prometheus Configuration

### Prometheus Stack Helm Values

The monitoring stack is deployed via the `kube-prometheus-stack` Helm chart. Key configuration sections:

```yaml
# Helm chart: kube-prometheus-stack v56.0.0
# Source: infrastructure/prometheus/prometheus-stack.yaml
prometheus:
  prometheusSpec:
    retention: 15d                    # Time-based retention
    retentionSize: 10GB               # Size-based retention cap
    resources:
      limits:
        memory: 2Gi
        cpu: "1"
      requests:
        memory: 1Gi
        cpu: 250m
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi
    # Additional scrape configs (Istio)
    additionalScrapeConfigs:
      - job_name: 'istiod'
        kubernetes_sd_configs:
          - role: endpoints
            namespaces:
              names:
                - istio-system
        relabel_configs:
          - source_labels: [__meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            action: keep
            regex: istiod;http-monitoring
      - job_name: 'istio-mesh'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
```

### ServiceMonitor Format

ServiceMonitors define Prometheus scrape targets declaratively:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{SERVICE_NAME}}
  namespace: monitoring
  labels:
    release: kube-prometheus-stack    # Required: matches Prometheus serviceMonitorSelector
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: {{SERVICE_NAME}}
  namespaceSelector:
    matchNames:
      - {{APP_NAMESPACE}}
  endpoints:
    - port: metrics                   # Must match Service port name
      interval: 30s                   # Scrape interval
      path: /metrics                  # Metrics endpoint path
      scrapeTimeout: 10s              # Optional: defaults to interval
      scheme: http                    # http or https
```

### PrometheusRule Format

Alert rules are defined as PrometheusRule CRDs:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: {{APP_NAME}}-alerts
  namespace: monitoring
  labels:
    release: kube-prometheus-stack    # Required: matches Prometheus ruleSelector
    app: kube-prometheus-stack
spec:
  groups:
    - name: {{APP_NAME}}.rules
      rules:
        - alert: AlertName
          expr: |                     # PromQL expression
            metric_name{label="value"} > threshold
          for: 5m                     # How long condition must be true
          labels:
            severity: warning         # critical | high | warning | info
            category: supply-chain    # Optional: for routing
          annotations:
            summary: "Human-readable summary"
            description: "Details: {{ $labels.instance }} value {{ $value }}"
            runbook_url: "https://{{ORG_NAME}}.io/runbooks/alert-name"
```

### Supply Chain Alert Categories

The supply chain alert system defines 8 rule groups:

| Group | Prefix | Alert Count |
|-------|--------|-------------|
| `supply-chain.image-signing` | UnsignedImage*, SignatureVerification* | 3 |
| `supply-chain.slsa-provenance` | MissingSLSA*, InsufficientSLSA*, ProvenanceVerification* | 3 |
| `supply-chain.sbom` | MissingSBOM | 1 |
| `supply-chain.vulnerabilities` | CriticalVulnerability*, HighVulnerability*, VulnerabilityCount* | 3 |
| `supply-chain.registry` | UnauthorizedRegistry, ImageWithoutDigest, BlockedImage* | 3 |
| `supply-chain.runtime-verifier` | RuntimeVerifier* | 3 |
| `supply-chain.incident-response` | IncidentResponder*, HighIncidentRate, IncidentRemediation*, QuarantinedPods* | 4 |
| `supply-chain.gatekeeper` | GatekeeperWebhook*, GatekeeperViolations*, GatekeeperAudit* | 3 |
| `supply-chain.coverage` | LowSignedImageCoverage, LowSBOMCoverage | 2 |

## Grafana Dashboard Format

Dashboards are delivered as Kubernetes ConfigMaps with the `grafana_dashboard: "1"` label:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-{{DASHBOARD_NAME}}
  namespace: monitoring
  labels:
    grafana_dashboard: "1"            # Required: triggers Grafana sidecar discovery
    app.kubernetes.io/name: grafana   # Optional: organizational label
data:
  {{DASHBOARD_NAME}}.json: |
    {
      "annotations": {"list": []},
      "editable": true,
      "fiscalYearStartMonth": 0,
      "graphTooltip": 0,              # 0=default, 1=shared crosshair, 2=shared tooltip
      "id": null,                     # Auto-assigned by Grafana
      "links": [],
      "liveNow": false,
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {"mode": "palette-classic"},
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"color": "green", "value": null},
                  {"color": "yellow", "value": 80},
                  {"color": "red", "value": 90}
                ]
              },
              "unit": "percent"       # See Grafana unit reference
            }
          },
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
          "id": 1,
          "targets": [
            {
              "expr": "promql_expression_here",
              "legendFormat": "{{label_name}}",
              "refId": "A"
            }
          ],
          "title": "Panel Title",
          "type": "stat"              # stat, gauge, timeseries, table, piechart, etc.
        }
      ],
      "refresh": "30s",
      "schemaVersion": 38,
      "tags": ["{{APP_NAME}}", "overview"],
      "templating": {
        "list": [
          {
            "datasource": "Prometheus",
            "definition": "label_values(kube_namespace_labels, namespace)",
            "name": "namespace",
            "type": "query"
          }
        ]
      },
      "time": {"from": "now-1h", "to": "now"},
      "title": "Dashboard Title",
      "uid": "unique-dashboard-id",
      "version": 1
    }
```

### Common Panel Types

| Type | Use Case | Key Options |
|------|----------|-------------|
| `stat` | Single metric display | `colorMode`, `graphMode`, `reduceOptions.calcs` |
| `gauge` | Value with threshold ranges | `showThresholdMarkers`, `showThresholdLabels` |
| `timeseries` | Time-series line/bar charts | `drawStyle`, `fillOpacity`, `stacking`, `legend.calcs` |
| `table` | Tabular data | `transformations`, `footer.reducer` |
| `piechart` | Distribution visualization | `pieType`, `displayLabels` |

### Common Units

| Unit Key | Display |
|----------|---------|
| `reqps` | req/s |
| `percent` | % |
| `percentunit` | % (0-1 range) |
| `s` | seconds |
| `bytes` | bytes (auto-scaled) |
| `short` | plain number |

## Fluent Bit Configuration

### Helm Values Structure

```yaml
# Helm chart: fluent-bit v0.43.0
# Source: infrastructure/fluent-bit/fluent-bit.yaml
resources:
  limits:
    memory: 128Mi
    cpu: 100m
  requests:
    memory: 64Mi
    cpu: 25m

serviceAccount:
  create: true
  annotations:
    # [GCP-SPECIFIC] Workload Identity annotation
    iam.gke.io/gcp-service-account: {{APP_NAME}}-fluent-bit@{{GCP_PROJECT_ID}}.iam.gserviceaccount.com

serviceMonitor:
  enabled: true
  selector:
    release: kube-prometheus-stack

config:
  service: |
    [SERVICE]
        Daemon Off
        Flush 1                       # Flush interval in seconds
        Log_Level info                # debug, info, warn, error
        Parsers_File /fluent-bit/etc/parsers.conf
        HTTP_Server On                # Enable health/metrics endpoint
        HTTP_Listen 0.0.0.0
        HTTP_Port 2020
        Health_Check On

  inputs: |
    [INPUT]
        Name tail
        Path /var/log/containers/*.log
        multiline.parser docker, cri
        Tag kube.*
        Mem_Buf_Limit 5MB             # Per-input memory buffer limit
        Skip_Long_Lines On

    [INPUT]
        Name systemd
        Tag host.*
        Systemd_Filter _SYSTEMD_UNIT=kubelet.service
        Read_From_Tail On

  filters: |
    [FILTER]
        Name kubernetes
        Match kube.*
        Merge_Log On                  # Parse JSON in log field
        Keep_Log Off                  # Drop original log field after parse
        K8S-Logging.Parser On         # Use pod annotation for parser
        K8S-Logging.Exclude On        # Use pod annotation to exclude

    [FILTER]
        Name modify
        Match *
        Add cluster {{CLUSTER_NAME}}
        Add environment {{ENVIRONMENT}}

    [FILTER]
        Name nest
        Match kube.*
        Operation lift
        Nested_under kubernetes
        Add_prefix kubernetes_

    [FILTER]
        Name grep
        Match kube.*
        Exclude kubernetes_namespace_name kube-system

  outputs: |
    # [GCP-SPECIFIC] Cloud Logging output
    [OUTPUT]
        Name stackdriver
        Match kube.*
        Resource k8s_container
        k8s_cluster_name {{CLUSTER_NAME}}
        k8s_cluster_location {{GCP_REGION}}

    # Alternative: Elasticsearch/OpenSearch output
    # [OUTPUT]
    #     Name es
    #     Match kube.*
    #     Host {{ELASTICSEARCH_HOST}}
    #     Port 9200
    #     Index {{APP_NAME}}-logs
    #     Type _doc
    #     Logstash_Format On
    #     Retry_Limit 5

  customParsers: |
    [PARSER]
        Name docker_no_time
        Format json
        Time_Keep Off
        Time_Key time
        Time_Format %Y-%m-%dT%H:%M:%S.%L

    [PARSER]
        Name json
        Format json
        Time_Key time
        Time_Format %Y-%m-%dT%H:%M:%S.%LZ

    [PARSER]
        Name syslog
        Format regex
        Regex ^(?<time>[^ ]* {1,2}[^ ]* [^ ]*) (?<host>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?(?:[^\:]*\:)? *(?<message>.*)$
        Time_Key time
        Time_Format %b %d %H:%M:%S
```

### Key Filter Chain

| Order | Filter | Purpose |
|-------|--------|---------|
| 1 | `kubernetes` | Enrich logs with pod/namespace/container metadata |
| 2 | `modify` | Add cluster name and environment tags |
| 3 | `nest` | Flatten Kubernetes metadata fields |
| 4 | `grep (Exclude)` | Drop `kube-system` namespace logs |

## Alertmanager Configuration

```yaml
# Source: infrastructure/prometheus/alertmanager-config.yaml
global:
  resolve_timeout: 5m                 # Time to wait before declaring resolved

route:
  group_by: ['alertname', 'severity', 'namespace']
  group_wait: 30s                     # Wait before sending first notification
  group_interval: 5m                  # Wait between notifications for same group
  repeat_interval: 4h                 # Wait before re-sending same alert
  receiver: 'default'                 # Fallback receiver
  routes:
    - receiver: 'critical'
      matchers:
        - severity = critical
      continue: true                  # Also send to next matching route
    - receiver: 'warning'
      matchers:
        - severity = warning

receivers:
  - name: 'default'
    # Configure webhook, Slack, or email for default alerts

  - name: 'critical'
    # PagerDuty for critical alerts
    # pagerduty_configs:
    #   - service_key: '{{PAGERDUTY_SERVICE_KEY}}'
    #     severity: 'critical'
    #     description: '{{ .GroupLabels.alertname }}'
    #     details:
    #       summary: '{{ .CommonAnnotations.summary }}'

  - name: 'warning'
    # Slack for warning alerts
    # slack_configs:
    #   - api_url: '{{SLACK_WEBHOOK_URL}}'
    #     channel: '{{SLACK_CHANNEL_ALERTS}}'
    #     title: '{{ .GroupLabels.alertname }}'
    #     text: '{{ .CommonAnnotations.description }}'

inhibit_rules:
  - source_matchers:
      - severity = critical
    target_matchers:
      - severity = warning
    equal: ['alertname', 'namespace']  # Suppress warnings when critical exists
```

### Routing Logic

```
Incoming Alert
  |
  +-- severity=critical --> 'critical' receiver (PagerDuty) --> continue=true
  |                                                              |
  +-- severity=warning  --> 'warning' receiver (Slack)           |
  |                                                              |
  +-- (default)         --> 'default' receiver <-----------------+
```

## SIEM Rules Format

### Elastic SIEM Detection Rule Format

```json
{
  "name": "Rule Name",
  "description": "What this rule detects",
  "risk_score": 73,                   // 0-100, higher = more severe
  "severity": "high",                 // critical, high, medium, low
  "type": "threshold",                // threshold, query, eql, machine_learning
  "query": "event.action:\"login_failed\"",  // KQL query
  "threshold": {
    "field": ["source.ip"],           // Aggregation field(s)
    "value": 5                        // Minimum count to trigger
  },
  "from": "now-5m",                   // Lookback window
  "interval": "5m",                   // Rule execution interval
  "enabled": true,
  "tags": ["Authentication", "Brute Force"],
  "threat": [{                        // MITRE ATT&CK mapping
    "framework": "MITRE ATT&CK",
    "tactic": {
      "id": "TA0006",
      "name": "Credential Access",
      "reference": "https://attack.mitre.org/tactics/TA0006/"
    },
    "technique": [{
      "id": "T1110",
      "name": "Brute Force",
      "reference": "https://attack.mitre.org/techniques/T1110/"
    }]
  }]
}
```

### OpenSearch SIEM Rule Format

```json
{
  "name": "Rule Name",
  "description": "What this rule detects",
  "severity": "high",
  "enabled": true,
  "schedule": {
    "period": {
      "interval": 1,                  // Execution interval
      "unit": "MINUTES"               // MINUTES, HOURS
    }
  },
  "inputs": [{
    "search": {
      "indices": ["logs-auth-*"],     // Index pattern(s) to search
      "query": {
        "size": 0,                    // 0 for aggregation-only queries
        "query": {
          "bool": {
            "must": [
              {"match": {"event.action": "login_failure"}},
              {"range": {"@timestamp": {"gte": "now-5m"}}}
            ]
          }
        },
        "aggs": {                     // Aggregation for threshold detection
          "by_field": {
            "terms": {
              "field": "source.ip",
              "min_doc_count": 10,    // Threshold
              "size": 100
            }
          }
        }
      }
    }
  }],
  "triggers": [{
    "name": "trigger_name",
    "severity": "2",                  // 1=highest, 5=lowest
    "condition": {
      "script": {
        "source": "ctx.results[0].aggregations.by_field.buckets.size() > 0",
        "lang": "painless"            // Painless scripting
      }
    },
    "actions": [{
      "name": "action_name",
      "destination_id": "security-alerts",  // Pre-configured destination
      "message_template": {
        "source": "Alert message with {{ctx.results[0].aggregations.by_field.buckets}}"
      }
    }]
  }]
}
```

### Platform SIEM Alert Rules Format

```json
{
  "rules": [
    {
      "name": "Rule Name",
      "description": "What this rule detects",
      "severity": "high",
      "query": {
        "bool": {
          "must": [{"match": {"event_type": "authentication"}}],
          "filter": [{"range": {"@timestamp": {"gte": "now-5m"}}}]
        }
      },
      "aggregation": {
        "field": "source_ip",
        "threshold": 5
      },
      "actions": ["slack", "pagerduty", "email"]
    }
  ]
}
```

## Elasticsearch / OpenSearch Configuration

### Index Templates

| Index Pattern | Use Case | Key Fields |
|--------------|----------|------------|
| `{{APP_NAME}}-logs-*` | Application logs | `@timestamp`, `message`, `level`, `service`, `namespace`, `pod`, `trace_id`, `http_method`, `http_path`, `http_status`, `duration_ms` |
| `security-events-*` | Security events | `@timestamp`, `event_type`, `severity`, `source`, `rule`, `namespace`, `user`, `action`, `outcome` |

### ILM Policies

| Policy | Hot | Warm | Cold | Delete |
|--------|-----|------|------|--------|
| App Logs | Rollover at 1d or 10GB | 7d (shrink + forcemerge) | 30d | 90d |
| Security Logs | Rollover at 1d or 5GB | 30d (shrink) | 90d | 365d |

### Cluster Sizing

| Node Role | Count | Memory | CPU | Storage |
|-----------|-------|--------|-----|---------|
| Master | 3 | 2Gi (limit), JVM 1g | 1 CPU | 10Gi |
| Data + Ingest | 2 | 4Gi (limit), JVM 2g | 2 CPU | 100Gi |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Prometheus Configuration
- Grafana Dashboard Format
- Fluent Bit Configuration
- Alertmanager Configuration

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
