# Week 20 — Observability

> **Thesis:** most dashboards are decoration. The test of a good one is whether someone can tell
> **users are having a bad time** within five seconds of looking at it. Almost none pass.

| | |
|---|---|
| **Hours** | 35–45 (incl. ~4h job search) |
| **Deliverable** | Blog post #11 — "Your dashboard is lying to you: cause-based vs symptom-based alerting" |
| **Break/Fix** | BF-56, BF-57, BF-58 |
| **Exit check** | Write 10 PromQL queries from scratch and define a valid SLO with burn-rate alerts |

## Day plan
| Day | Focus | Lab |
|---|---|---|
| Mon | The three signals; Prometheus architecture; instrumentation | Lab 1 |
| Tue | **PromQL by hand** — no copy-paste | Lab 2 |
| Wed | Grafana, Alertmanager, alert design | Lab 3 |
| Thu | OpenTelemetry, tracing, structured logging | Lab 4 |
| Fri | **SLIs, SLOs, error budgets, burn-rate alerts** + Break/Fix | Lab 5 |
| Sat | ⚑ Bravo observability; 15 applications | — |
| Sun | Blog post #11; plan week 21 | — |

## Reading map
- `_reference/observability-sre/content-01-observability-fundamentals.md`
- `_reference/observability-sre/content-02-prometheus-architecture.md`
- `_reference/observability-sre/content-03-grafana-visualization.md`
- `_reference/observability-sre/content-04-alertmanager-alerting.md`
- `_reference/observability-sre/content-06-distributed-tracing.md`
- `_reference/observability-sre/content-07-opentelemetry.md`
- `_reference/observability-sre/content-08-sre-practices.md`
- `_reference/kubernetes/03-production/01-observability-stack-exercises-06-slo-error-budgets.md`
- `_reference/kubernetes/03-production/01-observability-stack-exercises-05-alerting-strategies.md`
- **Drill:** `_shared/drills/promql.md` — the whole file, daily

**Free primary source:** the Google SRE Book and SRE Workbook are online for free. Read the SLO
chapter and the "Alerting on SLOs" chapter — they are the source for everything in Lab 5.

## Labs
[labs/LABS.md](labs/LABS.md) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md)

## Exit criteria
- [ ] App instrumented with a counter, a histogram, and a gauge
- [ ] **10 PromQL queries written from scratch**, no copy-paste
- [ ] One dashboard that answers "are users having a bad time?" in 5 seconds
- [ ] An SLO defined with its error budget computed by hand
- [ ] Multi-window burn-rate alerts configured
- [ ] Distributed trace across app → database; slow span identified
- [ ] Reproduce a cardinality explosion and fix it
