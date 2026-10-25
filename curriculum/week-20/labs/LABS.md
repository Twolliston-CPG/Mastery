# Week 20 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (20.2 to 20.6). Read a lab's figure
> before you start it; redraw it after.

---

# Lab 1 — The Three Signals and Instrumentation (3h)

## What each signal is for

| Signal | Answers | Cardinality | Cost |
|---|---|---|---|
| **Metrics** | "Is it broken? How broken? Trending?" | **Must be low** | Cheap, aggregatable |
| **Logs** | "What exactly happened to *this* request?" | High — that's the point | Expensive at volume |
| **Traces** | "Where did the time go across services?" | High, usually sampled | Expensive |

**The rule that prevents most observability disasters:** *metrics are for aggregates and must be low
cardinality; unique identifiers belong in logs and traces.* A `user_id` label on a metric is a
cardinality explosion (BF-56); a `user_id` field on a log line is correct.

## Install the stack
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set grafana.adminPassword=admin

kubectl -n monitoring port-forward svc/kps-grafana 3000:80
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090
```

## Instrument the app

```python
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from flask import Response
import time

REQUESTS = Counter(
    "http_requests_total", "Total HTTP requests",
    ["method", "endpoint", "status"],      # LOW cardinality only
)
LATENCY = Histogram(
    "http_request_duration_seconds", "Request latency",
    ["method", "endpoint"],
    buckets=(.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10),
)
IN_FLIGHT = Gauge("http_requests_in_flight", "In-flight requests")
DB_POOL = Gauge("db_connection_pool_used", "Database connections in use")

@app.before_request
def _start():
    request._t0 = time.perf_counter()
    IN_FLIGHT.inc()

@app.after_request
def _end(resp):
    IN_FLIGHT.dec()
    # NORMALIZE the endpoint. request.path would be /users/12345 -- unbounded.
    endpoint = request.url_rule.rule if request.url_rule else "unmatched"
    REQUESTS.labels(request.method, endpoint, resp.status_code).inc()
    LATENCY.labels(request.method, endpoint).observe(time.perf_counter() - request._t0)
    return resp

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)
```

**`request.url_rule.rule` gives `/users/<id>`, not `/users/12345`.** That one line is the difference
between 8 time series and 800,000. It is the most important line in the file.

## Histogram bucket choice

```python
buckets=(.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10)
```
`histogram_quantile` **interpolates within a bucket**, so your p99 is only as accurate as your bucket
boundaries. If your SLO is "p99 under 500ms," you need buckets near 0.5 — with buckets of
`(0.1, 1, 10)` your p99 is a guess somewhere between 100ms and 1s.

**Pick buckets around the thresholds you care about.** This is a real accuracy issue people don't
notice until their SLO reporting is wrong.

## ServiceMonitor
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: app
  namespace: shop
  labels: { release: kps }     # must match the Prometheus operator's selector
spec:
  selector:
    matchLabels: { app: app }
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```
**If a ServiceMonitor doesn't work, it's almost always the `release:` label** — the operator only
picks up ServiceMonitors matching its `serviceMonitorSelector`.

---

# Lab 2 — PromQL by Hand (3h)

> **No copy-paste this entire lab.** Copying PromQL is why people can't debug a dashboard when it
> matters.

Work `_shared/drills/promql.md` — all 20 queries, written from the description.

## The four metric types and how to query each

| Type | Query with | Never |
|---|---|---|
| **Counter** | `rate()`, `increase()` | the raw value — it's a sawtooth that resets on restart |
| **Gauge** | raw value, `avg`, `max`, `delta()` | `rate()` |
| **Histogram** | `histogram_quantile()` over `_bucket` | `avg` of quantiles |
| **Summary** | the pre-computed quantile labels | aggregating across instances (mathematically invalid) |

## The three traps

**1. Graphing a counter directly.**
```promql
http_requests_total              # sawtooth, resets to 0 on every pod restart
rate(http_requests_total[5m])    # per-second rate, handles resets correctly
```

**2. Aggregating quantiles.**
```promql
# WRONG -- the average of 99th percentiles is not the 99th percentile
avg(histogram_quantile(0.99, rate(x_bucket[5m])))

# RIGHT -- sum the buckets KEEPING `le`, then compute
histogram_quantile(0.99, sum by (le) (rate(x_bucket[5m])))
```
**You must keep the `le` label when summing.** Dropping it returns nothing and confuses everyone.

**3. A range shorter than 4 scrape intervals.**
`rate(x[1m])` with a 30s scrape gives you two points and a jumpy result. `[5m]` is a sane default.

## `rate` vs `irate` vs `increase`
- `rate()` — per-second average over the window. **Use this for alerting and dashboards.**
- `irate()` — instant rate from the last two samples. Spiky. High-resolution debugging only.
- `increase()` — the total over the window. Sugar for `rate() * window`.

## Tasks
Write all 20 from `_shared/drills/promql.md`, then:
1. Find the highest-cardinality metric in your Prometheus:
   ```promql
   topk(10, count by (__name__)({__name__=~".+"}))
   ```
2. Compute your app's error rate as a ratio, then as a percentage
3. Compute p50, p95, and p99 latency per endpoint
4. Detect a deployment: `changes(kube_pod_container_status_restarts_total[1h]) > 0`
5. Predict disk exhaustion: `predict_linear(node_filesystem_avail_bytes[6h], 4*3600) < 0`
6. Detect a target that disappeared: `absent(up{job="app"}) == 1`

---

# Lab 3 — Grafana and Alertmanager (3h)

## Build ONE good dashboard

**The five-second test:** can someone tell whether users are having a bad time, within five seconds
of looking at it?

**Top row — symptoms, always:**
| Panel | Query |
|---|---|
| Error rate % | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100` |
| p99 latency | `histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))` |
| Request rate | `sum(rate(http_requests_total[5m]))` |
| Availability SLI | `sum(rate(http_requests_total{status!~"5.."}[30d])) / sum(rate(http_requests_total[30d]))` |

**Second row — causes, for diagnosis:** CPU, memory, pod restarts, database connections, saturation.

**Never `avg` for latency.** A mean of 200ms is entirely compatible with 5% of users waiting 10
seconds. Use p50 **and** p99 — the gap between them is the story.

## Alertmanager

```yaml
route:
  group_by: ['alertname', 'namespace']
  group_wait: 30s          # collect related alerts before firing
  group_interval: 5m
  repeat_interval: 4h
  receiver: default
  routes:
    - matchers: [severity="page"]
      receiver: pagerduty
      continue: false
    - matchers: [severity="ticket"]
      receiver: slack

inhibit_rules:
  # If the whole service is down, don't also page about high latency.
  - source_matchers: [alertname="ServiceDown"]
    target_matchers: [severity=~"page|ticket"]
    equal: ['namespace', 'service']
```

**`inhibit_rules` are underused and genuinely valuable.** One root cause producing fifteen alerts is
how a real incident becomes unreadable. Inhibition suppresses the downstream noise so the page says
what actually broke.

## Tasks
1. Build the dashboard; time yourself answering "is anything wrong?" from a cold look
2. Route `severity=page` and `severity=ticket` to different receivers
3. Add an inhibit rule
4. **Reproduce BF-57:** write a `HighCPU` alert on a raw threshold, load the app, watch it flap
5. Replace it with a symptom-based alert and observe the difference

---

# Lab 4 — Tracing and Structured Logging (2h)

## OpenTelemetry

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor

trace.set_tracer_provider(TracerProvider())
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint="http://otel-collector:4317", insecure=True))
)
FlaskInstrumentor().instrument_app(app)
Psycopg2Instrumentor().instrument()      # database calls become child spans, free

tracer = trace.get_tracer(__name__)

@app.get("/orders/<int:order_id>")
def get_order(order_id):
    with tracer.start_as_current_span("fetch_order") as span:
        span.set_attribute("order.id", order_id)     # attributes CAN be high-cardinality
        ...
```

**Auto-instrumentation gives you most of the value for almost no effort.** Add manual spans only
where the auto-instrumented ones don't explain the time.

**Span attributes can be high cardinality** — that's the whole point of traces, and the reason IDs
belong here rather than in metric labels.

## Context propagation
```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
             ^v ^trace-id                        ^span-id          ^flags
```
The `traceparent` header (W3C Trace Context) is what links spans across services. **If it isn't
propagated, you get disconnected single-service traces** — which is the #1 tracing problem and is
almost always a client library that doesn't inject the header.

## Structured logging, with trace correlation
```python
import json, logging
from opentelemetry import trace

class JsonFormatter(logging.Formatter):
    def format(self, record):
        span = trace.get_current_span().get_span_context()
        return json.dumps({
            "ts": self.formatTime(record),
            "level": record.levelname,
            "msg": record.getMessage(),
            "logger": record.name,
            # THIS is what makes logs and traces one system
            "trace_id": format(span.trace_id, "032x") if span.is_valid else None,
            "span_id": format(span.span_id, "016x") if span.is_valid else None,
        })
```

**Putting `trace_id` in every log line is the single highest-value observability change you can
make.** It turns "a slow request" and "an error log" into the same investigation: click the trace,
see every log line from that exact request across every service.

---

# Lab 5 — SLOs, Error Budgets, Burn Rate (3h)

## Derive an SLO by hand

```
SLI:     proportion of HTTP requests that are not 5xx
SLO:     99.9% over a 30-day rolling window
Budget:  0.1% of 30 days

         30 days x 24 h x 60 min x 0.001 = 43.2 minutes
```

**Be able to do that arithmetic out loud.** "99.9% over 30 days is 43 minutes of budget" is a small
thing that reads as fluency.

| SLO | Budget / 30 days |
|---|---|
| 99% | 7h 12m |
| 99.5% | 3h 36m |
| **99.9%** | **43m 12s** |
| 99.95% | 21m 36s |
| 99.99% | 4m 19s |

**The point of an error budget is that it is a budget — it is meant to be spent.** An SLO at 100%
means no deploys. A team consistently at 99.999% against a 99.9% SLO is over-investing in reliability
and under-investing in features. That framing is a genuinely senior thing to say.

## Recording rules
```yaml
groups:
  - name: slo
    interval: 30s
    rules:
      - record: job:sli_error_ratio:rate5m
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum by (job) (rate(http_requests_total[5m]))
      - record: job:sli_error_ratio:rate1h
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[1h]))
          /
          sum by (job) (rate(http_requests_total[1h]))
```
Recording rules pre-compute expensive queries. **Alerts should use recording rules**, not raw
expressions — otherwise a dashboard refresh and an alert evaluation run the same expensive query
repeatedly.

## Multi-window burn-rate alerts

```yaml
      - alert: ErrorBudgetBurnFast
        expr: |
          job:sli_error_ratio:rate1h > (14.4 * 0.001)
          and
          job:sli_error_ratio:rate5m > (14.4 * 0.001)
        for: 2m
        labels: { severity: page }
        annotations:
          summary: "Burning the 30-day error budget 14.4x -- exhausted in ~2 days"
          runbook_url: "https://runbooks.example/high-error-rate"

      - alert: ErrorBudgetBurnSlow
        expr: |
          job:sli_error_ratio:rate6h > (6 * 0.001)
          and
          job:sli_error_ratio:rate30m > (6 * 0.001)
        for: 15m
        labels: { severity: ticket }
```

**Where 14.4 comes from:** a burn rate of 1 spends the budget exactly over the 30-day window
(720 hours). Paging when 2% of the budget goes in one hour means an error ratio 0.02 × 720 = 14.4
times the SLO's allowance; at that pace the whole budget is gone in 720 / 14.4 = 50 hours, about two
days. The slow burn is 5% in six hours: 0.05 × 720 / 6 = 6×, budget gone in five days. Two windows
(1h **and** 5m) prevent a single brief spike from paging: the long window says it has been going on,
the short one says it still is.

## Tasks
1. Define an SLO for your app; compute the budget by hand; verify against the table
2. Write the recording rules
3. Write both burn-rate alerts
4. Inject errors and **watch the fast-burn alert fire**
5. Build an error-budget panel: `1 - (error_ratio_30d / 0.001)`

## Break/Fix
**BF-56** (cardinality explosion) · **BF-57** (alert that fires constantly) · **BF-58** (dashboard
looks fine during an outage).

For BF-56, cause it deliberately:
```python
REQUESTS.labels(method, request.path, status).inc()   # request.path, not url_rule
```
Generate traffic to `/users/1` … `/users/5000` and watch `prometheus_tsdb_head_series` climb.
```promql
topk(10, count by (__name__)({__name__=~".+"}))
prometheus_tsdb_head_series
```
