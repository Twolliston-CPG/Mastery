# Phase 5 Assessment: Observability & SRE Knowledge Check

## Assessment Overview

**Duration**: 90 minutes
**Total Points**: 100
**Passing Score**: 75%

This assessment evaluates your understanding of observability fundamentals, metrics collection, logging, distributed tracing, SRE practices, incident management, and chaos engineering.

---

## Section 1: Observability Fundamentals (20 points)

### Question 1.1 (4 points)
What are the three pillars of observability?

A) Logs, Events, Traces
B) Metrics, Logs, Traces
C) Metrics, Events, Alerts
D) Monitoring, Logging, Alerting

**Answer**: ___

### Question 1.2 (4 points)
Which statement best describes the difference between monitoring and observability?

A) Monitoring is proactive; observability is reactive
B) Monitoring answers "is something wrong?"; observability answers "why is it wrong?"
C) Monitoring is for infrastructure; observability is for applications
D) Monitoring uses metrics; observability uses logs

**Answer**: ___

### Question 1.3 (4 points)
Examine this Prometheus metric:

```
http_request_duration_seconds_bucket{method="GET", endpoint="/api/users", le="0.5"} 1523
http_request_duration_seconds_bucket{method="GET", endpoint="/api/users", le="1.0"} 1687
http_request_duration_seconds_bucket{method="GET", endpoint="/api/users", le="+Inf"} 1702
http_request_duration_seconds_sum{method="GET", endpoint="/api/users"} 412.5
http_request_duration_seconds_count{method="GET", endpoint="/api/users"} 1702
```

What type of Prometheus metric is this?

A) Counter
B) Gauge
C) Histogram
D) Summary

**Answer**: ___

### Question 1.4 (4 points)
In the context of distributed systems, what does "cardinality" refer to in metrics?

A) The number of data points collected per second
B) The number of unique label value combinations for a metric
C) The storage space required for metrics
D) The precision of metric values

**Answer**: ___

### Question 1.5 (4 points)
Which OpenTelemetry component is responsible for receiving, processing, and exporting telemetry data?

A) SDK
B) API
C) Collector
D) Exporter

**Answer**: ___

---

## Section 2: Prometheus & PromQL (20 points)

### Question 2.1 (4 points)
What is the difference between `rate()` and `irate()` in PromQL?

A) `rate()` is for counters; `irate()` is for gauges
B) `rate()` calculates average rate over the range; `irate()` uses the last two data points
C) `rate()` is instantaneous; `irate()` is averaged
D) `rate()` is more accurate; `irate()` is deprecated

**Answer**: ___

### Question 2.2 (4 points)
Given this PromQL query:

```promql
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))
```

What does this query calculate?

A) The 99th percentile of request duration across all services, grouped by service
B) The 99th percentile of request count per service
C) The average request duration for 99% of requests
D) The number of requests taking more than 99ms

**Answer**: ___

### Question 2.3 (4 points)
What is a recording rule in Prometheus used for?

A) Storing alert history
B) Pre-computing frequently needed or expensive expressions
C) Recording metric metadata
D) Logging query executions

**Answer**: ___

### Question 2.4 (4 points)
Examine this alert rule:

```yaml
- alert: HighErrorRate
  expr: |
    sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
    /
    sum(rate(http_requests_total[5m])) by (service)
    > 0.05
  for: 5m
  labels:
    severity: critical
```

What does the `for: 5m` clause mean?

A) The alert fires after 5 minutes of data collection
B) The condition must be true for 5 consecutive minutes before the alert fires
C) The alert remains active for 5 minutes
D) The query evaluates data from the last 5 minutes

**Answer**: ___

### Question 2.5 (4 points)
Which PromQL function would you use to find the top 5 services by request rate?

A) `max_over_time()`
B) `topk(5, ...)`
C) `sort_desc()`
D) `limit(5, ...)`

**Answer**: ___

---

## Section 3: Logging & Log Management (15 points)

### Question 3.1 (3 points)
In the ELK Stack, what is the primary role of Logstash?

A) Store and index logs
B) Visualize log data
C) Ingest, transform, and ship logs
D) Query logs using SQL

**Answer**: ___

### Question 3.2 (4 points)
Examine this LogQL query:

```logql
{namespace="production", app="api-gateway"} |= "error" | json | status_code >= 500 | line_format "{{.timestamp}} - {{.message}}"
```

What does the `|=` operator do?

A) Assigns a value to a variable
B) Filters log lines containing the text "error"
C) Performs a regex match
D) Compares equality

**Answer**: ___

### Question 3.3 (4 points)
What is structured logging and why is it beneficial?

A) Logging in alphabetical order for easier reading
B) Logging with consistent key-value pairs enabling machine parsing and querying
C) Logging with timestamps only
D) Logging to structured files like CSV

**Answer**: ___

### Question 3.4 (4 points)
Which log level should be used for recording unexpected conditions that won't cause immediate failure but should be investigated?

A) DEBUG
B) INFO
C) WARN
D) ERROR

**Answer**: ___

---

## Section 4: Distributed Tracing (15 points)

### Question 4.1 (3 points)
In distributed tracing, what is the relationship between a trace and spans?

A) A span contains multiple traces
B) A trace is a collection of spans representing a request's journey through services
C) Traces and spans are interchangeable terms
D) A trace is a subset of a span

**Answer**: ___

### Question 4.2 (4 points)
What is context propagation in distributed tracing?

A) Sending logs from one service to another
B) Passing trace context (trace ID, span ID) between services to correlate spans
C) Propagating errors through the call chain
D) Distributing configuration across services

**Answer**: ___

### Question 4.3 (4 points)
Examine this trace data:

**Trace ID: abc123**

- Span A (service: api-gateway, duration: 250ms)
  - Span B (service: user-service, duration: 50ms)
  - Span C (service: auth-service, duration: 180ms)
    - Span D (service: database, duration: 150ms)


What is the root cause of the high latency in Span A?

A) Span B is slow
B) The api-gateway service is slow
C) Span D (database call in auth-service) is the bottleneck
D) Cannot be determined from this data

**Answer**: ___

### Question 4.4 (4 points)
What is tail-based sampling in distributed tracing?

A) Sampling only the last spans in a trace
B) Making sampling decisions after the complete trace is collected
C) Sampling based on trace ID hash
D) Sampling only error traces

**Answer**: ___

---

## Section 5: SRE Practices (20 points)

### Question 5.1 (4 points)
Which statement correctly defines the relationship between SLI, SLO, and SLA?

A) SLA > SLO > SLI (in strictness)
B) SLI measures service performance; SLO is the target for SLI; SLA is the contractual commitment
C) SLI is internal; SLO is external; SLA is legal
D) They are different terms for the same concept

**Answer**: ___

### Question 5.2 (4 points)
Calculate the error budget for a service with a 99.9% availability SLO over a 30-day period:

A) 43.2 minutes of allowed downtime
B) 4.32 minutes of allowed downtime
C) 7.2 hours of allowed downtime
D) 43.8 hours of allowed downtime

**Answer**: ___

### Question 5.3 (4 points)
What is a burn rate in the context of SLO alerting?

A) The speed at which CPU is being consumed
B) The rate at which error budget is being consumed compared to the expected rate
C) The rate of incident occurrence
D) The speed of deployment rollbacks

**Answer**: ___

### Question 5.4 (4 points)
Examine this multi-window burn rate alert configuration:

```yaml
# Fast burn: 2% of monthly budget consumed in 1 hour
- alert: SLOFastBurn
  expr: |
    (error_rate_5m > 14.4 * 0.001) and (error_rate_1h > 14.4 * 0.001)
  for: 2m
```

Why are two windows (5m and 1h) used?

A) To reduce storage costs
B) To catch both short spikes and sustained issues while reducing false positives
C) For redundancy in case one window fails
D) Because Prometheus requires multiple windows

**Answer**: ___

### Question 5.5 (4 points)
What is "toil" in SRE terminology?

A) Any work that is difficult
B) Manual, repetitive, automatable work that scales linearly with service growth
C) Incident response activities
D) Documentation tasks

**Answer**: ___

---

## Section 6: Incident Management & Chaos Engineering (10 points)

### Question 6.1 (3 points)
What is the primary purpose of a blameless postmortem?

A) To determine who is at fault for an incident
B) To learn from failures and prevent recurrence without assigning personal blame
C) To calculate the financial impact of incidents
D) To satisfy audit requirements

**Answer**: ___

### Question 6.2 (3 points)
In chaos engineering, what is a "steady state hypothesis"?

A) The assumption that systems are always stable
B) A measurable output of normal system behavior that you expect to remain unchanged
C) The hypothesis that chaos experiments will fail
D) The expected downtime during experiments

**Answer**: ___

### Question 6.3 (4 points)
Which of the following is NOT a principle of chaos engineering?

A) Build a hypothesis around steady state behavior
B) Vary real-world events (inject failures)
C) Run experiments in production only after validating in staging
D) Maximize the blast radius to find more issues

**Answer**: ___

---

## Section 7: Scenario-Based Questions (Bonus - 10 points)

### Scenario 7.1 (5 points)

Your team receives an alert that the error rate for the checkout service has spiked to 15%. Describe the systematic approach you would take to investigate this issue using observability tools.

**Your Answer:**
```
[Write your investigation approach here, including:
- Initial triage steps
- Which metrics/logs/traces you would examine
- How you would correlate data across pillars
- How you would identify root cause]
```

### Scenario 7.2 (5 points)

Your organization wants to implement SLOs for a new API service. The service handles payment processing and has the following characteristics:
- P50 latency: 100ms
- P99 latency: 800ms
- Current error rate: 0.5%
- Business requirement: "The service should be highly available"

Define appropriate SLIs and SLOs for this service, explaining your reasoning.

**Your Answer:**
```
[Define your SLIs, SLOs, and explain why you chose these targets]
```

---

## Answer Key (For Instructors)

### Section 1
1.1: B
1.2: B
1.3: C
1.4: B
1.5: C

### Section 2
2.1: B
2.2: A
2.3: B
2.4: B
2.5: B

### Section 3
3.1: C
3.2: B
3.3: B
3.4: C

### Section 4
4.1: B
4.2: B
4.3: C
4.4: B

### Section 5
5.1: B
5.2: A (30 days × 24 hours × 60 minutes × 0.1% = 43.2 minutes)
5.3: B
5.4: B
5.5: B

### Section 6
6.1: B
6.2: B
6.3: D

### Section 7 - Sample Answers

**7.1 Investigation Approach:**
1. Initial triage: Check current error rate trend, identify when spike started
2. Metrics: Look at request rate, latency distribution, downstream dependency health
3. Logs: Filter for errors in checkout service, look for patterns (error codes, stack traces)
4. Traces: Find error traces, identify which spans are failing
5. Correlation: Check if spike correlates with deployments, config changes, or dependency issues
6. Root cause: Follow the trace to identify failing component (database, payment gateway, etc.)

**7.2 SLO Definition:**
- **Availability SLI**: Ratio of successful requests (non-5xx) to total requests
  - **SLO**: 99.95% (payment processing requires high availability)
  - **Reasoning**: 0.5% error rate suggests room for improvement; 99.9% would be too loose

- **Latency SLI**: Ratio of requests completing within threshold to total requests
  - **SLO**: 99% of requests < 500ms
  - **Reasoning**: P99 at 800ms is high for payments; target should be tighter than current performance

- **Error Budget**: 0.05% = 21.6 minutes of complete outage equivalent per 30 days

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Observability Fundamentals
- Prometheus & PromQL
- Logging & Log Management
- Distributed Tracing

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
