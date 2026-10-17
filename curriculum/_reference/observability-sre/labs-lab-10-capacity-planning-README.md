# Lab 10: Capacity Planning

## Overview
Implement data-driven capacity planning using historical metrics, growth projections, and load testing to ensure systems can handle expected demand.

## Prerequisites
- Prometheus with historical data
- Grafana dashboards
- Understanding of system resources
- Basic statistics knowledge

## Learning Objectives
- Analyze historical resource utilization
- Create growth trend projections
- Implement load testing for capacity validation
- Build capacity planning dashboards
- Design scaling strategies

## Lab Environment

Uses existing Prometheus/Grafana stack with additional tools:

```yaml
services:
  k6:
    image: grafana/k6:latest
    volumes:
      - ./k6-scripts:/scripts
    command: ["run", "/scripts/load-test.js"]

  locust:
    image: locustio/locust
    ports:
      - "8089:8089"
    volumes:
      - ./locust:/mnt/locust
    command: ["-f", "/mnt/locust/locustfile.py", "--host=http://api:8080"]
```

---

## Part 1: Guided Exercises

### Exercise 1.1: Historical Utilization Analysis

**Objective:** Analyze historical resource usage patterns.

**Step 1:** Create queries for utilization analysis.

```promql
# Average CPU utilization over 30 days
avg_over_time(
  (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))[30d:1h]
) * 100

# Peak CPU utilization over 30 days
max_over_time(
  (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))[30d:1h]
) * 100

# Memory utilization trend
avg_over_time(
  (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)[30d:1h]
) * 100

# Storage growth rate (bytes per day)
deriv(node_filesystem_size_bytes{mountpoint="/"}[30d]) * 86400

# Request rate trend
avg_over_time(sum(rate(api_requests_total[5m]))[30d:1h])
```

**Step 2:** Create capacity analysis script.

```python
# capacity_analysis.py
import requests
import numpy as np
from datetime import datetime, timedelta
from dataclasses import dataclass

@dataclass
class CapacityMetrics:
    avg_utilization: float
    peak_utilization: float
    p95_utilization: float
    growth_rate: float  # per day
    current_headroom: float

class CapacityAnalyzer:
    def __init__(self, prometheus_url: str):
        self.prometheus_url = prometheus_url

    def query_range(self, query: str, start: datetime, end: datetime, step: str = "1h"):
        """Query Prometheus for a time range."""
        response = requests.get(
            f"{self.prometheus_url}/api/v1/query_range",
            params={
                "query": query,
                "start": start.isoformat() + "Z",
                "end": end.isoformat() + "Z",
                "step": step
            }
        )
        return response.json()

    def analyze_cpu(self, days: int = 30) -> CapacityMetrics:
        """Analyze CPU capacity over the specified period."""
        end = datetime.utcnow()
        start = end - timedelta(days=days)

        query = '(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100'
        result = self.query_range(query, start, end)

        values = [float(v[1]) for v in result['data']['result'][0]['values']]

        return CapacityMetrics(
            avg_utilization=np.mean(values),
            peak_utilization=np.max(values),
            p95_utilization=np.percentile(values, 95),
            growth_rate=self._calculate_growth_rate(values, days),
            current_headroom=100 - np.percentile(values, 95)
        )

    def analyze_memory(self, days: int = 30) -> CapacityMetrics:
        """Analyze memory capacity."""
        end = datetime.utcnow()
        start = end - timedelta(days=days)

        query = '(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100'
        result = self.query_range(query, start, end)

        values = [float(v[1]) for v in result['data']['result'][0]['values']]

        return CapacityMetrics(
            avg_utilization=np.mean(values),
            peak_utilization=np.max(values),
            p95_utilization=np.percentile(values, 95),
            growth_rate=self._calculate_growth_rate(values, days),
            current_headroom=100 - np.percentile(values, 95)
        )

    def analyze_disk(self, days: int = 30) -> dict:
        """Analyze disk capacity and project exhaustion date."""
        end = datetime.utcnow()
        start = end - timedelta(days=days)

        # Current usage
        current_query = '(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100'
        current = float(requests.get(
            f"{self.prometheus_url}/api/v1/query",
            params={"query": current_query}
        ).json()['data']['result'][0]['value'][1])

        # Growth rate
        growth_query = 'deriv(node_filesystem_size_bytes{mountpoint="/"}[30d]) * 86400 / (1024*1024*1024)'  # GB per day
        growth_result = requests.get(
            f"{self.prometheus_url}/api/v1/query",
            params={"query": growth_query}
        ).json()

        growth_rate = float(growth_result['data']['result'][0]['value'][1])

        # Total capacity
        total_query = 'node_filesystem_size_bytes{mountpoint="/"} / (1024*1024*1024)'
        total_gb = float(requests.get(
            f"{self.prometheus_url}/api/v1/query",
            params={"query": total_query}
        ).json()['data']['result'][0]['value'][1])

        # Days until full (at current growth rate)
        available_gb = total_gb * (1 - current / 100)
        days_until_full = available_gb / growth_rate if growth_rate > 0 else float('inf')

        return {
            "current_usage_percent": current,
            "growth_rate_gb_per_day": growth_rate,
            "total_capacity_gb": total_gb,
            "available_gb": available_gb,
            "days_until_full": days_until_full,
            "exhaustion_date": (datetime.utcnow() + timedelta(days=days_until_full)).strftime("%Y-%m-%d")
        }

    def _calculate_growth_rate(self, values: list, days: int) -> float:
        """Calculate daily growth rate using linear regression."""
        x = np.arange(len(values))
        slope, _ = np.polyfit(x, values, 1)
        return slope * 24  # Convert hourly to daily

    def generate_report(self) -> str:
        """Generate capacity planning report."""
        cpu = self.analyze_cpu()
        memory = self.analyze_memory()
        disk = self.analyze_disk()

        report = """
# Capacity Planning Report
Generated: {date}

## CPU Capacity
- Average Utilization: {cpu_avg:.1f}%
- Peak Utilization: {cpu_peak:.1f}%
- P95 Utilization: {cpu_p95:.1f}%
- Current Headroom: {cpu_headroom:.1f}%
- Daily Growth Rate: {cpu_growth:.2f}%

## Memory Capacity
- Average Utilization: {mem_avg:.1f}%
- Peak Utilization: {mem_peak:.1f}%
- P95 Utilization: {mem_p95:.1f}%
- Current Headroom: {mem_headroom:.1f}%
- Daily Growth Rate: {mem_growth:.2f}%

## Disk Capacity
- Current Usage: {disk_current:.1f}%
- Total Capacity: {disk_total:.1f} GB
- Available: {disk_avail:.1f} GB
- Growth Rate: {disk_growth:.2f} GB/day
- Projected Exhaustion: {disk_exhaust}
- Days Until Full: {disk_days:.0f}

## Recommendations
{recommendations}
""".format(
            date=datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC"),
            cpu_avg=cpu.avg_utilization,
            cpu_peak=cpu.peak_utilization,
            cpu_p95=cpu.p95_utilization,
            cpu_headroom=cpu.current_headroom,
            cpu_growth=cpu.growth_rate,
            mem_avg=memory.avg_utilization,
            mem_peak=memory.peak_utilization,
            mem_p95=memory.p95_utilization,
            mem_headroom=memory.current_headroom,
            mem_growth=memory.growth_rate,
            disk_current=disk['current_usage_percent'],
            disk_total=disk['total_capacity_gb'],
            disk_avail=disk['available_gb'],
            disk_growth=disk['growth_rate_gb_per_day'],
            disk_exhaust=disk['exhaustion_date'],
            disk_days=disk['days_until_full'],
            recommendations=self._generate_recommendations(cpu, memory, disk)
        )

        return report

    def _generate_recommendations(self, cpu, memory, disk) -> str:
        """Generate actionable recommendations."""
        recommendations = []

        if cpu.current_headroom < 20:
            recommendations.append("⚠️ CPU headroom below 20%. Consider scaling up or optimizing workloads.")
        if memory.current_headroom < 15:
            recommendations.append("⚠️ Memory headroom below 15%. Consider increasing memory or optimizing usage.")
        if disk['days_until_full'] < 30:
            recommendations.append(f"🚨 Disk will be full in {disk['days_until_full']:.0f} days. Take action immediately.")
        elif disk['days_until_full'] < 90:
            recommendations.append(f"⚠️ Disk will be full in {disk['days_until_full']:.0f} days. Plan expansion.")

        if not recommendations:
            recommendations.append("✅ All resources have adequate headroom.")

        return "\n".join(recommendations)

if __name__ == "__main__":
    analyzer = CapacityAnalyzer("http://localhost:9090")
    print(analyzer.generate_report())
```

**Step 3:** Run the analysis.

```bash
python capacity_analysis.py
```

**Verification:**
- [ ] Historical data analyzed
- [ ] Growth rates calculated
- [ ] Exhaustion dates projected

---

### Exercise 1.2: Growth Trend Projections

**Objective:** Project future resource needs based on trends.

**Step 1:** Create Prometheus recording rules for trends.

```yaml
# prometheus/rules/capacity_trends.yml
groups:
  - name: capacity_trends
    interval: 1h
    rules:
      # CPU trend (linear extrapolation)
      - record: capacity:cpu:trend_30d
        expr: |
          predict_linear(
            (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])))[30d:1h],
            86400 * 30
          ) * 100

      # Memory trend
      - record: capacity:memory:trend_30d
        expr: |
          predict_linear(
            (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)[30d:1h],
            86400 * 30
          ) * 100

      # Request rate trend
      - record: capacity:requests:trend_30d
        expr: |
          predict_linear(
            sum(rate(api_requests_total[5m]))[30d:1h],
            86400 * 30
          )

      # Disk exhaustion date
      - record: capacity:disk:days_until_full
        expr: |
          (node_filesystem_avail_bytes{mountpoint="/"}
          /
          deriv(node_filesystem_size_bytes{mountpoint="/"}[30d]))
          / 86400
```

**Step 2:** Create projection visualization.

```promql
# Project CPU usage 90 days out
predict_linear(
  (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])))[30d:1h],
  86400 * 90
) * 100

# Project memory usage 90 days out
predict_linear(
  (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)[30d:1h],
  86400 * 90
) * 100

# Project request rate growth
predict_linear(
  sum(rate(api_requests_total[5m]))[30d:1h],
  86400 * 90
)
```

**Step 3:** Create Grafana dashboard with projections.

```json
{
  "panels": [
    {
      "title": "CPU Utilization - Current vs Projected",
      "type": "timeseries",
      "targets": [
        {
          "expr": "(1 - avg(rate(node_cpu_seconds_total{mode='idle'}[5m]))) * 100",
          "legendFormat": "Current"
        },
        {
          "expr": "capacity:cpu:trend_30d",
          "legendFormat": "30-day projection"
        },
        {
          "expr": "80",
          "legendFormat": "Warning threshold"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "max": 100
        }
      }
    },
    {
      "title": "Days Until Disk Full",
      "type": "gauge",
      "targets": [{
        "expr": "capacity:disk:days_until_full"
      }],
      "fieldConfig": {
        "defaults": {
          "thresholds": {
            "steps": [
              {"color": "red", "value": 0},
              {"color": "yellow", "value": 30},
              {"color": "green", "value": 90}
            ]
          }
        }
      }
    }
  ]
}
```

**Verification:**
- [ ] Trends calculated correctly
- [ ] Projections reasonable
- [ ] Thresholds visible

---

### Exercise 1.3: Load Testing for Capacity Validation

**Objective:** Use load testing to validate capacity assumptions.

**Step 1:** Create k6 load test script.

```javascript
// k6-scripts/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const latency = new Trend('request_latency');

// Test configuration
export const options = {
    scenarios: {
        // Baseline load
        baseline: {
            executor: 'constant-vus',
            vus: 10,
            duration: '5m',
            startTime: '0s',
        },
        // Ramp up to find capacity limit
        stress: {
            executor: 'ramping-vus',
            startVUs: 10,
            stages: [
                { duration: '2m', target: 50 },
                { duration: '5m', target: 100 },
                { duration: '5m', target: 200 },
                { duration: '5m', target: 300 },
                { duration: '2m', target: 0 },
            ],
            startTime: '5m',
        },
        // Spike test
        spike: {
            executor: 'ramping-vus',
            startVUs: 10,
            stages: [
                { duration: '10s', target: 500 },
                { duration: '1m', target: 500 },
                { duration: '10s', target: 10 },
            ],
            startTime: '25m',
        },
    },
    thresholds: {
        'http_req_duration': ['p(95)<500', 'p(99)<1000'],
        'http_req_failed': ['rate<0.05'],
        'errors': ['rate<0.1'],
    },
};

const BASE_URL = __ENV.TARGET_URL || 'http://localhost:8080';

export default function() {
    // API endpoints with different weights
    const endpoints = [
        { path: '/api/users', weight: 40 },
        { path: '/api/products', weight: 30 },
        { path: '/api/orders', weight: 20 },
        { path: '/api/search?q=test', weight: 10 },
    ];

    // Select endpoint based on weight
    const total = endpoints.reduce((sum, e) => sum + e.weight, 0);
    let random = Math.random() * total;
    let endpoint = endpoints[0];

    for (const e of endpoints) {
        random -= e.weight;
        if (random <= 0) {
            endpoint = e;
            break;
        }
    }

    const start = Date.now();
    const response = http.get(`${BASE_URL}${endpoint.path}`);
    const duration = Date.now() - start;

    latency.add(duration);

    const success = check(response, {
        'status is 200': (r) => r.status === 200,
        'response time < 500ms': (r) => r.timings.duration < 500,
    });

    errorRate.add(!success);

    sleep(Math.random() * 2 + 1);  // 1-3 second think time
}

export function handleSummary(data) {
    return {
        'stdout': textSummary(data, { indent: ' ', enableColors: true }),
        'summary.json': JSON.stringify(data),
    };
}

function textSummary(data, options) {
    // Custom summary formatting
    const metrics = data.metrics;

    return `
Load Test Summary
================

Requests:
  Total: ${metrics.http_reqs.values.count}
  Rate: ${metrics.http_reqs.values.rate.toFixed(2)}/s

Response Time:
  Avg: ${metrics.http_req_duration.values.avg.toFixed(2)}ms
  P95: ${metrics.http_req_duration.values['p(95)'].toFixed(2)}ms
  P99: ${metrics.http_req_duration.values['p(99)'].toFixed(2)}ms

Errors:
  Rate: ${(metrics.http_req_failed.values.rate * 100).toFixed(2)}%
  Count: ${metrics.http_req_failed.values.count || 0}

Thresholds:
  ${Object.entries(data.thresholds).map(([k, v]) => `${k}: ${v.ok ? '✓' : '✗'}`).join('\n  ')}
    `;
}
```

**Step 2:** Run load test.

```bash
# Run k6 load test
docker run --rm -i grafana/k6 run - <k6-scripts/load-test.js

# Or with environment variable
docker run --rm -i -e TARGET_URL=http://host.docker.internal:8080 grafana/k6 run - <k6-scripts/load-test.js
```

**Step 3:** Create capacity test script.

```python
# capacity_test.py
import subprocess
import requests
import json
import time
from datetime import datetime

class CapacityTester:
    def __init__(self, prometheus_url: str, target_url: str):
        self.prometheus_url = prometheus_url
        self.target_url = target_url

    def get_current_metrics(self) -> dict:
        """Get current resource metrics."""
        metrics = {}

        queries = {
            "cpu_usage": '(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m]))) * 100',
            "memory_usage": '(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100',
            "request_rate": 'sum(rate(api_requests_total[1m]))',
            "error_rate": 'sum(rate(api_requests_total{status=~"5.."}[1m])) / sum(rate(api_requests_total[1m]))',
            "p99_latency": 'histogram_quantile(0.99, sum by (le) (rate(api_request_duration_seconds_bucket[1m])))',
        }

        for name, query in queries.items():
            try:
                response = requests.get(
                    f"{self.prometheus_url}/api/v1/query",
                    params={"query": query}
                )
                result = response.json()['data']['result']
                metrics[name] = float(result[0]['value'][1]) if result else None
            except Exception as e:
                metrics[name] = None

        return metrics

    def find_capacity_limit(self, max_vus: int = 500, step: int = 50) -> dict:
        """Find the capacity limit by incrementally increasing load."""
        results = []
        current_vus = step

        print("Starting capacity limit test...")
        print("-" * 60)

        while current_vus <= max_vus:
            print(f"\nTesting with {current_vus} VUs...")

            # Get baseline metrics
            baseline = self.get_current_metrics()

            # Run short load test
            self._run_load_test(current_vus, duration="1m")

            # Wait for metrics to stabilize
            time.sleep(30)

            # Get metrics under load
            under_load = self.get_current_metrics()

            result = {
                "vus": current_vus,
                "timestamp": datetime.now().isoformat(),
                "baseline": baseline,
                "under_load": under_load,
            }

            # Check for capacity limit indicators
            if under_load['error_rate'] and under_load['error_rate'] > 0.05:
                print(f"⚠️ Error rate exceeded 5% at {current_vus} VUs")
                result['limit_reason'] = 'error_rate'
                results.append(result)
                break

            if under_load['p99_latency'] and under_load['p99_latency'] > 2.0:
                print(f"⚠️ P99 latency exceeded 2s at {current_vus} VUs")
                result['limit_reason'] = 'latency'
                results.append(result)
                break

            if under_load['cpu_usage'] and under_load['cpu_usage'] > 90:
                print(f"⚠️ CPU usage exceeded 90% at {current_vus} VUs")
                result['limit_reason'] = 'cpu'
                results.append(result)
                break

            print(f"  CPU: {under_load['cpu_usage']:.1f}%")
            print(f"  Memory: {under_load['memory_usage']:.1f}%")
            print(f"  Request Rate: {under_load['request_rate']:.1f}/s")
            print(f"  Error Rate: {under_load['error_rate']*100:.2f}%")
            print(f"  P99 Latency: {under_load['p99_latency']*1000:.0f}ms")

            results.append(result)
            current_vus += step

        return {
            "test_date": datetime.now().isoformat(),
            "target": self.target_url,
            "max_tested_vus": current_vus,
            "results": results,
            "capacity_limit": results[-1] if results else None
        }

    def _run_load_test(self, vus: int, duration: str):
        """Run a k6 load test with specified VUs."""
        script = f"""
import http from 'k6/http';
import {{ sleep }} from 'k6';

export const options = {{
    vus: {vus},
    duration: '{duration}',
}};

export default function() {{
    http.get('{self.target_url}/api/health');
    sleep(1);
}}
"""
        # In real implementation, would execute k6
        time.sleep(60)  # Simulate test duration

if __name__ == "__main__":
    tester = CapacityTester(
        prometheus_url="http://localhost:9090",
        target_url="http://localhost:8080"
    )
    results = tester.find_capacity_limit()
    print(json.dumps(results, indent=2))
```

**Verification:**
- [ ] Load tests execute successfully
- [ ] Capacity limits identified
- [ ] Results correlate with metrics

---

### Exercise 1.4: Capacity Planning Dashboard

**Objective:** Build comprehensive capacity planning dashboard.

**Step 1:** Create Grafana dashboard.

```json
{
  "dashboard": {
    "title": "Capacity Planning",
    "tags": ["capacity", "planning"],
    "panels": [
      {
        "title": "Resource Utilization Summary",
        "type": "stat",
        "gridPos": {"h": 4, "w": 8, "x": 0, "y": 0},
        "targets": [
          {"expr": "(1 - avg(rate(node_cpu_seconds_total{mode='idle'}[5m]))) * 100", "legendFormat": "CPU"},
          {"expr": "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100", "legendFormat": "Memory"},
          {"expr": "(1 - node_filesystem_avail_bytes{mountpoint='/'} / node_filesystem_size_bytes{mountpoint='/'}) * 100", "legendFormat": "Disk"}
        ],
        "fieldConfig": {
          "defaults": {"unit": "percent"}
        }
      },
      {
        "title": "Capacity Headroom",
        "type": "gauge",
        "gridPos": {"h": 6, "w": 8, "x": 8, "y": 0},
        "targets": [{
          "expr": "100 - (1 - avg(rate(node_cpu_seconds_total{mode='idle'}[5m]))) * 100",
          "legendFormat": "CPU Headroom"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100,
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 20},
                {"color": "green", "value": 40}
              ]
            }
          }
        }
      },
      {
        "title": "Days Until Capacity Exhaustion",
        "type": "stat",
        "gridPos": {"h": 4, "w": 8, "x": 16, "y": 0},
        "targets": [{
          "expr": "capacity:disk:days_until_full",
          "legendFormat": "Disk"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "d",
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 30},
                {"color": "green", "value": 90}
              ]
            }
          }
        }
      },
      {
        "title": "Historical CPU Utilization with Trend",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 6},
        "targets": [
          {"expr": "(1 - avg(rate(node_cpu_seconds_total{mode='idle'}[5m]))) * 100", "legendFormat": "Actual"},
          {"expr": "capacity:cpu:trend_30d", "legendFormat": "Projected (30d)"},
          {"expr": "80", "legendFormat": "Warning"}
        ]
      },
      {
        "title": "Request Rate Trend",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 6},
        "targets": [
          {"expr": "sum(rate(api_requests_total[5m]))", "legendFormat": "Actual"},
          {"expr": "capacity:requests:trend_30d", "legendFormat": "Projected"}
        ]
      }
    ]
  }
}
```

**Verification:**
- [ ] Dashboard shows current utilization
- [ ] Projections visible
- [ ] Headroom clearly indicated

---

### Exercise 1.5: Scaling Strategies

**Objective:** Define and implement scaling strategies.

**Step 1:** Document scaling strategies.

```yaml
# scaling-strategies.yml
services:
  api-gateway:
    current_capacity:
      instances: 3
      cpu_per_instance: 2
      memory_per_instance: 4Gi
      max_rps_per_instance: 1000

    scaling_strategy:
      type: horizontal
      trigger_metrics:
        - metric: cpu_utilization
          threshold: 70
          duration: 5m
        - metric: memory_utilization
          threshold: 80
          duration: 5m
        - metric: request_rate
          threshold: 2500  # 85% of capacity
          duration: 2m

      scaling_rules:
        scale_up:
          increment: 2
          cooldown: 300s
          max_instances: 10
        scale_down:
          decrement: 1
          cooldown: 600s
          min_instances: 2

    cost_per_instance: 150  # $/month

  database:
    current_capacity:
      type: db.r5.xlarge
      cpu: 4
      memory: 32Gi
      storage: 500Gi
      max_connections: 1000

    scaling_strategy:
      type: vertical
      trigger_metrics:
        - metric: cpu_utilization
          threshold: 70
          duration: 10m
        - metric: connection_utilization
          threshold: 80
          duration: 5m
        - metric: storage_utilization
          threshold: 80
          duration: 24h

      scaling_path:
        - db.r5.xlarge   # Current
        - db.r5.2xlarge
        - db.r5.4xlarge
        - db.r5.8xlarge

      read_replica_scaling:
        enabled: true
        max_replicas: 5
```

**Step 2:** Create HPA configuration.

```yaml
# kubernetes/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Pods
          value: 2
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Pods
          value: 1
          periodSeconds: 120
```

**Verification:**
- [ ] Scaling strategies documented
- [ ] HPA configured
- [ ] Cost implications understood

---

## Part 2: Semi-Guided Exercises

### Exercise 2.1: Seasonal Pattern Analysis

**Requirements:**
1. Identify daily/weekly patterns
2. Adjust capacity for peak times
3. Create predictive scaling

---

### Exercise 2.2: Cost-Optimized Capacity

**Requirements:**
1. Calculate cost per request
2. Compare scaling options
3. Optimize for cost efficiency

---

### Exercise 2.3: Multi-Region Capacity

**Requirements:**
1. Analyze regional traffic patterns
2. Balance global capacity
3. Plan for regional failover

---

### Exercise 2.4: Capacity Alerts

**Requirements:**
1. Alert on approaching limits
2. Alert on unusual growth
3. Alert on exhaustion projections

---

## Part 3: Challenge Exercises

### Challenge 3.1: Automated Capacity Planning

**Objective:** Build automated capacity recommendation system.

---

### Challenge 3.2: Cost Forecasting

**Objective:** Project infrastructure costs based on growth.

---

### Challenge 3.3: Capacity Simulation

**Objective:** Simulate various growth scenarios.

---

## Cleanup

```bash
# Remove test resources
kubectl delete hpa api-gateway-hpa -n production
rm -f summary.json
```

## Additional Resources

- [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [k6 Load Testing](https://k6.io/docs/)
- [Google SRE Book - Capacity Planning](https://sre.google/sre-book/software-engineering-in-sre/)

## Next Lab
Continue to [Lab 11: APM Solutions](labs-lab-11-apm-solutions-README.md) to implement Application Performance Monitoring.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- CPU Capacity
- Memory Capacity
- Disk Capacity
- 1: Historical Utilization Analysis

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
