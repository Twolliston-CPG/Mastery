# Lab 07: SRE Practices - SLOs and Error Budgets

## Overview
Implement Site Reliability Engineering practices including Service Level Objectives (SLOs), Error Budgets, and reliability-focused operations.

## Prerequisites
- Completed Labs 01-06
- Understanding of SRE principles
- Prometheus and Grafana running
- Application metrics available

## Learning Objectives
- Define and implement Service Level Indicators (SLIs)
- Create Service Level Objectives (SLOs)
- Calculate and track Error Budgets
- Implement multi-window, multi-burn-rate alerting
- Build SLO dashboards and reports

## Lab Environment

Uses the environment from previous labs with additional SLO configuration:

```yaml
# Additional services for SLO management
services:
  sloth:
    image: slok/sloth:v0.11.0
    container_name: sloth
    volumes:
      - ./sloth:/sloth
    command: ["generate", "-i", "/sloth/slos.yml", "-o", "/sloth/output"]

  # SLO dashboard generator (Pyrra alternative)
  # Can also use Google's SLO Generator or Nobl9
```

---

## Part 1: Guided Exercises

### Exercise 1.1: Defining Service Level Indicators

**Objective:** Create meaningful SLIs for different service types.

**Step 1:** Understand the SLI types.

```markdown
# SLI Types by Service Category

## Request-Driven Services (APIs)
- Availability: successful_requests / total_requests
- Latency: requests_below_threshold / total_requests
- Quality: valid_responses / total_responses

## Data Processing Services
- Freshness: records_updated_on_time / total_records
- Correctness: valid_outputs / total_outputs
- Throughput: actual_throughput / expected_throughput

## Storage Services
- Durability: data_intact / total_data
- Availability: successful_operations / total_operations
- Latency: operations_below_threshold / total_operations
```

**Step 2:** Create Prometheus recording rules for SLIs.

```yaml
# prometheus/rules/sli_recording_rules.yml
groups:
  - name: sli_api_availability
    interval: 30s
    rules:
      # Total requests in the window
      - record: sli:api_requests:rate5m
        expr: sum(rate(api_requests_total[5m]))

      # Successful requests (non-5xx)
      - record: sli:api_requests_success:rate5m
        expr: sum(rate(api_requests_total{status!~"5.."}[5m]))

      # Error requests (5xx)
      - record: sli:api_requests_error:rate5m
        expr: sum(rate(api_requests_total{status=~"5.."}[5m]))

      # Availability SLI (success ratio)
      - record: sli:api_availability:ratio
        expr: |
          sli:api_requests_success:rate5m
          /
          sli:api_requests:rate5m

  - name: sli_api_latency
    interval: 30s
    rules:
      # Total requests for latency calculation
      - record: sli:api_latency_requests:rate5m
        expr: sum(rate(api_request_duration_seconds_count[5m]))

      # Requests under latency threshold (200ms)
      - record: sli:api_latency_good:rate5m
        expr: |
          sum(rate(api_request_duration_seconds_bucket{le="0.2"}[5m]))

      # Latency SLI (good requests ratio)
      - record: sli:api_latency:ratio
        expr: |
          sli:api_latency_good:rate5m
          /
          sli:api_latency_requests:rate5m

  - name: sli_combined
    interval: 30s
    rules:
      # Combined SLI (both availability AND latency must be good)
      - record: sli:api_combined:ratio
        expr: |
          (
            sli:api_requests_success:rate5m
            *
            (sli:api_latency_good:rate5m / sli:api_latency_requests:rate5m)
          )
          /
          sli:api_requests:rate5m
```

**Step 3:** Create SLIs for different services.

```yaml
# prometheus/rules/sli_services.yml
groups:
  - name: sli_payment_service
    rules:
      # Payment success rate
      - record: sli:payment_success:ratio
        expr: |
          sum(rate(payment_transactions_total{status="success"}[5m]))
          /
          sum(rate(payment_transactions_total[5m]))

      # Payment latency (< 2 seconds)
      - record: sli:payment_latency:ratio
        expr: |
          sum(rate(payment_duration_seconds_bucket{le="2"}[5m]))
          /
          sum(rate(payment_duration_seconds_count[5m]))

  - name: sli_data_pipeline
    rules:
      # Data freshness (processed within 5 minutes)
      - record: sli:pipeline_freshness:ratio
        expr: |
          sum(rate(pipeline_records_processed_on_time_total[5m]))
          /
          sum(rate(pipeline_records_total[5m]))

      # Data correctness
      - record: sli:pipeline_correctness:ratio
        expr: |
          sum(rate(pipeline_records_valid_total[5m]))
          /
          sum(rate(pipeline_records_total[5m]))
```

**Step 4:** Reload Prometheus and verify SLIs.

```bash
# Reload Prometheus
curl -X POST http://localhost:9090/-/reload

# Query SLIs
curl -s 'http://localhost:9090/api/v1/query?query=sli:api_availability:ratio' | jq '.data.result[0].value[1]'
curl -s 'http://localhost:9090/api/v1/query?query=sli:api_latency:ratio' | jq '.data.result[0].value[1]'
```

**Verification:**
- [ ] SLI recording rules loaded
- [ ] SLI values between 0 and 1
- [ ] Multiple SLI types implemented

---

### Exercise 1.2: Creating Service Level Objectives

**Objective:** Define SLOs with appropriate targets and windows.

**Step 1:** Create SLO definitions.

```yaml
# sloth/slos.yml
version: "prometheus/v1"
service: "api-gateway"
labels:
  owner: "platform-team"
  tier: "critical"

slos:
  - name: "availability"
    objective: 99.9  # 99.9% availability
    description: "API should return successful responses 99.9% of the time"
    sli:
      events:
        error_query: sum(rate(api_requests_total{status=~"5.."}[{{.window}}]))
        total_query: sum(rate(api_requests_total[{{.window}}]))
    alerting:
      name: APIAvailability
      labels:
        category: availability
      annotations:
        summary: "API availability SLO is at risk"
      page_alert:
        labels:
          severity: critical
      ticket_alert:
        labels:
          severity: warning

  - name: "latency"
    objective: 99.0  # 99% of requests under 200ms
    description: "99% of API requests should complete within 200ms"
    sli:
      events:
        error_query: |
          sum(rate(api_request_duration_seconds_count[{{.window}}]))
          -
          sum(rate(api_request_duration_seconds_bucket{le="0.2"}[{{.window}}]))
        total_query: sum(rate(api_request_duration_seconds_count[{{.window}}]))
    alerting:
      name: APILatency
      labels:
        category: latency
```

**Step 2:** Calculate SLO compliance and error budgets.

```yaml
# prometheus/rules/slo_rules.yml
groups:
  - name: slo_api_availability
    rules:
      # SLO target
      - record: slo:api_availability:target
        expr: 0.999  # 99.9%

      # Error budget total (in ratio)
      - record: slo:api_availability:error_budget_total
        expr: 1 - slo:api_availability:target  # 0.001 = 0.1%

      # Current error rate (1 - SLI)
      - record: slo:api_availability:error_rate
        expr: 1 - sli:api_availability:ratio

      # Error budget remaining (can be negative if overspent)
      - record: slo:api_availability:error_budget_remaining
        expr: |
          1 - (
            slo:api_availability:error_rate
            /
            slo:api_availability:error_budget_total
          )

  - name: slo_api_latency
    rules:
      # SLO target
      - record: slo:api_latency:target
        expr: 0.99  # 99%

      # Error budget total
      - record: slo:api_latency:error_budget_total
        expr: 1 - slo:api_latency:target  # 0.01 = 1%

      # Current error rate
      - record: slo:api_latency:error_rate
        expr: 1 - sli:api_latency:ratio

      # Error budget remaining
      - record: slo:api_latency:error_budget_remaining
        expr: |
          1 - (
            slo:api_latency:error_rate
            /
            slo:api_latency:error_budget_total
          )

  # Time-window based error budget tracking
  - name: slo_error_budget_windows
    rules:
      # 30-day error budget consumption
      - record: slo:api_availability:error_budget_consumed:30d
        expr: |
          1 - (
            sum_over_time(sli:api_availability:ratio[30d])
            /
            (30 * 24 * 12)  # 30 days of 5-minute samples
          )
          /
          (1 - 0.999)

      # 7-day error budget consumption
      - record: slo:api_availability:error_budget_consumed:7d
        expr: |
          1 - (
            sum_over_time(sli:api_availability:ratio[7d])
            /
            (7 * 24 * 12)
          )
          /
          (1 - 0.999)
```

**Step 3:** Translate SLO to concrete numbers.

```markdown
# SLO Translation Table

## 99.9% Availability SLO (30-day window)
| Metric | Value |
|--------|-------|
| Allowed downtime per month | 43.2 minutes |
| Allowed downtime per week | 10.08 minutes |
| Allowed downtime per day | 1.44 minutes |
| Error budget (ratio) | 0.001 |

## 99% Latency SLO
| Metric | Value |
|--------|-------|
| Allowed slow requests | 1 in 100 |
| At 1000 req/min | 10 slow requests/min allowed |
| At 10000 req/min | 100 slow requests/min allowed |
```

**Verification:**
- [ ] SLO targets defined
- [ ] Error budget calculations correct
- [ ] Time-window tracking working

---

### Exercise 1.3: Multi-Window, Multi-Burn-Rate Alerting

**Objective:** Implement alerting that balances detection speed with false positive rate.

**Step 1:** Understand burn rate concepts.

```markdown
# Burn Rate Alerting

## Burn Rate Definition
Burn Rate = (Error Rate) / (Error Budget Rate)

If burn rate = 1: Consuming budget at exactly the expected rate
If burn rate = 2: Consuming budget 2x faster than allowed
If burn rate = 14.4: Will exhaust 30-day budget in 2 days

## Multi-Window Strategy
| Alert Type | Long Window | Short Window | Burn Rate | Budget Consumed |
|------------|-------------|--------------|-----------|-----------------|
| Page       | 1h          | 5m           | 14.4      | 2% in 1h        |
| Page       | 6h          | 30m          | 6         | 5% in 6h        |
| Ticket     | 3d          | 6h           | 1         | 10% in 3d       |
```

**Step 2:** Create burn rate recording rules.

```yaml
# prometheus/rules/slo_burn_rates.yml
groups:
  - name: slo_burn_rates_availability
    rules:
      # 5-minute error rate
      - record: slo:api_availability:error_rate:5m
        expr: 1 - sli:api_availability:ratio

      # 30-minute error rate
      - record: slo:api_availability:error_rate:30m
        expr: |
          1 - (
            sum(increase(api_requests_total{status!~"5.."}[30m]))
            /
            sum(increase(api_requests_total[30m]))
          )

      # 1-hour error rate
      - record: slo:api_availability:error_rate:1h
        expr: |
          1 - (
            sum(increase(api_requests_total{status!~"5.."}[1h]))
            /
            sum(increase(api_requests_total[1h]))
          )

      # 6-hour error rate
      - record: slo:api_availability:error_rate:6h
        expr: |
          1 - (
            sum(increase(api_requests_total{status!~"5.."}[6h]))
            /
            sum(increase(api_requests_total[6h]))
          )

      # 3-day error rate
      - record: slo:api_availability:error_rate:3d
        expr: |
          1 - (
            sum(increase(api_requests_total{status!~"5.."}[3d]))
            /
            sum(increase(api_requests_total[3d]))
          )

      # Burn rates (error_rate / error_budget)
      - record: slo:api_availability:burn_rate:5m
        expr: slo:api_availability:error_rate:5m / 0.001

      - record: slo:api_availability:burn_rate:30m
        expr: slo:api_availability:error_rate:30m / 0.001

      - record: slo:api_availability:burn_rate:1h
        expr: slo:api_availability:error_rate:1h / 0.001

      - record: slo:api_availability:burn_rate:6h
        expr: slo:api_availability:error_rate:6h / 0.001

      - record: slo:api_availability:burn_rate:3d
        expr: slo:api_availability:error_rate:3d / 0.001
```

**Step 3:** Create multi-window alerting rules.

```yaml
# prometheus/rules/slo_alerts.yml
groups:
  - name: slo_alerts_availability
    rules:
      # Page alert: Fast burn - 2% budget in 1 hour
      # Triggers when: 1h burn rate > 14.4 AND 5m burn rate > 14.4
      - alert: APIAvailabilityBudgetFastBurn
        expr: |
          slo:api_availability:burn_rate:1h > 14.4
          and
          slo:api_availability:burn_rate:5m > 14.4
        for: 2m
        labels:
          severity: critical
          slo: api-availability
          window: 1h
        annotations:
          summary: "API availability burning error budget too fast"
          description: "Current burn rate: {{ $value | printf \"%.1f\" }}x. At this rate, 30-day budget will be exhausted in {{ printf \"%.1f\" (div 30 $value) }} days."
          runbook_url: "https://wiki.example.com/runbooks/slo-budget-burn"

      # Page alert: Medium burn - 5% budget in 6 hours
      - alert: APIAvailabilityBudgetMediumBurn
        expr: |
          slo:api_availability:burn_rate:6h > 6
          and
          slo:api_availability:burn_rate:30m > 6
        for: 5m
        labels:
          severity: critical
          slo: api-availability
          window: 6h
        annotations:
          summary: "API availability SLO at risk"
          description: "Burning error budget at {{ $value | printf \"%.1f\" }}x rate over 6 hours"

      # Ticket alert: Slow burn - 10% budget in 3 days
      - alert: APIAvailabilityBudgetSlowBurn
        expr: |
          slo:api_availability:burn_rate:3d > 1
          and
          slo:api_availability:burn_rate:6h > 1
        for: 30m
        labels:
          severity: warning
          slo: api-availability
          window: 3d
        annotations:
          summary: "API availability SLO degrading"
          description: "Elevated error rate over 3 days. Investigate trends."

      # Budget exhausted alert
      - alert: APIAvailabilityBudgetExhausted
        expr: slo:api_availability:error_budget_remaining < 0
        for: 5m
        labels:
          severity: critical
          slo: api-availability
        annotations:
          summary: "API availability error budget exhausted"
          description: "Error budget is {{ $value | printf \"%.1f\" }}% remaining (negative means overspent)"
```

**Step 4:** Reload and verify alerts.

```bash
# Reload Prometheus
curl -X POST http://localhost:9090/-/reload

# Check alert rules
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[] | select(.name | contains("slo")) | .rules[] | .name'

# Check current burn rates
curl -s 'http://localhost:9090/api/v1/query?query=slo:api_availability:burn_rate:1h' | jq
```

**Verification:**
- [ ] All burn rate recording rules created
- [ ] Alert rules loaded
- [ ] Alerts fire at appropriate thresholds

---

### Exercise 1.4: SLO Dashboard

**Objective:** Create a comprehensive SLO dashboard in Grafana.

**Step 1:** Create dashboard JSON.

```json
{
  "dashboard": {
    "title": "SLO Dashboard - API Gateway",
    "tags": ["slo", "api"],
    "panels": [
      {
        "title": "Current SLO Status",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
        "targets": [{
          "expr": "sli:api_availability:ratio * 100",
          "legendFormat": "Availability"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 99},
                {"color": "green", "value": 99.9}
              ]
            }
          }
        }
      },
      {
        "title": "Error Budget Remaining",
        "type": "gauge",
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
        "targets": [{
          "expr": "slo:api_availability:error_budget_remaining * 100",
          "legendFormat": "Budget"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": -50,
            "max": 100,
            "thresholds": {
              "steps": [
                {"color": "red", "value": -50},
                {"color": "yellow", "value": 0},
                {"color": "green", "value": 50}
              ]
            }
          }
        }
      },
      {
        "title": "Burn Rate (1h)",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 12, "y": 0},
        "targets": [{
          "expr": "slo:api_availability:burn_rate:1h",
          "legendFormat": "Burn Rate"
        }],
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 1},
                {"color": "red", "value": 14.4}
              ]
            }
          }
        }
      },
      {
        "title": "SLI Over Time",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
        "targets": [
          {
            "expr": "sli:api_availability:ratio * 100",
            "legendFormat": "Availability SLI"
          },
          {
            "expr": "sli:api_latency:ratio * 100",
            "legendFormat": "Latency SLI"
          },
          {
            "expr": "99.9",
            "legendFormat": "Availability Target (99.9%)"
          },
          {
            "expr": "99",
            "legendFormat": "Latency Target (99%)"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 90,
            "max": 100
          }
        }
      },
      {
        "title": "Error Budget Burn Down",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
        "targets": [{
          "expr": "slo:api_availability:error_budget_remaining * 100",
          "legendFormat": "Budget Remaining"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percent"
          }
        }
      },
      {
        "title": "Burn Rate Comparison",
        "type": "timeseries",
        "gridPos": {"h": 6, "w": 24, "x": 0, "y": 12},
        "targets": [
          {"expr": "slo:api_availability:burn_rate:5m", "legendFormat": "5m"},
          {"expr": "slo:api_availability:burn_rate:1h", "legendFormat": "1h"},
          {"expr": "slo:api_availability:burn_rate:6h", "legendFormat": "6h"},
          {"expr": "14.4", "legendFormat": "Critical Threshold"}
        ]
      }
    ]
  }
}
```

**Step 2:** Create dashboard via API.

```bash
# Import dashboard
curl -X POST -H "Content-Type: application/json" \
  -u admin:admin \
  -d @slo-dashboard.json \
  http://localhost:3000/api/dashboards/db
```

**Verification:**
- [ ] Dashboard created successfully
- [ ] All panels showing data
- [ ] Thresholds working correctly

---

### Exercise 1.5: SLO Reporting

**Objective:** Generate SLO compliance reports.

**Step 1:** Create weekly SLO report query.

```promql
# Weekly availability compliance
avg_over_time(sli:api_availability:ratio[7d]) * 100

# Weekly latency compliance
avg_over_time(sli:api_latency:ratio[7d]) * 100

# Error budget consumption this week
(1 - avg_over_time(sli:api_availability:ratio[7d])) / 0.001 * 100

# Time below SLO target
count_over_time((sli:api_availability:ratio < 0.999)[7d:5m])
* 5  # minutes below target

# Incidents (SLO violations)
count_over_time((slo:api_availability:burn_rate:1h > 14.4)[7d:5m])
```

**Step 2:** Create reporting script.

```python
#!/usr/bin/env python3
# slo_report.py

import requests
from datetime import datetime, timedelta
import json

PROMETHEUS_URL = "http://localhost:9090"

def query_prometheus(query: str, time: datetime = None) -> float:
    """Execute a Prometheus query and return the result."""
    params = {"query": query}
    if time:
        params["time"] = time.isoformat() + "Z"

    response = requests.get(f"{PROMETHEUS_URL}/api/v1/query", params=params)
    data = response.json()

    if data["status"] == "success" and data["data"]["result"]:
        return float(data["data"]["result"][0]["value"][1])
    return None

def generate_slo_report(service: str, slo_name: str, target: float, window_days: int = 7):
    """Generate an SLO compliance report."""

    # Calculate compliance
    compliance = query_prometheus(
        f'avg_over_time(sli:{service}_{slo_name}:ratio[{window_days}d]) * 100'
    )

    # Calculate error budget consumption
    error_budget_total = 1 - target
    error_rate = (100 - compliance) / 100 if compliance else None
    budget_consumed = (error_rate / error_budget_total * 100) if error_rate else None

    # Count violations
    violations = query_prometheus(
        f'count_over_time((sli:{service}_{slo_name}:ratio < {target})[{window_days}d:5m])'
    )

    report = {
        "service": service,
        "slo": slo_name,
        "target": f"{target * 100:.2f}%",
        "window": f"{window_days} days",
        "report_date": datetime.now().isoformat(),
        "results": {
            "compliance": f"{compliance:.3f}%" if compliance else "N/A",
            "target_met": compliance >= target * 100 if compliance else False,
            "error_budget_consumed": f"{budget_consumed:.1f}%" if budget_consumed else "N/A",
            "violation_count": int(violations) if violations else 0,
            "downtime_minutes": int(violations) * 5 if violations else 0
        }
    }

    return report

if __name__ == "__main__":
    # Generate reports
    reports = [
        generate_slo_report("api", "availability", 0.999, 7),
        generate_slo_report("api", "latency", 0.99, 7),
    ]

    print("=" * 60)
    print("WEEKLY SLO REPORT")
    print("=" * 60)

    for report in reports:
        print(f"\nService: {report['service']}")
        print(f"SLO: {report['slo']}")
        print(f"Target: {report['target']}")
        print(f"Window: {report['window']}")
        print("-" * 40)
        print(f"Compliance: {report['results']['compliance']}")
        print(f"Target Met: {'✓' if report['results']['target_met'] else '✗'}")
        print(f"Error Budget Consumed: {report['results']['error_budget_consumed']}")
        print(f"Violation Count: {report['results']['violation_count']}")
        print(f"Downtime: {report['results']['downtime_minutes']} minutes")

    # Export as JSON
    with open("slo_report.json", "w") as f:
        json.dump(reports, f, indent=2)
    print(f"\nReport saved to slo_report.json")
```

**Step 3:** Run the report.

```bash
python3 slo_report.py
```

**Verification:**
- [ ] Report generates correctly
- [ ] Compliance calculations accurate
- [ ] Export working

---

## Part 2: Semi-Guided Exercises

### Exercise 2.1: SLO for Batch Processing

**Objective:** Create SLOs for a data pipeline.

**Requirements:**
1. Define freshness SLI (data processed within deadline)
2. Define correctness SLI (valid outputs)
3. Define throughput SLI (processing rate)
4. Create appropriate alerts

**Hints:**
- Freshness often uses histogram of processing times
- Correctness needs validation metrics
- Consider business hours vs 24/7

---

### Exercise 2.2: Composite SLOs

**Objective:** Create SLOs that depend on multiple services.

**Requirements:**
1. Define end-to-end SLI across service chain
2. Handle partial failures
3. Weight services by criticality
4. Alert on composite degradation

---

### Exercise 2.3: SLO-Based Capacity Planning

**Objective:** Use SLO data for capacity decisions.

**Requirements:**
1. Calculate required capacity to meet SLO
2. Project SLO compliance under load
3. Create headroom recommendations
4. Build capacity planning dashboard

---

### Exercise 2.4: Error Budget Policy

**Objective:** Implement automated error budget policies.

**Requirements:**
1. Define policy actions (deploy freeze, etc.)
2. Automate policy enforcement
3. Create escalation paths
4. Document override procedures

---

## Part 3: Challenge Exercises

### Challenge 3.1: Organization-Wide SLO Platform

**Objective:** Build a platform for managing SLOs across many services.

**Requirements:**
1. Self-service SLO definition
2. Automated rule generation
3. Centralized reporting
4. SLO inheritance (team -> service)

**Success Criteria:**
- [ ] 10+ services with SLOs
- [ ] Automated weekly reports
- [ ] Self-service portal

---

### Challenge 3.2: Predictive SLO Management

**Objective:** Predict SLO violations before they occur.

**Requirements:**
1. Trend analysis for SLI degradation
2. Anomaly detection
3. Proactive alerting
4. Recommendations engine

---

### Challenge 3.3: Customer-Facing SLO Dashboard

**Objective:** Create external SLO visibility for customers.

**Requirements:**
1. Customer-specific SLO views
2. Historical compliance data
3. Incident correlation
4. Credit/SLA impact calculation

---

## Cleanup

```bash
# Remove SLO-specific rules
rm prometheus/rules/sli_*.yml prometheus/rules/slo_*.yml
docker-compose restart prometheus
```

## Additional Resources

- [Google SRE Book](https://sre.google/sre-book/service-level-objectives/)
- [Sloth - SLO Generator](https://github.com/slok/sloth)
- [Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
- [Error Budget Policy](https://sre.google/workbook/error-budget-policy/)

## Next Lab
Continue to [Lab 08: Incident Management](../lab-08-incident-management/README.md) to implement incident response procedures.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Request-Driven Services (APIs)
- Data Processing Services
- Storage Services
- 9% Availability SLO (30-day window)

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
