# Week 21 Solutions

---

## Lab 2 — What the three incidents should teach you

### Incident 1 — the 500s

**What you should find:** the alert fires correctly (you built it in week 20), mitigation is a
rollback, and time-to-mitigate is short.

**The finding worth writing down:** how long between the deploy and the alert? If it was 5+ minutes,
your `for:` duration plus the rate window is the detection lag — and that lag is a deliberate
tradeoff against false pages, not a bug. Being able to articulate *why* detection isn't instant, and
that it's a choice, is the senior version of this.

### Incident 2 — the database disappears

**What you should find:** readiness probes fail, pods leave the Service endpoints, and **nothing
restarts**. If pods *do* restart, your liveness probe is checking the database — which is BF-44, and
you have just reproduced the production disaster deliberately.

**The finding:** this is the incident that proves the liveness/readiness split was correct. Write it
up that way: *"the app degraded and recovered without a restart storm, because dependency checks are
in readiness, not liveness."*

### Incident 3 — gradual degradation

**The hardest, and the most valuable.** Connection-pool exhaustion or a filling disk degrades slowly.
Requests get slower, then some fail, then most fail.

**The findings you should reach:**
- Threshold alerts on error rate catch this **late**, because the error rate climbs gradually
- A **saturation** signal (pool utilization, disk free) catches it early — this is why saturation is
  one of the four golden signals
- `predict_linear` on disk free would have alerted hours before it mattered
- **"Our alerting only catches binary failures"** is a genuine and common gap

---

## Postmortem quality — the difference

### Weak

> **What happened:** The site was down for 20 minutes. Alex deployed a bad change. We rolled back.
> **Action item:** Be more careful with deploys.

Three problems: it blames a person, it has no timeline, and the action item is unactionable.

### Strong

> **Impact:** 18 minutes of elevated errors (peak 34% of requests). ~4,200 failed requests.
> 42% of the 30-day error budget consumed.
>
> **Timeline (UTC):**
> `14:02` deploy of `api@v1.4.2` begins ·
> `14:07` error rate crosses 5%, `ErrorBudgetBurnFast` fires ·
> `14:09` on-call acknowledges ·
> `14:18` root cause identified ·
> `14:22` rollback begins ·
> `14:26` error rate normal.
>
> **Detection time:** 5 minutes. **Time to mitigate:** 19 minutes.
>
> **Root cause:** `v1.4.2` introduced a connection leak in the retry path. Under normal traffic the
> pool (20 connections) exhausted in ~5 minutes.
> *Contributing:* pool saturation had no alert, so detection depended on user-visible errors.
> *Systemic:* load tests do not run against the release candidate.
>
> **Where we got lucky:** it was 2pm on a Tuesday. At 2am detection would have depended on the pager
> and mitigation would have taken 40+ minutes. The same failure at peak traffic would have exhausted
> the pool in under a minute.
>
> **Action items:**
> | # | Action | Type | Owner | Due | Ticket |
> |---|---|---|---|---|---|
> | 1 | Alert on `db_connection_pool_used / max > 0.8` | **Detect** | | 2026-03-21 | #123 |
> | 2 | Load test the RC in CI before promotion | **Prevent** | | 2026-03-28 | #124 |
> | 3 | Add pool metrics to the service dashboard | Detect | | 2026-03-21 | #125 |
> | 4 | Document the rollback in the runbook; game-day it | **Mitigate** | | 2026-04-04 | #126 |

**What makes it strong:** numbers, a timeline with derived metrics, a root cause that goes past the
proximate one to the systemic one, an explicit luck section, and action items that are
owned/dated/ticketed and span Prevent/Detect/Mitigate.

**Note the "contributing" and "systemic" layers.** Stopping at "there was a bug" produces the action
item "write better code," which is not an action item. Going one layer further produces
"pool saturation had no alert" and "load tests don't run on the RC" — both of which are fixable.

---

## Lab 3 — Chaos and DORA

### The chaos hypothesis format

> *"If I kill one app pod, the PDB and remaining replicas absorb it, and error rate stays under 0.1%
> for the duration."*

State it, test it, record the result. **If you aren't occasionally surprised, you're testing things
you already know** — which is comfortable and worthless.

Common surprises, each of which is a real finding:
- Killing a pod causes a brief error spike → **`preStop` sleep missing**, so the endpoints controller
  hadn't removed the pod before it stopped accepting connections
- Draining a node takes down the service → **no PDB**, or `minAvailable` too low
- The database restarting causes an app restart storm → **liveness checks the database** (BF-44)
- Added latency cascades into timeouts → **no circuit breaker, no timeout budget**

### DORA — the thresholds for context

| Metric | Elite | High | Medium | Low |
|---|---|---|---|---|
| Deployment frequency | On demand (multiple/day) | Weekly–monthly | Monthly–6mo | < 6mo |
| Lead time for changes | < 1 hour | 1 day – 1 week | 1–6 months | > 6 months |
| Change failure rate | 0–15% | 16–30% | 16–30% | 16–30% |
| Time to restore | < 1 hour | < 1 day | 1 day – 1 week | > 6 months |

**Your Alpha and Bravo pipelines should be "elite" on the first two by construction** — a personal
project deploys on demand with a short lead time almost by default. Say that honestly: *"my pipeline
is elite on deployment frequency and lead time, but that's easy at one-engineer scale; the hard part
at real scale is keeping change failure rate low while deploy frequency rises, which is what the test
gates and progressive delivery are for."*

**That framing — knowing why your own numbers are easy — is more impressive than the numbers.**

---

## Project Bravo — the two demonstrations

Everything else is presentation. These two **are** the project:

```bash
# 1. CVE blocks the pipeline
echo "requests==2.19.1" >> app/requirements.txt && git commit -am "test: CVE" && git push
```
Trivy fails the build naming `CVE-2018-18074`. **Screenshot the CI output with the CVE ID visible.**

```bash
# 2. Unsigned image refused
kubectl -n shop run test --image=$REGISTRY/bravo-app:unsigned
# Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request:
#   ... failed to verify image ...: no matching signatures
```
**Screenshot the rejection.**

### Why evidence beats assertion

Almost every portfolio claims "integrated security scanning." Almost none **show the pipeline
refusing to ship something**.

A screenshot of a blocked build converts a claim into a demonstration — and a demonstration is what
an interviewer will ask you to walk through. It also means the follow-up question ("what happens if
there's no fix?") lands on ground you've prepared: BF-51's triage.

### The control narrative — say why it matters

In a regulated environment, assembling evidence for an audit is a multi-week manual exercise,
repeated annually. A control narrative generated from controls that live in code turns that into a
query.

**"I can generate the audit evidence from the same code that enforces the control"** is a genuinely
valuable sentence and almost no junior candidate says it.
