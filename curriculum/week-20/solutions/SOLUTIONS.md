# Week 20 Solutions

Working config: [`observability/`](observability/)

---

## Lab 1 — Instrumentation

### The one line that matters

```python
endpoint = request.url_rule.rule if request.url_rule else "unmatched"
```

`request.path` → `/users/12345` → one time series **per user ID**.
`request.url_rule.rule` → `/users/<id>` → one time series per **route**.

With 8 routes, 4 methods, and 6 status codes that's 192 series. With raw paths and 100,000 users it
is potentially millions. **This is BF-56 in one line**, and it is the most important line in the
instrumentation.

The `"unmatched"` fallback matters too: a 404 has no `url_rule`, and without the fallback you'd
either crash or fall back to the raw path — reintroducing the explosion via scanner traffic hitting
random URLs.

### Histogram buckets determine your accuracy

```python
buckets=(.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10)
```
`histogram_quantile` **linearly interpolates within a bucket**. With buckets of `(0.1, 1, 10)` and an
SLO of "p99 under 500ms", your p99 lands somewhere in the 0.1–1 bucket and the reported value is an
interpolation, not a measurement.

**Pick buckets around the thresholds you care about.** If your SLO threshold is 500ms, you want
buckets at 0.25, 0.5, and 1.0 so the quantile is well-constrained near the number that matters.

This is a real accuracy problem that people don't notice until their SLO reporting disagrees with
user complaints.

### Why the ServiceMonitor "doesn't work"

```yaml
metadata:
  labels:
    release: kps      # MUST match the operator's serviceMonitorSelector
```
The Prometheus Operator only picks up ServiceMonitors matching its selector. Check it:
```bash
kubectl -n monitoring get prometheus -o jsonpath='{.items[0].spec.serviceMonitorSelector}'
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090
# then http://localhost:9090/targets -- if your target isn't listed, it's the selector
```
**The `/targets` page is the first place to look** for any "Prometheus isn't scraping my app"
problem, and it tells you whether the issue is discovery (target absent) or connectivity (target
present, DOWN with an error).

---

## Lab 2 — PromQL

### Why you never graph a counter

```promql
http_requests_total
```
Monotonically increasing, reset to zero on every pod restart. The graph is a sawtooth whose slope is
the thing you wanted and whose value is meaningless.

```promql
rate(http_requests_total[5m])
```
`rate()` handles counter resets — it detects the drop and treats it as a restart rather than a
negative rate. That reset handling is the actual reason to use it, beyond the convenience.

### Aggregating quantiles is mathematically invalid

```promql
avg(histogram_quantile(0.99, rate(x_bucket[5m])))
```
The average of three instances' 99th percentiles is not the 99th percentile of the combined
population. If instance A's p99 is 100ms and instance B's is 900ms, the true combined p99 depends
entirely on the relative traffic volumes.

```promql
histogram_quantile(0.99, sum by (le) (rate(x_bucket[5m])))
```
Sum the **bucket counts** first (which is valid — buckets are cumulative counts), then compute the
quantile from the combined histogram.

**`by (le)` is mandatory.** Drop it and `histogram_quantile` has no bucket boundaries to work with
and returns nothing.

### Range selection

A `rate()` needs at least **4 data points** to be stable. With a 15s scrape interval that's a minimum
of `[1m]`, and `[5m]` is the practical default. `rate(x[30s])` with a 15s scrape gives you two
points, and the result jumps around meaninglessly.

Rule of thumb: **range ≥ 4 × scrape_interval**, and use the same range consistently across a
dashboard so panels are comparable.

---

## Lab 3 — Dashboards and alerts

### Why `avg` for latency is a lie

Suppose 95% of requests take 100ms and 5% take 10 seconds.
```
mean = 0.95 × 0.1 + 0.05 × 10 = 0.595s
```
A 595ms average looks acceptable. Meanwhile **one in twenty users waits ten seconds**. The average
has hidden the entire problem.

p50 tells you the typical experience; p99 tells you the worst common experience. **The gap between
them is the story** — a p50 of 100ms and a p99 of 10s means a small set of requests is doing
something very different, and that's what you investigate.

### Cause-based vs symptom-based

```yaml
# CAUSE-based -- fires constantly, gets muted, teaches people to ignore alerts
- alert: HighCPU
  expr: node_cpu_utilization > 0.8
```
High CPU with normal latency means the machine is **working efficiently**. It is not an incident.

```yaml
# SYMPTOM-based -- fires when users are actually affected
- alert: ErrorBudgetBurnFast
  expr: job:sli_error_ratio:rate1h > (14.4 * 0.001)
      and job:sli_error_ratio:rate5m > (14.4 * 0.001)
```

**The rule: page on symptoms, diagnose with causes.** CPU, memory, and connection counts belong on
the dashboard you open *after* being paged — not in the pager.

The test: **if a human can't do something about it at 3am, it is not a page.**

### Inhibition

```yaml
inhibit_rules:
  - source_matchers: [alertname="ServiceDown"]
    target_matchers: [severity=~"page|ticket"]
    equal: ['namespace', 'service']
```
When a service is down, it will *also* produce high latency, high error rate, failed health checks,
and probably a few downstream alerts. Fifteen alerts for one root cause make an incident channel
unreadable at exactly the moment clarity matters.

**Inhibition is underused and cheap.** One rule suppressing the downstream noise makes the page say
what actually broke.

---

## Lab 4 — Tracing

### The `traceparent` header is the whole mechanism

```text
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
             │  │                                │                │
             │  │                                │                └── flags
             │  │                                └── parent span id
             │  └── trace id — the same for the whole request
             └── version
```

| Field | Bytes | Meaning |
|---|---|---|
| Version | 1 | Always `00` today |
| Trace id | 16 | Identifies the whole request; identical in every span |
| Parent span id | 8 | The span that called this one — this is what builds the tree |
| Flags | 1 | `01` means sampled; `00` means recorded but not exported |

The sampled flag is the field that surprises people. It is decided **once**, at the root, and
propagated — so a downstream service cannot decide to sample a trace the entry point already
discarded. That is what keeps a trace whole instead of half-collected.
Service A creates a trace ID and injects the header. Service B extracts it and creates child spans
under the same trace ID. **If the header isn't propagated, you get disconnected single-service
traces** — which looks like tracing working and tells you nothing about cross-service latency.

That's the #1 tracing problem, and it's almost always an HTTP client that doesn't inject the header
(an un-instrumented library, a raw socket, or a message queue where you must propagate manually).

### `trace_id` in logs is the highest-value change

```json
{"ts":"2026-03-14T10:00:00Z","level":"ERROR","msg":"db timeout",
 "trace_id":"4bf92f3577b34da6a3ce929d0e0e4736","span_id":"00f067aa0ba902b7"}
```

Without it, logs and traces are two separate investigations. With it they are one system: you see a
slow trace, grab the trace ID, and get every log line from that exact request across every service.
Or you see an error log and jump straight to the trace showing what the request was doing.

**In an interview:** *"the single highest-value observability change I've made is putting the trace ID
in every log line — it turns logs and traces from two tools into one investigation."*

### Sampling

Tracing every request is expensive at volume. Two approaches:
- **Head-based** — decide at the start, e.g. 1% of requests. Simple, cheap, and **you lose the
  interesting ones** — errors and slow requests are rare by definition.
- **Tail-based** — buffer the trace, decide after it completes: keep 100% of errors and slow traces,
  sample 1% of successful fast ones. More expensive to run, far more useful.

**Tail-based sampling is the better answer** and knowing the distinction is a good signal.

---

## Lab 5 — SLOs

### The arithmetic, done out loud

```
99.9% over 30 days
  30 × 24 × 60 = 43,200 minutes
  43,200 × 0.001 = 43.2 minutes of budget
```

### Why burn rate rather than a threshold

A raw threshold alert (`error_rate > 1%`) fires on every brief spike and tells you nothing about
whether you're actually in trouble. **Burn rate asks a different question: at this rate, when does
the budget run out?**

| Burn rate | Budget exhausted in | Action |
|---|---|---|
| 1× | 30 days (exactly on budget) | Nothing |
| 6× | ~5 days | **Ticket** |
| 14.4× | **~2 days** | **Page** |
| 100× | ~7 hours | Page, escalate |

**Two windows prevent false pages.** `rate1h > 14.4x` alone fires on a one-minute blip that happened
to land in the window. Requiring `rate5m` to *also* be burning means the problem is still happening
right now. That combination is the Google SRE workbook's recommendation and it's worth naming as
such.

### The error budget is meant to be spent

The most valuable framing, and the one that reads as senior:

> *"An error budget is a budget. A team consistently delivering 99.999% against a 99.9% SLO isn't
> excellent — it's over-invested in reliability and under-invested in shipping. The budget exists to
> make that tradeoff explicit and negotiable: if we've burned it, we stop feature work and fix
> reliability; if we haven't, we can take more risk."*

Most candidates present SLOs as "a target to hit." Presenting them as a **decision-making tool for
allocating engineering effort** is the actual point.

---

## BF-56 — the cardinality explosion, reproduced

```python
REQUESTS.labels(method, request.path, status).inc()   # request.path -- unbounded
```
```bash
for i in $(seq 1 5000); do curl -s "http://localhost:8080/users/$i" > /dev/null; done
```
```promql
prometheus_tsdb_head_series                              # climbing fast
topk(10, count by (__name__)({__name__=~".+"}))          # which metric
```
```bash
curl -s localhost:9090/api/v1/status/tsdb | jq '.data.seriesCountByMetricName[:5]'
```

**Prometheus keeps every active series in memory.** Millions of series means gigabytes of RAM and
eventually an OOMKill — and the recovery is worse, because on restart it replays the WAL and OOMs
again.

**The fixes, in order:**
1. Normalize the label at the source (`url_rule.rule`) — fix the cause
2. Drop it at scrape time as a stopgap:
   ```yaml
   metric_relabel_configs:
     - source_labels: [__name__]
       regex: 'http_requests_total'
       action: drop
   ```
3. Cap it so it can't recur: `sample_limit: 10000` on the scrape config

**The one-sentence rule:** *metrics are for aggregates and must be low cardinality; unique
identifiers belong in logs and traces.*

And it makes a genuinely good war story: *"I OOMed Prometheus by putting a user ID in a metric
label."*
