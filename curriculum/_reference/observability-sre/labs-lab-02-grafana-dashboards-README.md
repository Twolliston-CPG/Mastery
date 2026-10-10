# Lab 02: Grafana Dashboards

## Overview
Build professional Grafana dashboards with advanced visualizations, variables, and dashboard-as-code practices using the metrics from Lab 01.

## Prerequisites
- Completed Lab 01 (Prometheus Fundamentals)
- Docker and Docker Compose installed
- Understanding of PromQL basics
- Metrics flowing from applications

## Learning Objectives
- Design effective dashboards following RED/USE methods
- Create dynamic dashboards with template variables
- Implement dashboard-as-code with Grafonnet
- Configure data source provisioning
- Build reusable panel library

## Lab Environment

Continuing from Lab 01, ensure all services are running:

```bash
cd prometheus-lab
docker-compose up -d

# Verify Grafana is accessible
curl -s http://localhost:3000/api/health | jq
```

---

## Part 1: Guided Exercises

### Exercise 1.1: Data Source Configuration

**Objective:** Configure Prometheus as a Grafana data source using provisioning.

**Step 1:** Create provisioning directory structure.

```bash
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards
```

**Step 2:** Create data source provisioning file.

```yaml
# grafana/provisioning/datasources/prometheus.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      httpMethod: POST
      manageAlerts: true
      prometheusType: Prometheus
      prometheusVersion: "2.45.0"
      cacheLevel: 'High'
      disableRecordingRules: false
      incrementalQueryOverlapWindow: 10m
      exemplarTraceIdDestinations:
        - name: traceID
          datasourceUid: tempo

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: false
    jsonData:
      maxLines: 1000
```

**Step 3:** Create dashboard provisioning file.

```yaml
# grafana/provisioning/dashboards/default.yml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: 'DevOps Academy'
    folderUid: 'devops-academy'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards/json
```

**Step 4:** Restart Grafana to apply provisioning.

```bash
docker-compose restart grafana

# Verify data source via API
curl -s -u admin:admin http://localhost:3000/api/datasources | jq '.[].name'
```

**Verification:**
- [ ] Prometheus data source appears in Grafana
- [ ] Data source test shows "Success"
- [ ] Dashboard provider folder is created

---

### Exercise 1.2: API Service Dashboard (RED Method)

**Objective:** Create a dashboard following the RED method for request-driven services.

**Step 1:** Create dashboard JSON structure.

```bash
mkdir -p grafana/provisioning/dashboards/json
```

```json
// grafana/provisioning/dashboards/json/api-service.json
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 1,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "collapsed": false,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "panels": [],
      "title": "Overview",
      "type": "row"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 0.99
              }
            ]
          },
          "unit": "percentunit"
        }
      },
      "gridPos": {
        "h": 4,
        "w": 4,
        "x": 0,
        "y": 1
      },
      "id": 2,
      "options": {
        "colorMode": "value",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "expr": "1 - (sum(rate(api_requests_total{status=~\"5..\"}[$__rate_interval])) / sum(rate(api_requests_total[$__rate_interval])))",
          "legendFormat": "Availability"
        }
      ],
      "title": "Availability",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "unit": "reqps"
        }
      },
      "gridPos": {
        "h": 4,
        "w": 4,
        "x": 4,
        "y": 1
      },
      "id": 3,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "targets": [
        {
          "expr": "sum(rate(api_requests_total[$__rate_interval]))",
          "legendFormat": "RPS"
        }
      ],
      "title": "Request Rate",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 0.1
              },
              {
                "color": "red",
                "value": 0.5
              }
            ]
          },
          "unit": "s"
        }
      },
      "gridPos": {
        "h": 4,
        "w": 4,
        "x": 8,
        "y": 1
      },
      "id": 4,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum by (le) (rate(api_request_duration_seconds_bucket[$__rate_interval])))",
          "legendFormat": "P95"
        }
      ],
      "title": "P95 Latency",
      "type": "stat"
    }
  ],
  "refresh": "10s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": ["api", "red-method"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "API Service - RED Method",
  "uid": "api-red-method",
  "version": 1
}
```

**Step 2:** Create the dashboard using Grafana API (interactive method).

```bash
# Login to Grafana UI at http://localhost:3000 (admin/admin)
# Navigate to: Dashboards > New > New Dashboard
```

**Step 3:** Add Rate panel (requests per second).

In Grafana UI, add a new panel with:

- **Panel Type:** Time series
- **Title:** Request Rate
- **Query:**
```promql
sum by (endpoint) (rate(api_requests_total[$__rate_interval]))
```
- **Legend:** `{{endpoint}}`
- **Unit:** requests/sec (reqps)

**Step 4:** Add Error panel.

- **Panel Type:** Time series
- **Title:** Error Rate
- **Query:**
```promql
sum by (endpoint) (rate(api_requests_total{status=~"5.."}[$__rate_interval]))
/
sum by (endpoint) (rate(api_requests_total[$__rate_interval]))
```
- **Legend:** `{{endpoint}}`
- **Unit:** Percent (0.0-1.0)
- **Thresholds:** 0=green, 0.01=yellow, 0.05=red

**Step 5:** Add Duration panel (latency percentiles).

- **Panel Type:** Time series
- **Title:** Request Duration
- **Queries:**
```promql
# P50
histogram_quantile(0.50, sum by (le) (rate(api_request_duration_seconds_bucket[$__rate_interval])))

# P95
histogram_quantile(0.95, sum by (le) (rate(api_request_duration_seconds_bucket[$__rate_interval])))

# P99
histogram_quantile(0.99, sum by (le) (rate(api_request_duration_seconds_bucket[$__rate_interval])))
```
- **Legends:** P50, P95, P99
- **Unit:** seconds (s)

**Verification:**
- [ ] Dashboard displays all three RED metrics
- [ ] Data is updating in real-time
- [ ] Color thresholds work correctly

---

### Exercise 1.3: Infrastructure Dashboard (USE Method)

**Objective:** Create infrastructure monitoring dashboard using USE method.

**Step 1:** Create USE method panels for CPU.

```promql
# Utilization - CPU busy percentage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Saturation - CPU runqueue length
node_load1 / count by (instance) (node_cpu_seconds_total{mode="idle"})

# Errors - CPU throttling (if available)
rate(container_cpu_cfs_throttled_periods_total[5m])
/
rate(container_cpu_cfs_periods_total[5m])
```

**Step 2:** Create USE method panels for Memory.

```promql
# Utilization - Memory used percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Saturation - Swap usage
(node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes) / node_memory_SwapTotal_bytes * 100

# Errors - OOM kills
increase(node_vmstat_oom_kill[5m])
```

**Step 3:** Create USE method panels for Disk.

```promql
# Utilization - Disk space used
(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100

# Saturation - Disk I/O queue
rate(node_disk_io_time_weighted_seconds_total[5m])

# Errors - Disk errors
rate(node_disk_io_errors_total[5m])
```

**Step 4:** Create USE method panels for Network.

```promql
# Utilization - Network bandwidth
rate(node_network_receive_bytes_total{device!="lo"}[5m]) * 8
rate(node_network_transmit_bytes_total{device!="lo"}[5m]) * 8

# Saturation - Network drops
rate(node_network_receive_drop_total{device!="lo"}[5m])
rate(node_network_transmit_drop_total{device!="lo"}[5m])

# Errors - Network errors
rate(node_network_receive_errs_total{device!="lo"}[5m])
rate(node_network_transmit_errs_total{device!="lo"}[5m])
```

**Verification:**
- [ ] All USE metrics displayed for each resource
- [ ] Gauges show appropriate ranges
- [ ] Network graphs show bidirectional traffic

---

### Exercise 1.4: Template Variables

**Objective:** Add dynamic template variables for flexible dashboards.

**Step 1:** Create environment variable.

In dashboard settings > Variables, add:

```yaml
Name: environment
Label: Environment
Type: Query
Query: label_values(api_requests_total, env)
Refresh: On time range change
Multi-value: true
Include All option: true
```

**Step 2:** Create endpoint variable.

```yaml
Name: endpoint
Label: Endpoint
Type: Query
Query: label_values(api_requests_total{env=~"$environment"}, endpoint)
Refresh: On time range change
Multi-value: true
Include All option: true
```

**Step 3:** Create interval variable.

```yaml
Name: interval
Label: Interval
Type: Interval
Values: 1m,5m,10m,30m,1h
Auto option: true
Auto min interval: 1m
```

**Step 4:** Update queries to use variables.

```promql
# Request rate with variables
sum by (endpoint) (
  rate(api_requests_total{
    env=~"$environment",
    endpoint=~"$endpoint"
  }[$interval])
)

# Error rate with variables
sum by (endpoint) (
  rate(api_requests_total{
    env=~"$environment",
    endpoint=~"$endpoint",
    status=~"5.."
  }[$interval])
)
/
sum by (endpoint) (
  rate(api_requests_total{
    env=~"$environment",
    endpoint=~"$endpoint"
  }[$interval])
)
```

**Step 5:** Add ad-hoc filters.

```yaml
Name: Filters
Type: Ad hoc filters
Data source: Prometheus
```

**Verification:**
- [ ] Variables appear in dashboard toolbar
- [ ] Changing variables updates all panels
- [ ] Multi-select works with regex matching

---

### Exercise 1.5: Annotations and Alerts

**Objective:** Add annotations and integrate Grafana alerting.

**Step 1:** Create annotation query for deployments.

In dashboard settings > Annotations, add:

```yaml
Name: Deployments
Data source: Prometheus
Query: changes(deployment_info{app="api"}[1m]) > 0
Tag keys: version
```

**Step 2:** Create Grafana alert rule.

In Alerting > Alert rules, create:

```yaml
Rule name: API High Error Rate
Folder: DevOps Academy
Group: API Alerts

Query A:
  sum(rate(api_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(api_requests_total[5m]))

Condition:
  WHEN last() OF A IS ABOVE 0.05

Evaluation:
  Evaluate every: 1m
  For: 5m

Labels:
  severity: warning
  service: api

Annotations:
  Summary: High error rate detected
  Description: Error rate is {{ $values.A.Value | printf "%.2f" }}%
```

**Step 3:** Create contact point.

```yaml
Name: DevOps Team
Type: Email
Addresses: devops@example.com

# Or Slack
Name: DevOps Slack
Type: Slack
Webhook URL: https://hooks.slack.com/services/xxx
Channel: #alerts
```

**Step 4:** Create notification policy.

```yaml
Root policy:
  Default contact point: DevOps Team
  Group by: [alertname, service]
  Group wait: 30s
  Group interval: 5m
  Repeat interval: 4h

Nested policies:
  - Match: severity=critical
    Contact point: DevOps Slack
    Continue: true
```

**Verification:**
- [ ] Annotations appear on graphs
- [ ] Alerts fire when thresholds exceeded
- [ ] Notifications delivered to correct channels

---

## Part 2: Semi-Guided Exercises

### Exercise 2.1: Dashboard-as-Code with Grafonnet

**Objective:** Generate dashboards programmatically using Grafonnet.

**Requirements:**
1. Install Jsonnet and Grafonnet
2. Create a dashboard library with reusable components
3. Generate the API service dashboard
4. Implement CI pipeline for dashboard deployment

**Hints:**
- Use `jsonnet-bundler` for dependency management
- Grafonnet provides builder patterns for panels
- Export dashboards as JSON for provisioning

**Starting Point:**
```jsonnet
local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local prometheus = grafana.prometheus;
local graphPanel = grafana.graphPanel;

dashboard.new(
  'API Service Dashboard',
  tags=['api', 'generated'],
  schemaVersion=18,
)
.addPanel(
  graphPanel.new(
    'Request Rate',
    datasource='Prometheus',
  )
  .addTarget(
    prometheus.target(
      'sum(rate(api_requests_total[$__rate_interval]))',
      legendFormat='Requests/s',
    )
  ),
  gridPos={x: 0, y: 0, w: 12, h: 8},
)
```

**Expected Deliverables:**
- [ ] Jsonnet project structure with Grafonnet
- [ ] Reusable panel library
- [ ] Generated dashboard JSON
- [ ] CI/CD pipeline for deployment

---

### Exercise 2.2: Multi-Cluster Dashboard

**Objective:** Create a dashboard that aggregates metrics from multiple clusters.

**Requirements:**
1. Configure multiple Prometheus data sources (one per cluster)
2. Create mixed data source queries
3. Implement cluster comparison views
4. Add drill-down links to cluster-specific dashboards

**Hints:**
- Use the `datasource` variable type
- Mixed queries allow multiple data sources in one panel
- Data links enable contextual navigation

**Expected Deliverables:**
- [ ] Multi-cluster overview dashboard
- [ ] Cluster comparison panels
- [ ] Navigation links to cluster details
- [ ] Variable for data source selection

---

### Exercise 2.3: SLO Dashboard

**Objective:** Build an SLO tracking dashboard with error budget visualization.

**Requirements:**
1. Calculate SLO compliance over multiple windows (7d, 28d, 90d)
2. Display error budget remaining
3. Show burn rate trends
4. Implement traffic light indicators

**Hints:**
- Recording rules simplify SLO calculations
- Use gauge panels for budget display
- State timeline shows compliance history

**Expected Deliverables:**
- [ ] SLO compliance gauges
- [ ] Error budget burn-down chart
- [ ] Multi-window compliance view
- [ ] Historical compliance timeline

---

### Exercise 2.4: Log Integration Panel

**Objective:** Integrate logs with metrics panels for unified troubleshooting.

**Requirements:**
1. Configure Loki data source
2. Create panels mixing metrics and logs
3. Implement log context from metric spikes
4. Add correlation links between panels

**Hints:**
- Loki queries use LogQL
- Data links can pass time ranges
- Explore view supports split pane

**Expected Deliverables:**
- [ ] Mixed metrics/logs dashboard
- [ ] Click-through from metrics to logs
- [ ] Log panel with filters
- [ ] Correlation by trace ID (if available)

---

## Part 3: Challenge Exercises

### Challenge 3.1: Executive Dashboard

**Objective:** Create a business-focused dashboard for executives and stakeholders.

**Scenario:**
The CTO wants a dashboard that shows:
- Overall platform health at a glance
- Business impact of incidents
- Cost metrics (if available)
- Trend analysis for capacity planning

**Requirements:**
1. Design for non-technical audience
2. Use appropriate visualizations (no raw numbers)
3. Include business context and SLAs
4. Enable drill-down for technical teams

**Constraints:**
- Maximum 6 panels on main view
- Must load in under 3 seconds
- Mobile-friendly layout
- Automated PDF export for reports

**Success Criteria:**
- [ ] Dashboard communicates health in 5 seconds
- [ ] No technical jargon visible on main view
- [ ] Trend lines show 30-day history
- [ ] Click reveals technical details
- [ ] Weekly report automation configured

---

### Challenge 3.2: Capacity Planning Dashboard

**Objective:** Build a dashboard for infrastructure capacity planning.

**Scenario:**
The platform team needs to forecast resource requirements based on:
- Historical growth trends
- Seasonal patterns
- Deployment schedules
- Current utilization rates

**Requirements:**
1. Implement trend analysis with linear regression
2. Show resource headroom calculations
3. Create "what-if" scenario panels
4. Add growth rate projections

**Constraints:**
- Predictions should extend 90 days
- Must account for weekend/weekday patterns
- Alert when capacity threshold approaching
- Export data for spreadsheet analysis

**Success Criteria:**
- [ ] Growth trend lines with R² values
- [ ] Capacity exhaustion date predictions
- [ ] Confidence intervals displayed
- [ ] Actionable recommendations panel
- [ ] Data export functionality

---

### Challenge 3.3: On-Call Dashboard Suite

**Objective:** Create a suite of dashboards optimized for on-call engineers.

**Scenario:**
On-call engineers need dashboards for:
- Immediate triage during incidents
- Root cause investigation
- Status page updates
- Handoff documentation

**Requirements:**
1. Incident overview with severity context
2. Service dependency visualization
3. Recent changes correlation
4. Customer impact assessment

**Constraints:**
- Must work on mobile devices
- Load time under 2 seconds
- Dark theme for night shifts
- Keyboard navigation support

**Success Criteria:**
- [ ] Incident triage dashboard with alert context
- [ ] Service topology with health status
- [ ] Change log integration
- [ ] Mobile-optimized layout
- [ ] One-click incident creation

---

## Dashboard Export

Save your dashboards for future use:

```bash
# Export via API
curl -s -u admin:admin \
  "http://localhost:3000/api/dashboards/uid/api-red-method" | \
  jq '.dashboard' > exported-dashboard.json

# Import via API
curl -X POST -H "Content-Type: application/json" \
  -u admin:admin \
  -d @exported-dashboard.json \
  "http://localhost:3000/api/dashboards/db"
```

## Cleanup

```bash
# Remove generated files
rm -rf grafana/provisioning/dashboards/json/*.json

# Restart to reset
docker-compose restart grafana
```

## Additional Resources

- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
- [Grafonnet Documentation](https://github.com/grafana/grafonnet)
- [RED Method](https://www.weave.works/blog/the-red-method-key-metrics-for-microservices-architecture/)
- [USE Method](https://www.brendangregg.com/usemethod.html)
- [Dashboard Design Patterns](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)

## Next Lab
Continue to [Lab 03: Alertmanager](../lab-03-alertmanager/README.md) to implement sophisticated alerting.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Dashboard Export
- 1: Data Source Configuration
- 2: API Service Dashboard (RED Method)
- 3: Infrastructure Dashboard (USE Method)

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Prometheus monitors the service."* |
| ✓ | *"Prometheus discovers targets from the Kubernetes API, applies relabelling rules, scrapes `/metrics` over HTTP on an interval, and appends samples to a local TSDB. Nothing is pushed — so a target missing from a dashboard is a service-discovery problem, not an application one."* |

**Trace it:** A latency regression → a phone ringing. Name each hop: sample, rule evaluation, alert state transition, routing, notification — and where each one can silently stop.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [SRE Workbook ch. 5, *Alerting on SLOs*](https://sre.google/workbook/alerting-on-slos/) — free, and the best thing written on why static thresholds page you for nothing.
Full list per domain: [`SOURCES.md`](../SOURCES.md#observability-sre)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
