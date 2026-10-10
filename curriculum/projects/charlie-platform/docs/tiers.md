# Choosing a tier

You make **one** decision: how important is this service? The platform turns that into twelve
technical ones.

| | `experimental` | `standard` | `critical` |
|---|---|---|---|
| **Use it when** | Prototype, spike, internal tool | Most production services | Revenue-affecting, or user-facing at scale |
| Replicas | 1 | 2 | 3, spread across AZs |
| PodDisruptionBudget | none | minAvailable 1 | minAvailable 2 |
| SLO | none | 99.5% availability | 99.9% availability |
| Error budget / 30 days | — | 3h 36m | **43m** |
| Alerting | none | tickets, business hours | **pages on-call, 24/7** |
| Database | single-AZ, 1-day backups | single-AZ, 7-day backups | **Multi-AZ, 14-day backups** |
| Log retention | 7 days | 30 days | 90 days |
| **Lifetime** | **auto-expires after 30 days** | indefinite | indefinite |
| Typical cost/month | ~$15 | ~$45 | ~$160 |

## Why `experimental` expires

Without it, "experimental" becomes "production without an SLO" — a service with real users and no
reliability commitment, which is the worst category to be in.

You will get a reminder at 23 days. Promoting is a one-line change to `service.yaml`.

## Changing tier later

Edit `spec.tier` and open a PR. Moving **up** is a rolling change with no downtime. Moving **down**
from `critical` may briefly reduce capacity, and moving a database from Multi-AZ to single-AZ
requires a maintenance window — the plan comment will tell you.

## If you are unsure

**Pick `standard`.** It is the right answer for most services, and moving up later is easy.
