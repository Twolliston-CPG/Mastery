# Exercise 6: SLOs and Error Budgets

## Objectives

- Define Service Level Objectives (SLOs)
- Implement error budget tracking
- Create SLO-based dashboards
- Configure burn rate alerting

## Prerequisites

- Completed Exercises 1-5
- Prometheus collecting application metrics
- Understanding of SRE principles

---

## Part 1: SLO Concepts

### 1.1 SLI/SLO/SLA Hierarchy

**SLI / SLO / SLA Relationship**

**SLI (Service Level Indicator)**

- What we measure
- Example: Request success rate
- Formula: successful_requests / total_requests

**SLO (Service Level Objective)**

- Internal target for SLI
- Example: 99.9% success rate over 30 days
- Creates error budget: 0.1% = ~43 minutes/month

**SLA (Service Level Agreement)**

- External commitment (contractual)
- Example: 99.5% uptime guaranteed
- Usually more lenient than SLO (buffer)

**Error Budget = 1 - SLO Target**

- 99.9% SLO = 0.1% error budget
- Per month: 30 days × 24h × 60m × 0.1% = 43.2 minutes
- Spend budget on: releases, experiments, maintenance


### 1.2 Common SLI Types

```yaml
# Availability SLI
availability:
  description: "Proportion of successful requests"
  good_events: "Requests returning non-5xx status"
  total_events: "All requests"
  formula: "sum(rate(http_requests_total{status!~'5..'}[window])) / sum(rate(http_requests_total[window]))"

# Latency SLI
latency:
  description: "Proportion of requests faster than threshold"
  good_events: "Requests completing in < 200ms"
  total_events: "All requests"
  formula: "sum(rate(http_request_duration_seconds_bucket{le='0.2'}[window])) / sum(rate(http_request_duration_seconds_count[window]))"

# Freshness SLI (for data pipelines)
freshness:
  description: "Proportion of time data is fresh"
  good_events: "Data age < 5 minutes"
  total_events: "All time windows"
  formula: "avg_over_time((time() - data_last_updated_timestamp < 300)[window:])"

# Throughput SLI
throughput:
  description: "Proportion of time meeting throughput target"
  good_events: "Time periods with > 1000 req/s capacity"
  total_events: "All time periods"
```

---

## Part 2: SLO Recording Rules

### 2.1 Basic SLO Rules

```yaml
# slo-recording-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: slo-recording-rules
  namespace: monitoring
spec:
  groups:
  - name: slo.availability
    rules:
    # Total requests
    - record: slo:http_requests:total:rate5m
      expr: |
        sum by (service, namespace) (
          rate(http_requests_total[5m])
        )

    # Error requests
    - record: slo:http_requests:errors:rate5m
      expr: |
        sum by (service, namespace) (
          rate(http_requests_total{status=~"5.."}[5m])
        )

    # Error ratio (1 - SLI)
    - record: slo:http_requests:error_ratio:rate5m
      expr: |
        slo:http_requests:errors:rate5m
        /
        slo:http_requests:total:rate5m

    # SLI value
    - record: slo:availability:ratio:rate5m
      expr: |
        1 - slo:http_requests:error_ratio:rate5m

  - name: slo.latency
    rules:
    # Requests meeting latency target (200ms)
    - record: slo:http_requests:latency_good:rate5m
      expr: |
        sum by (service, namespace) (
          rate(http_request_duration_seconds_bucket{le="0.2"}[5m])
        )

    # Total requests (for latency)
    - record: slo:http_requests:latency_total:rate5m
      expr: |
        sum by (service, namespace) (
          rate(http_request_duration_seconds_count[5m])
        )

    # Latency SLI
    - record: slo:latency:ratio:rate5m
      expr: |
        slo:http_requests:latency_good:rate5m
        /
        slo:http_requests:latency_total:rate5m
```

### 2.2 Multi-Window Recording Rules

```yaml
# slo-multiwindow-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: slo-multiwindow-rules
  namespace: monitoring
spec:
  groups:
  - name: slo.windows
    rules:
    # 5m window
    - record: slo:error_ratio:rate5m
      expr: |
        sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
        /
        sum by (service) (rate(http_requests_total[5m]))

    # 30m window
    - record: slo:error_ratio:rate30m
      expr: |
        sum by (service) (rate(http_requests_total{status=~"5.."}[30m]))
        /
        sum by (service) (rate(http_requests_total[30m]))

    # 1h window
    - record: slo:error_ratio:rate1h
      expr: |
        sum by (service) (rate(http_requests_total{status=~"5.."}[1h]))
        /
        sum by (service) (rate(http_requests_total[1h]))

    # 6h window
    - record: slo:error_ratio:rate6h
      expr: |
        sum by (service) (rate(http_requests_total{status=~"5.."}[6h]))
        /
        sum by (service) (rate(http_requests_total[6h]))

    # 1d window
    - record: slo:error_ratio:rate1d
      expr: |
        sum by (service) (rate(http_requests_total{status=~"5.."}[1d]))
        /
        sum by (service) (rate(http_requests_total[1d]))

    # 3d window
    - record: slo:error_ratio:rate3d
      expr: |
        sum by (service) (rate(http_requests_total{status=~"5.."}[3d]))
        /
        sum by (service) (rate(http_requests_total[3d]))

    # 7d window (weekly)
    - record: slo:error_ratio:rate7d
      expr: |
        sum by (service) (rate(http_requests_total{status=~"5.."}[7d]))
        /
        sum by (service) (rate(http_requests_total[7d]))

    # 30d window (monthly)
    - record: slo:error_ratio:rate30d
      expr: |
        sum by (service) (rate(http_requests_total{status=~"5.."}[30d]))
        /
        sum by (service) (rate(http_requests_total[30d]))
```

---

## Part 3: Error Budget Calculation

### 3.1 Error Budget Recording Rules

```yaml
# error-budget-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: error-budget-rules
  namespace: monitoring
spec:
  groups:
  - name: error.budget
    rules:
    # SLO target (99.9% = 0.001 error budget)
    - record: slo:target:api_gateway
      expr: 0.999

    # Error budget total (for 30d window)
    - record: slo:error_budget:total
      expr: 1 - slo:target:api_gateway
      labels:
        service: api-gateway

    # Error budget consumed (30d)
    - record: slo:error_budget:consumed:ratio
      expr: |
        slo:error_ratio:rate30d{service="api-gateway"}
        /
        (1 - 0.999)
      labels:
        slo: api-gateway-availability

    # Error budget remaining
    - record: slo:error_budget:remaining:ratio
      expr: |
        1 - slo:error_budget:consumed:ratio{slo="api-gateway-availability"}

    # Error budget remaining (minutes per month)
    - record: slo:error_budget:remaining:minutes
      expr: |
        slo:error_budget:remaining:ratio{slo="api-gateway-availability"}
        * 30 * 24 * 60 * (1 - 0.999)

    # Burn rate (how fast we're consuming budget)
    - record: slo:burn_rate:1h
      expr: |
        slo:error_ratio:rate1h{service="api-gateway"}
        /
        (1 - 0.999)

    - record: slo:burn_rate:6h
      expr: |
        slo:error_ratio:rate6h{service="api-gateway"}
        /
        (1 - 0.999)
```

### 3.2 Burn Rate Thresholds

```yaml
# burn-rate-thresholds.yaml
# Based on Google SRE book recommendations

# For 30-day window with 99.9% SLO:
# Error budget = 0.1% = 43.2 minutes

# Alert thresholds:
# | Burn Rate | Time to exhaust | Long Window | Short Window |
# |-----------|-----------------|-------------|--------------|
# | 14.4x     | 2 days          | 1h          | 5m           |
# | 6x        | 5 days          | 6h          | 30m          |
# | 3x        | 10 days         | 1d          | 2h           |
# | 1x        | 30 days         | 3d          | 6h           |

rules:
  # Fast burn (page immediately)
  - alert: SLOBurnRateCritical
    expr: |
      slo:error_ratio:rate1h{service="api-gateway"} > 14.4 * 0.001
      and
      slo:error_ratio:rate5m{service="api-gateway"} > 14.4 * 0.001
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "High SLO burn rate - will exhaust budget in 2 days"

  # Medium burn (page during business hours)
  - alert: SLOBurnRateHigh
    expr: |
      slo:error_ratio:rate6h{service="api-gateway"} > 6 * 0.001
      and
      slo:error_ratio:rate30m{service="api-gateway"} > 6 * 0.001
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "Elevated SLO burn rate - will exhaust budget in 5 days"

  # Slow burn (ticket)
  - alert: SLOBurnRateElevated
    expr: |
      slo:error_ratio:rate1d{service="api-gateway"} > 3 * 0.001
      and
      slo:error_ratio:rate2h{service="api-gateway"} > 3 * 0.001
    for: 1h
    labels:
      severity: info
    annotations:
      summary: "SLO burn rate above sustainable - will exhaust budget in 10 days"
```

---

## Part 4: SLO Dashboard

### 4.1 SLO Overview Dashboard

```json
{
  "dashboard": {
    "title": "SLO Overview",
    "uid": "slo-overview",
    "panels": [
      {
        "title": "Current SLI (Availability)",
        "type": "gauge",
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "slo:availability:ratio:rate5m{service=\"$service\"}",
            "legendFormat": "Current"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percentunit",
            "min": 0.99,
            "max": 1,
            "thresholds": {
              "steps": [
                {"value": 0, "color": "red"},
                {"value": 0.999, "color": "yellow"},
                {"value": 0.9999, "color": "green"}
              ]
            }
          }
        }
      },
      {
        "title": "Error Budget Remaining",
        "type": "gauge",
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0},
        "targets": [
          {
            "expr": "slo:error_budget:remaining:ratio{service=\"$service\"} * 100"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100,
            "thresholds": {
              "steps": [
                {"value": 0, "color": "red"},
                {"value": 25, "color": "yellow"},
                {"value": 50, "color": "green"}
              ]
            }
          }
        }
      },
      {
        "title": "Burn Rate",
        "type": "stat",
        "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "slo:burn_rate:1h{service=\"$service\"}",
            "legendFormat": "1h burn rate"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "x",
            "thresholds": {
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 1, "color": "yellow"},
                {"value": 6, "color": "orange"},
                {"value": 14.4, "color": "red"}
              ]
            }
          }
        }
      },
      {
        "title": "Time Until Budget Exhaustion",
        "type": "stat",
        "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0},
        "targets": [
          {
            "expr": "slo:error_budget:remaining:ratio{service=\"$service\"} * 30 * 24 / clamp_min(slo:burn_rate:1h{service=\"$service\"}, 0.001)",
            "legendFormat": "Hours remaining"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "h",
            "thresholds": {
              "steps": [
                {"value": 0, "color": "red"},
                {"value": 48, "color": "yellow"},
                {"value": 168, "color": "green"}
              ]
            }
          }
        }
      },
      {
        "title": "SLI Over Time",
        "type": "timeseries",
        "gridPos": {"h": 10, "w": 24, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "slo:availability:ratio:rate5m{service=\"$service\"}",
            "legendFormat": "5m SLI"
          },
          {
            "expr": "0.999",
            "legendFormat": "SLO Target (99.9%)"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percentunit",
            "min": 0.99
          }
        }
      },
      {
        "title": "Error Budget Consumption",
        "type": "timeseries",
        "gridPos": {"h": 10, "w": 24, "x": 0, "y": 18},
        "targets": [
          {
            "expr": "slo:error_budget:consumed:ratio{service=\"$service\"} * 100",
            "legendFormat": "Budget Consumed %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "max": 100
          }
        }
      }
    ]
  }
}
```

### 4.2 Multi-Service SLO Dashboard

```json
{
  "panels": [
    {
      "title": "All Services SLO Status",
      "type": "table",
      "gridPos": {"h": 12, "w": 24, "x": 0, "y": 0},
      "targets": [
        {
          "expr": "slo:availability:ratio:rate30d",
          "instant": true,
          "format": "table"
        },
        {
          "expr": "slo:error_budget:remaining:ratio",
          "instant": true,
          "format": "table"
        },
        {
          "expr": "slo:burn_rate:1h",
          "instant": true,
          "format": "table"
        }
      ],
      "transformations": [
        {
          "id": "merge"
        },
        {
          "id": "organize",
          "options": {
            "excludeByName": {"Time": true},
            "renameByName": {
              "service": "Service",
              "Value #A": "30d SLI",
              "Value #B": "Budget Remaining",
              "Value #C": "Burn Rate"
            }
          }
        }
      ],
      "fieldConfig": {
        "overrides": [
          {
            "matcher": {"id": "byName", "options": "30d SLI"},
            "properties": [
              {"id": "unit", "value": "percentunit"},
              {"id": "custom.displayMode", "value": "color-background"},
              {"id": "thresholds", "value": {
                "steps": [
                  {"value": 0, "color": "red"},
                  {"value": 0.999, "color": "yellow"},
                  {"value": 0.9999, "color": "green"}
                ]
              }}
            ]
          }
        ]
      }
    }
  ]
}
```

---

## Part 5: Sloth - SLO Generator

### 5.1 Install Sloth

```bash
# Install Sloth
kubectl apply -f https://raw.githubusercontent.com/slok/sloth/main/deploy/kubernetes/raw/sloth.yaml
```

### 5.2 Sloth SLO Definition

```yaml
# sloth-slo.yaml
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: api-gateway-slo
  namespace: monitoring
spec:
  service: "api-gateway"
  labels:
    team: platform
    tier: "1"

  slos:
    # Availability SLO
    - name: "requests-availability"
      objective: 99.9
      description: "99.9% of requests should be successful"
      sli:
        events:
          errorQuery: sum(rate(http_requests_total{service="api-gateway",status=~"5.."}[{{.window}}]))
          totalQuery: sum(rate(http_requests_total{service="api-gateway"}[{{.window}}]))
      alerting:
        name: APIGatewayAvailability
        labels:
          team: platform
        annotations:
          summary: "API Gateway availability SLO is at risk"
          runbook: "https://runbooks.example.com/api-gateway-availability"
        pageAlert:
          labels:
            severity: critical
        ticketAlert:
          labels:
            severity: warning

    # Latency SLO
    - name: "requests-latency"
      objective: 99.0
      description: "99% of requests should be faster than 200ms"
      sli:
        events:
          errorQuery: |
            sum(rate(http_request_duration_seconds_count{service="api-gateway"}[{{.window}}]))
            -
            sum(rate(http_request_duration_seconds_bucket{service="api-gateway",le="0.2"}[{{.window}}]))
          totalQuery: sum(rate(http_request_duration_seconds_count{service="api-gateway"}[{{.window}}]))
      alerting:
        name: APIGatewayLatency
        labels:
          team: platform
        annotations:
          summary: "API Gateway latency SLO is at risk"
```

### 5.3 Generated Rules

```yaml
# Sloth generates these automatically:
groups:
  - name: sloth-slo-sli-recordings-api-gateway-requests-availability
    rules:
      - record: slo:sli_error:ratio_rate5m
        expr: |
          sum(rate(http_requests_total{service="api-gateway",status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total{service="api-gateway"}[5m]))
        labels:
          sloth_service: api-gateway
          sloth_slo: requests-availability

  - name: sloth-slo-meta-recordings-api-gateway-requests-availability
    rules:
      - record: slo:objective:ratio
        expr: vector(0.999)
        labels:
          sloth_service: api-gateway
          sloth_slo: requests-availability

      - record: slo:error_budget:ratio
        expr: vector(1 - 0.999)
        labels:
          sloth_service: api-gateway
          sloth_slo: requests-availability

      - record: slo:time_period:days
        expr: vector(30)
        labels:
          sloth_service: api-gateway
          sloth_slo: requests-availability

  - name: sloth-slo-alerts-api-gateway-requests-availability
    rules:
      - alert: APIGatewayAvailabilityBurnRateCritical
        expr: |
          (
            max(slo:sli_error:ratio_rate5m{sloth_service="api-gateway",sloth_slo="requests-availability"}) > (14.4 * 0.001)
            and
            max(slo:sli_error:ratio_rate1h{sloth_service="api-gateway",sloth_slo="requests-availability"}) > (14.4 * 0.001)
          )
          or
          (
            max(slo:sli_error:ratio_rate30m{sloth_service="api-gateway",sloth_slo="requests-availability"}) > (6 * 0.001)
            and
            max(slo:sli_error:ratio_rate6h{sloth_service="api-gateway",sloth_slo="requests-availability"}) > (6 * 0.001)
          )
        labels:
          severity: critical
        for: 2m
        annotations:
          summary: "High error budget burn rate for API Gateway"
```

---

## Part 6: Hands-on Challenges

### Challenge 1: Define SLOs for Microservices

Create SLOs for a microservices application:
1. Define availability SLO (99.9%)
2. Define latency SLO (P99 < 500ms)
3. Create recording rules
4. Build error budget dashboard

### Challenge 2: Implement Burn Rate Alerting

Set up multi-window burn rate alerts:
1. Configure 4 burn rate thresholds
2. Set up page vs ticket routing
3. Test alert firing
4. Tune for your environment

### Challenge 3: SLO Reporting

Build SLO reporting system:
1. Weekly SLO reports
2. Error budget consumption trends
3. SLO breach post-mortems
4. Stakeholder dashboards

---

## Verification Tasks

1. [ ] Defined SLIs for key services
2. [ ] Created SLO recording rules
3. [ ] Implemented error budget tracking
4. [ ] Set up burn rate alerting
5. [ ] Built SLO dashboard
6. [ ] Tested alert escalation

---

## Key Takeaways

- SLIs measure service health objectively
- SLOs set customer-focused targets
- Error budgets balance reliability and velocity
- Multi-window burn rates catch issues quickly
- Automate SLO generation with tools like Sloth
- Use SLOs to drive engineering priorities

---

## Next Steps

Continue to [Exercise 7: Long-term Storage with Thanos](01-observability-stack-exercises-07-thanos-long-term.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- SLO Concepts
- SLO Recording Rules
- Error Budget Calculation
- SLO Dashboard

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
