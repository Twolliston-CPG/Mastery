# Runbook: <Alert or scenario name>

> Written for someone woken at 3am who has never seen this system. Assume no context.
> If a step requires judgment, say what the judgment is and give the default.

**Alert:** `<AlertName>` · **Severity:** SEV<N> · **Owner:** <team> · **Last tested:** YYYY-MM-DD

## What this alert means

One paragraph, plain language. What is degraded from a **user's** point of view?

## Is this urgent?

| Condition | Action |
|---|---|
| Error rate > 10% and climbing | Page the secondary. Escalate now. |
| Error rate 2–10%, stable | Work it. No escalation yet. |
| Single instance, others healthy | Not urgent. Handle in business hours. |

## First five minutes

```bash
# 1. Confirm real user impact -- don't debug a monitoring bug
curl -sf -o /dev/null -w '%{http_code}\n' https://api.example.com/health

# 2. What changed? (resolves most incidents)
kubectl rollout history deploy/api -n prod
gh run list --limit 5

# 3. Scope it
kubectl get pods -n prod -l app=api
```

## Mitigate first, diagnose second

**Stop the bleeding before finding the cause.** A clean rollback beats a clever fix during an
incident.

```bash
kubectl rollout undo deploy/api -n prod
kubectl rollout status deploy/api -n prod --timeout=120s
```

## Diagnosis

| Symptom | Likely cause | Check |
|---|---|---|
| All pods CrashLooping | Bad image / config | `kubectl logs <pod> --previous` |
| Some pods failing | Node problem | `kubectl get pods -o wide` |
| 503 from the LB | No healthy targets | `kubectl get endpoints api` |
| Slow, not failing | Saturation / downstream | `kubectl top pods`, check DB latency |

## Escalation

| When | Who |
|---|---|
| Not mitigated in 30 min | Secondary on-call |
| Data loss suspected | Engineering manager, immediately |
| Security suspected | Security on-call — **do not remediate first**, preserve evidence |

## After

- [ ] Incident channel updated with the final state
- [ ] Postmortem opened (any SEV1/SEV2)
- [ ] This runbook corrected if any step was wrong

---
*A runbook that has never been tested is fiction. Run it during a game day at least quarterly.*
