# Postmortem: <Incident title>

- **Date:** YYYY-MM-DD
- **Duration:** HH:MM – HH:MM (<N> minutes)
- **Severity:** SEV1 / SEV2 / SEV3
- **Author:** <name>
- **Status:** Draft | Reviewed | Actions complete

> **Blameless.** Describe systems and decisions, never people's competence. The question is always
> "what made this failure possible?" — never "who screwed up?" A postmortem that assigns blame
> teaches everyone to hide information, which makes the next incident worse.

## Impact

- **Users affected:** <how many, which ones, how>
- **Duration of user-visible impact:** <N> minutes
- **Error budget consumed:** <N>% of the 30-day budget
- **Business impact:** <requests failed / revenue / SLA>

## Timeline (all times UTC)

| Time | Event |
|---|---|
| 14:02 | Deploy of `api@v1.4.2` begins |
| 14:07 | Error rate crosses 5%; `HighErrorRateBurn` fires |
| 14:09 | On-call acknowledges |
| 14:18 | Root cause identified |
| 14:22 | Rollback begins |
| 14:26 | Error rate normal. Incident closed. |

Include **detection time** (14:02 → 14:07 = 5 min) and **time to mitigate** (14:07 → 14:26 = 19 min).
Those two numbers are what you actually improve.

## Root cause

What actually caused it — mechanically. Go past the proximate cause:

> *Proximate:* the new release had a connection leak.
> *Contributing:* connection-pool exhaustion had no alert, so we learned from user reports.
> *Systemic:* load testing does not run against the release candidate.

## Detection

How did we find out? Alert, dashboard, or **a user telling us** (that last one is itself a finding).
What should have caught it sooner?

## Resolution

What actually fixed it. Was the rollback clean? Did anything need manual repair?

## What went well

Genuinely. Morale is part of reliability.

## What went badly

Facts, not blame. "The runbook was out of date." "The alert routed to a muted channel."

## Where we got lucky

The most under-used section. "It happened during business hours." "Only one region was affected."
Luck is a finding — it means the same event could be far worse next time.

## Action items

| # | Action | Type | Owner | Due | Issue |
|---|---|---|---|---|---|
| 1 | Add connection-pool saturation alert | Detect | | | #123 |
| 2 | Load test the release candidate in CI | Prevent | | | #124 |
| 3 | Update the rollback runbook | Mitigate | | | #125 |

Every action must have an **owner**, a **due date**, and a **ticket**. Actions without all three do
not happen. Classify each as Prevent / Detect / Mitigate — if every action is "Prevent," you have no
plan for the next unknown failure.
