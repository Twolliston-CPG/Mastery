# Week 20 Assessment

> Closed book, 35 min. **Part B must be written from memory — no reference.**

## Part A (15 min)
1. Metrics vs logs vs traces — what is each for, and what is the cardinality rule?
2. Why must you never graph a counter directly? What does `rate()` handle that you'd miss?
3. `rate` vs `irate` vs `increase` — when each?
4. Why is `avg(histogram_quantile(...))` wrong? Write the correct form.
5. Why must you keep `le` when summing buckets?
6. What determines the accuracy of your p99, and how do you choose it?
7. Why is `avg` latency a lie? Give a concrete example with numbers.
8. Cause-based vs symptom-based alerting — state the rule.
9. What is the 3am test for whether something should be a page?
10. What do Alertmanager `inhibit_rules` solve?
11. What is `traceparent` and what happens if it isn't propagated?
12. What's the single highest-value observability change you can make to logs?
13. Head-based vs tail-based sampling — which is better and why?
14. What is an error budget *for*? Give the framing that isn't "a target to hit."
15. Where does 14.4 come from, and why do burn-rate alerts use two windows?

## Part B — Write from memory (20 min)
16. Requests per second, by service
17. Error rate as a percentage
18. p99 latency, correctly aggregated across instances
19. The 30-day availability SLI
20. Error budget remaining, as a fraction, for a 99.9% SLO
21. A fast-burn alert (14.4×, two windows)
22. Detect a target that has disappeared entirely
23. Find the ten highest-cardinality metrics
24. Predict disk exhaustion within 4 hours
25. Compute the error budget for 99.95% over 30 days — in minutes, by hand

---

# Answer key

**A1.** **Metrics** — "is it broken, how broken, trending?"; **must be low cardinality**; cheap and
aggregatable. **Logs** — "what happened to *this* request?"; high cardinality is the point; expensive
at volume. **Traces** — "where did the time go across services?"; high cardinality, usually sampled.
**Rule: unique identifiers belong in logs and traces, never in metric labels.**

**A2.** A counter only increases and **resets to zero on restart**, so the raw graph is a meaningless
sawtooth. `rate()` detects the reset and treats it as a restart rather than a large negative rate —
that reset handling is the real reason to use it.

**A3.** `rate()` per-second average over the window — **use for alerting and dashboards**.
`irate()` instant rate from the last two samples — spiky, high-resolution debugging only.
`increase()` total over the window — sugar for `rate() × window`.

**A4.** The average of per-instance 99th percentiles is not the 99th percentile of the combined
population — it depends on the relative traffic volumes.
```promql
histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))
```

**A5.** `histogram_quantile` needs the bucket boundaries to interpolate. Drop `le` and there are no
boundaries, so it returns nothing.

**A6.** **The bucket boundaries.** `histogram_quantile` interpolates *within* a bucket, so your p99 is
only as precise as the bucket it lands in. Choose buckets clustered around the thresholds you care
about — if the SLO is 500ms, you want buckets at 0.25, 0.5, 1.0.

**A7.** 95% of requests at 100ms and 5% at 10s gives a mean of **595ms** — which looks acceptable
while one in twenty users waits ten seconds. Use p50 **and** p99; the gap between them is the story.

**A8.** **Page on symptoms, diagnose with causes.** High CPU with normal latency is a machine working
efficiently, not an incident. Error rate and latency are what users feel.

**A9.** **If a human can't do something about it at 3am, it is not a page.** If you can't write a
runbook for it, it belongs on a dashboard.

**A10.** One root cause producing fifteen alerts. Inhibition suppresses the downstream ones so the
page says what actually broke, at exactly the moment clarity matters most.

**A11.** The W3C Trace Context header carrying the trace ID and parent span ID across service
boundaries. **Without propagation you get disconnected single-service traces** — which looks like
tracing is working and tells you nothing about cross-service latency. It's the #1 tracing problem,
usually an HTTP client that doesn't inject the header.

**A12.** **Put `trace_id` in every log line.** It turns logs and traces from two separate
investigations into one system: from a slow trace, find every log from that request; from an error
log, jump to the trace.

**A13.** **Tail-based.** Head-based decides at the start (e.g. 1%), so you **lose the interesting
ones** — errors and slow requests are rare by definition. Tail-based buffers the trace and decides
after completion: keep 100% of errors and slow traces, sample the boring ones. More expensive to
operate, far more useful.

**A14.** *"An error budget is a budget, and it is meant to be spent. A team consistently at 99.999%
against a 99.9% SLO isn't excellent — it's over-invested in reliability and under-invested in
shipping. The budget makes that tradeoff explicit: burn it, and feature work pauses for reliability
work; don't, and you can take more risk."* **It is a decision-making tool for allocating engineering
effort**, not a scoreboard.

**A15.** 14.4× corresponds to consuming 2% of a 30-day budget in one hour — exhausting the whole
budget in roughly two days (the Google SRE workbook figure). **Two windows** because the long window
(1h) detects the burn and the short window (5m) confirms it is **still happening right now** —
otherwise a one-minute spike that happened to land in the hour window pages someone about a problem
that's already over.

---

**B16.** `sum by (service) (rate(http_requests_total[5m]))`

**B17.** `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100`

**B18.** `histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))`

**B19.** `sum(rate(http_requests_total{status!~"5.."}[30d])) / sum(rate(http_requests_total[30d]))`

**B20.** `1 - ((1 - <B19>) / 0.001)` — or with a recording rule:
`1 - (job:sli_error_ratio:rate30d / 0.001)`

**B21.**
```promql
job:sli_error_ratio:rate1h > (14.4 * 0.001)
and
job:sli_error_ratio:rate5m > (14.4 * 0.001)
```

**B22.** `absent(up{job="shop-app"}) == 1`

**B23.** `topk(10, count by (__name__)({__name__=~".+"}))`

**B24.** `predict_linear(node_filesystem_avail_bytes[6h], 4*3600) < 0`

**B25.** 30 × 24 × 60 = 43,200 minutes. × 0.0005 = **21.6 minutes.**

## Scoring
| | |
|---|---|
| 20–25 | Move on. |
| 15–19 | Redo Lab 2. PromQL fluency is what separates "I've seen Grafana" from "I can debug with it." |
| < 15 | Redo Labs 2 and 5. SLOs and burn-rate alerting are the most-asked SRE interview topics. |
