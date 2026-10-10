# Exercise 4: Grafana Dashboards

## Objectives

- Build effective Grafana dashboards
- Create reusable dashboard templates
- Implement dashboard as code
- Configure dashboard provisioning

## Prerequisites

- Completed Exercises 1-3
- Prometheus with metrics
- Loki with logs
- Basic PromQL knowledge

---

## Part 1: Dashboard Design Principles

### 1.1 The USE Method (Resources)

**The USE method** — for *resources*: nodes, disks, network interfaces

| | Question | Metrics |
|---|---|---|
| **Utilisation** | How busy is it? | CPU percentage · memory percentage · disk I/O bandwidth |
| **Saturation** | How much extra work is queued? | CPU run-queue length · swap usage · disk queue depth |
| **Errors** | What is failing? | Network errors · disk errors · system errors |

Saturation is the one that predicts. Utilisation at 100% is not a problem by itself — a CPU is
*meant* to be busy. A run queue that is growing means work is arriving faster than it can be done,
and that is the number that turns into user-visible latency.

### 1.2 The RED Method (Services)

**The RED method** — for *services*: anything that serves requests

| | Metric | Panel |
|---|---|---|
| **Rate** | Requests per second | Big single stat, plus a time series |
| **Errors** | Failed requests per second | Big single stat, plus a rate-of-errors graph |
| **Duration** | Latency distribution | p50, p95, p99 — never the mean |

**Layout that works**

```text
┌──── RATE ────┐  ┌─── ERRORS ───┐  ┌── DURATION ──┐    ← three stat panels,
│   req/sec    │  │   err/sec    │  │   p99 ms     │      top row, at a glance
└──────────────┘  └──────────────┘  └──────────────┘

┌────────────────────────────────────────────────────┐  ← request rate over time
└────────────────────────────────────────────────────┘

┌───── Error rate ─────┐  ┌──── Latency percentiles ────┐
└──────────────────────┘  └─────────────────────────────┘
```

**Never plot the mean latency.** A service where 99 requests take 10 ms and one takes 10 seconds has
a mean of 110 ms — a number that describes nothing that happened to anybody. USE and RED are
complements: RED tells you the service is slow, USE tells you which resource is why.

---

## Part 2: Dashboard JSON Structure

### 2.1 Basic Dashboard

```json
{
  "dashboard": {
    "id": null,
    "uid": "service-overview",
    "title": "Service Overview",
    "tags": ["kubernetes", "service"],
    "timezone": "browser",
    "schemaVersion": 38,
    "refresh": "30s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "templating": {
      "list": [
        {
          "name": "namespace",
          "type": "query",
          "datasource": "Prometheus",
          "query": "label_values(kube_pod_info, namespace)",
          "refresh": 2,
          "includeAll": true,
          "multi": true
        },
        {
          "name": "service",
          "type": "query",
          "datasource": "Prometheus",
          "query": "label_values(kube_service_info{namespace=~\"$namespace\"}, service)",
          "refresh": 2,
          "includeAll": false,
          "multi": false
        }
      ]
    },
    "panels": []
  }
}
```

### 2.2 Stat Panel

```json
{
  "type": "stat",
  "title": "Request Rate",
  "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
  "targets": [
    {
      "expr": "sum(rate(http_requests_total{namespace=\"$namespace\", service=\"$service\"}[5m]))",
      "legendFormat": "Requests/sec"
    }
  ],
  "options": {
    "reduceOptions": {
      "calcs": ["lastNotNull"],
      "fields": "",
      "values": false
    },
    "orientation": "auto",
    "textMode": "auto",
    "colorMode": "value",
    "graphMode": "area"
  },
  "fieldConfig": {
    "defaults": {
      "unit": "reqps",
      "thresholds": {
        "mode": "absolute",
        "steps": [
          {"value": null, "color": "green"},
          {"value": 1000, "color": "yellow"},
          {"value": 5000, "color": "red"}
        ]
      }
    }
  }
}
```

### 2.3 Time Series Panel

```json
{
  "type": "timeseries",
  "title": "Request Rate by Status",
  "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
  "targets": [
    {
      "expr": "sum by (status_code) (rate(http_requests_total{namespace=\"$namespace\", service=\"$service\"}[5m]))",
      "legendFormat": "{{status_code}}"
    }
  ],
  "options": {
    "tooltip": {
      "mode": "multi",
      "sort": "desc"
    },
    "legend": {
      "displayMode": "table",
      "placement": "bottom",
      "calcs": ["mean", "max", "last"]
    }
  },
  "fieldConfig": {
    "defaults": {
      "custom": {
        "drawStyle": "line",
        "lineInterpolation": "smooth",
        "fillOpacity": 10,
        "pointSize": 5,
        "lineWidth": 2,
        "stacking": {"mode": "none"}
      },
      "unit": "reqps",
      "color": {"mode": "palette-classic"}
    },
    "overrides": [
      {
        "matcher": {"id": "byRegexp", "options": "5.."},
        "properties": [{"id": "color", "value": {"mode": "fixed", "fixedColor": "red"}}]
      }
    ]
  }
}
```

### 2.4 Heatmap Panel

```json
{
  "type": "heatmap",
  "title": "Request Latency Distribution",
  "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
  "targets": [
    {
      "expr": "sum by (le) (rate(http_request_duration_seconds_bucket{namespace=\"$namespace\", service=\"$service\"}[5m]))",
      "format": "heatmap",
      "legendFormat": "{{le}}"
    }
  ],
  "options": {
    "calculate": false,
    "yAxis": {
      "axisPlacement": "left",
      "unit": "s"
    },
    "cellGap": 1,
    "color": {
      "mode": "scheme",
      "scheme": "Spectral",
      "steps": 64
    },
    "tooltip": {
      "show": true,
      "yHistogram": true
    }
  }
}
```

### 2.5 Table Panel

```json
{
  "type": "table",
  "title": "Top Endpoints by Error Rate",
  "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
  "targets": [
    {
      "expr": "topk(10, sum by (endpoint) (rate(http_requests_total{namespace=\"$namespace\", service=\"$service\", status_code=~\"5..\"}[5m])) / sum by (endpoint) (rate(http_requests_total{namespace=\"$namespace\", service=\"$service\"}[5m])))",
      "legendFormat": "{{endpoint}}",
      "instant": true,
      "format": "table"
    }
  ],
  "transformations": [
    {
      "id": "organize",
      "options": {
        "excludeByName": {"Time": true},
        "renameByName": {"Value": "Error Rate", "endpoint": "Endpoint"}
      }
    },
    {
      "id": "sortBy",
      "options": {"fields": {}, "sort": [{"field": "Error Rate", "desc": true}]}
    }
  ],
  "fieldConfig": {
    "defaults": {
      "custom": {
        "align": "auto",
        "displayMode": "auto"
      }
    },
    "overrides": [
      {
        "matcher": {"id": "byName", "options": "Error Rate"},
        "properties": [
          {"id": "unit", "value": "percentunit"},
          {"id": "custom.displayMode", "value": "color-background"},
          {"id": "thresholds", "value": {
            "mode": "absolute",
            "steps": [
              {"value": null, "color": "green"},
              {"value": 0.01, "color": "yellow"},
              {"value": 0.05, "color": "red"}
            ]
          }}
        ]
      }
    ]
  }
}
```

---

## Part 3: Dashboard Provisioning

### 3.1 ConfigMap Provisioning

```yaml
# grafana-dashboards-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  kubernetes-cluster.json: |
    {
      "dashboard": {
        "title": "Kubernetes Cluster",
        "uid": "k8s-cluster",
        "panels": [
          {
            "title": "CPU Usage by Node",
            "type": "timeseries",
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
            "targets": [
              {
                "expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                "legendFormat": "{{instance}}"
              }
            ]
          }
        ]
      }
    }
```

### 3.2 Helm Values Provisioning

```yaml
# grafana-values.yaml
grafana:
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: default
          orgId: 1
          folder: ""
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/default
        - name: kubernetes
          orgId: 1
          folder: Kubernetes
          type: file
          disableDeletion: false
          editable: false
          options:
            path: /var/lib/grafana/dashboards/kubernetes
        - name: applications
          orgId: 1
          folder: Applications
          type: file
          disableDeletion: false
          editable: false
          options:
            path: /var/lib/grafana/dashboards/applications

  dashboards:
    kubernetes:
      cluster-overview:
        gnetId: 7249
        revision: 1
        datasource: Prometheus
      node-exporter:
        gnetId: 1860
        revision: 31
        datasource: Prometheus
    applications:
      redis:
        gnetId: 763
        revision: 5
        datasource: Prometheus
```

### 3.3 Sidecar Provisioning

```yaml
# grafana-sidecar-config.yaml
grafana:
  sidecar:
    dashboards:
      enabled: true
      label: grafana_dashboard
      labelValue: "1"
      folder: /tmp/dashboards
      folderAnnotation: grafana_folder
      provider:
        foldersFromFilesStructure: true
        allowUiUpdates: true
    datasources:
      enabled: true
      label: grafana_datasource
      labelValue: "1"
```

---

## Part 4: Dashboard Templates with Grafonnet

### 4.1 Grafonnet Setup

```jsonnet
// dashboard.libsonnet
local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local statPanel = grafana.statPanel;

{
  serviceDashboard(
    title,
    namespace,
    service,
  ):: dashboard.new(
    title,
    tags=['service', 'kubernetes'],
    schemaVersion=38,
    refresh='30s',
    time_from='now-1h',
  )
  .addTemplate(
    template.datasource(
      'datasource',
      'prometheus',
      'Prometheus',
    )
  )
  .addTemplate(
    template.new(
      'namespace',
      '$datasource',
      'label_values(kube_pod_info, namespace)',
      label='Namespace',
      refresh='time',
      includeAll=true,
      multi=true,
    )
  )
  .addRow(
    row.new('Overview')
    .addPanel(
      statPanel.new(
        'Request Rate',
        datasource='$datasource',
      )
      .addTarget(
        prometheus.target(
          'sum(rate(http_requests_total{namespace=~"$namespace"}[5m]))',
          legendFormat='req/s',
        )
      )
    )
    .addPanel(
      statPanel.new(
        'Error Rate',
        datasource='$datasource',
      )
      .addTarget(
        prometheus.target(
          'sum(rate(http_requests_total{namespace=~"$namespace", status_code=~"5.."}[5m])) / sum(rate(http_requests_total{namespace=~"$namespace"}[5m]))',
          legendFormat='errors',
        )
      )
    )
  )
  .addRow(
    row.new('Latency')
    .addPanel(
      graphPanel.new(
        'Request Latency',
        datasource='$datasource',
      )
      .addTarget(
        prometheus.target(
          'histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=~"$namespace"}[5m])))',
          legendFormat='p50',
        )
      )
      .addTarget(
        prometheus.target(
          'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=~"$namespace"}[5m])))',
          legendFormat='p95',
        )
      )
      .addTarget(
        prometheus.target(
          'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=~"$namespace"}[5m])))',
          legendFormat='p99',
        )
      )
    )
  ),
}
```

### 4.2 Generate Dashboard

```bash
# Install jsonnet
brew install jsonnet

# Generate dashboard JSON
jsonnet -J vendor dashboard.jsonnet > dashboard.json

# Apply to Kubernetes
kubectl create configmap my-dashboard \
  --from-file=dashboard.json \
  -n monitoring \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl label configmap my-dashboard grafana_dashboard=1 -n monitoring
```

---

## Part 5: Advanced Panels

### 5.1 Logs Panel

```json
{
  "type": "logs",
  "title": "Application Logs",
  "gridPos": {"h": 10, "w": 24, "x": 0, "y": 20},
  "datasource": "Loki",
  "targets": [
    {
      "expr": "{namespace=\"$namespace\", app=\"$service\"} |= \"$search\"",
      "refId": "A"
    }
  ],
  "options": {
    "showTime": true,
    "showLabels": true,
    "showCommonLabels": false,
    "wrapLogMessage": true,
    "prettifyLogMessage": false,
    "enableLogDetails": true,
    "sortOrder": "Descending",
    "dedupStrategy": "none"
  }
}
```

### 5.2 Node Graph Panel

```json
{
  "type": "nodeGraph",
  "title": "Service Dependencies",
  "gridPos": {"h": 12, "w": 12, "x": 0, "y": 30},
  "datasource": "Tempo",
  "targets": [
    {
      "queryType": "serviceMap"
    }
  ],
  "options": {
    "nodes": {
      "mainStatUnit": "ms"
    },
    "edges": {
      "mainStatUnit": "r/sec"
    }
  }
}
```

### 5.3 Geomap Panel

```json
{
  "type": "geomap",
  "title": "Request Origins",
  "gridPos": {"h": 12, "w": 12, "x": 12, "y": 30},
  "targets": [
    {
      "expr": "sum by (country) (increase(http_requests_total{namespace=\"$namespace\"}[1h]))",
      "format": "table",
      "instant": true
    }
  ],
  "options": {
    "view": {
      "id": "fit"
    },
    "basemap": {
      "type": "carto",
      "config": {"theme": "auto"}
    },
    "layers": [
      {
        "type": "markers",
        "config": {
          "style": {
            "size": {"field": "Value", "min": 5, "max": 30}
          }
        }
      }
    ]
  }
}
```

---

## Part 6: Dashboard Variables

### 6.1 Variable Types

```json
{
  "templating": {
    "list": [
      {
        "name": "datasource",
        "type": "datasource",
        "query": "prometheus",
        "current": {"text": "Prometheus", "value": "Prometheus"}
      },
      {
        "name": "cluster",
        "type": "query",
        "datasource": "$datasource",
        "query": "label_values(up, cluster)",
        "refresh": 2,
        "multi": false
      },
      {
        "name": "namespace",
        "type": "query",
        "datasource": "$datasource",
        "query": "label_values(kube_namespace_labels{cluster=\"$cluster\"}, namespace)",
        "refresh": 2,
        "includeAll": true,
        "multi": true
      },
      {
        "name": "interval",
        "type": "interval",
        "query": "1m,5m,10m,30m,1h",
        "current": {"text": "5m", "value": "5m"}
      },
      {
        "name": "search",
        "type": "textbox",
        "current": {"text": "", "value": ""}
      },
      {
        "name": "show_errors",
        "type": "custom",
        "query": "true,false",
        "current": {"text": "true", "value": "true"}
      }
    ]
  }
}
```

---

## Part 7: Hands-on Challenges

### Challenge 1: RED Dashboard

Build a complete RED dashboard:
1. Create stat panels for Rate, Errors, Duration
2. Add time series for trends
3. Include heatmap for latency distribution
4. Add table for top endpoints

### Challenge 2: Multi-Cluster Dashboard

Create dashboard for multiple clusters:
1. Add cluster variable
2. Show cluster comparison
3. Aggregate metrics across clusters
4. Drill down to specific cluster

### Challenge 3: Dashboard as Code

Implement GitOps for dashboards:
1. Store dashboards in Git
2. Use Grafonnet for templates
3. CI/CD pipeline for deployment
4. Version control changes

---

## Verification Tasks

1. [ ] Created RED method dashboard
2. [ ] Implemented USE method panels
3. [ ] Configured dashboard provisioning
4. [ ] Set up template variables
5. [ ] Created reusable dashboard templates
6. [ ] Integrated logs and traces panels

---

## Key Takeaways

- Follow RED/USE methods for dashboard design
- Use variables for flexible filtering
- Provision dashboards as code
- Grafonnet enables templated dashboards
- Panel types suited for different data
- Correlation across metrics, logs, traces

---

## Next Steps

Continue to [Exercise 5: Alerting Strategies](05-alerting-strategies.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Dashboard Design Principles
- Dashboard JSON Structure
- Dashboard Provisioning
- Dashboard Templates with Grafonnet

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
