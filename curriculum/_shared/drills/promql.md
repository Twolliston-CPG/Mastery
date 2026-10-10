# PromQL Drill

> Weeks 20–26. **Write these from memory.** Copy-pasting PromQL is why most people can't debug
> a dashboard when it matters.

## The four metric types

| Type | Meaning | Query with |
|---|---|---|
| **Counter** | Only goes up (resets to 0 on restart) | `rate()` / `increase()` — **never** the raw value |
| **Gauge** | Goes up and down | Raw value, `avg`, `max`, `delta()` |
| **Histogram** | Bucketed observations | `histogram_quantile()` over `_bucket` |
| **Summary** | Pre-computed quantiles | Raw quantile labels (can't aggregate across instances) |

**The #1 PromQL mistake:** graphing a counter directly. You get a sawtooth that resets on every pod
restart and means nothing. **Always `rate()` a counter.**

## Write these from the description

| # | Ask | Answer |
|---|---|---|
| 1 | Requests per second, last 5m | `rate(http_requests_total[5m])` |
| 2 | Total RPS across all instances | `sum(rate(http_requests_total[5m]))` |
| 3 | RPS by service | `sum by (service) (rate(http_requests_total[5m]))` |
| 4 | Error rate as a ratio | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))` |
| 5 | Error percentage | same as #4 `* 100` |
| 6 | p99 latency | `histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))` |
| 7 | p99 latency per service | `histogram_quantile(0.99, sum by (le, service) (rate(http_request_duration_seconds_bucket[5m])))` |
| 8 | Average latency (and why it's worse) | `rate(..._sum[5m]) / rate(..._count[5m])` |
| 9 | Memory usage % of limit | `container_memory_working_set_bytes / container_spec_memory_limit_bytes * 100` |
| 10 | CPU throttling ratio | `rate(container_cpu_cfs_throttled_periods_total[5m]) / rate(container_cpu_cfs_periods_total[5m])` |
| 11 | Pods restarting in the last hour | `increase(kube_pod_container_status_restarts_total[1h]) > 0` |
| 12 | Nodes not ready | `kube_node_status_condition{condition="Ready",status="true"} == 0` |
| 13 | Disk will fill within 4h | `predict_linear(node_filesystem_avail_bytes[6h], 4*3600) < 0` |
| 14 | Top 5 memory consumers | `topk(5, sum by (pod) (container_memory_working_set_bytes))` |
| 15 | A target has disappeared | `absent(up{job="api"}) == 1` |
| 16 | Targets currently down | `up == 0` |
| 17 | 30-day availability SLI | `sum(rate(http_requests_total{status!~"5.."}[30d])) / sum(rate(http_requests_total[30d]))` |
| 18 | Error budget remaining (99.9% target) | `1 - ((1 - <#17>) / 0.001)` |
| 19 | Fast burn (14.4x over 1h) | `(sum(rate(http_requests_total{status=~"5.."}[1h])) / sum(rate(http_requests_total[1h]))) > 14.4 * 0.001` |
| 20 | Deployment has fewer ready replicas than desired | `kube_deployment_status_replicas_available < kube_deployment_spec_replicas` |

## Traps that cost people interviews

**`rate()` vs `irate()` vs `increase()`**
- `rate()` — per-second average over the window. **Use this for alerting and graphing.**
- `irate()` — instant rate from the last two samples. Spiky. Only for high-resolution debugging.
- `increase()` — total over the window. Syntactic sugar for `rate() * window`.

**Range must cover at least 4 scrape intervals.** `rate(x[1m])` with a 30s scrape gives you 2 points
and a jumpy, unreliable result. Use `[5m]` as a default.

**Aggregate the `_bucket`, then take the quantile — never the reverse.**
```promql
# WRONG - averages quantiles, which is mathematically meaningless
avg(histogram_quantile(0.99, rate(x_bucket[5m])))

# RIGHT - sum the buckets by `le`, then compute
histogram_quantile(0.99, sum by (le) (rate(x_bucket[5m])))
```
You must keep the `le` label when summing. Dropping it returns nothing and confuses everyone.

**Label matching is `=`, `!=`, `=~`, `!~`.** Regex is fully anchored — `status=~"5.."` matches
exactly three characters, and `status=~"5.*"` is what you want for longer codes.

**Beware high cardinality.** See break/fix BF-56 — a `user_id` label will OOM your Prometheus.

## Build an SLO from scratch (do this once, in week 20)

```
Target:      99.9% availability, 30-day rolling window
Error budget: 0.1% of 30 days = 43.2 minutes of downtime
SLI:          proportion of non-5xx HTTP responses

Burn-rate alerts (Google SRE multi-window):
  PAGE   14.4x over 1h AND 14.4x over 5m   -> budget gone in ~2 days
  TICKET  6x  over 6h AND  6x  over 30m    -> budget gone in ~5 days
```
Being able to derive the 43.2-minute number out loud — 30 days × 24 × 60 × 0.001 — is a small thing
that reads as fluency.
