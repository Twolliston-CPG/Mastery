# Week 23 Solutions

Working platform: [`../projects/charlie-platform/`](../../projects/charlie-platform/)

---

## Lab 1 — The controller

### Why GitHub Actions + Terraform rather than Crossplane

| | Actions + Terraform | Crossplane |
|---|---|---|
| Runtime to operate | None new | A controller in your cluster |
| Debugging | Read the workflow log | Inspect CRD status and controller logs |
| Reconciliation | On PR/merge only | **Continuous** |
| Drift correction | Scheduled plan | Automatic |
| Explainable in an interview | **Line by line** | "Crossplane does it" |

**For Charlie, Actions + Terraform is right.** The goal is demonstrating that you understand the
pattern — validate, plan, show the cost, approve, provision — and a pipeline you can walk through
line by line demonstrates that better than a framework doing it for you.

**In the ADR, name Crossplane and say when you'd switch:** when you want continuous reconciliation of
cloud resources (drift corrected automatically rather than detected nightly), or when you want the
platform API to be Kubernetes CRDs so the same RBAC and GitOps tooling applies.

### Idempotency is the test

Re-running the flow on an unchanged file must produce **no changes**. If it doesn't, something is
non-deterministic — usually a `timestamp()`, a `random_*` resource without `keepers`, or a data
source returning a different value.

```bash
terraform plan -detailed-exitcode   # 0 = no changes, 2 = changes
```
Wire that into CI as a test: provision, then plan again and assert exit 0.

---

## Lab 2 — Generated infrastructure

### Least privilege by construction — the strongest platform argument

```hcl
# From: dependencies: [{type: s3, access: readwrite}]
statement {
  actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
  resources = ["${aws_s3_bucket.this.arn}/*"]
}
statement {
  actions   = ["s3:ListBucket"]
  resources = [aws_s3_bucket.this.arn]    # bucket ARN, no /* -- week 5's lesson
}
```

A human writing this at 5pm writes `s3:*` on `*`, because it works and the deadline is real. It is
not a competence failure — it is a predictable consequence of making the secure thing more expensive
than the insecure one.

**Generated policies are least-privilege by construction.** The developer declares *what they need*
(`s3, readwrite`) and the platform decides *what that means in IAM*.

> *"The platform makes least privilege free. That's a stronger security control than any policy
> document, because it doesn't depend on anyone being careful at 5pm."*

That sentence reframes the platform from a convenience to a security control, and it is a genuinely
good thing to say in an interview.

### The declaration-to-permission mapping

| Declared | Generated |
|---|---|
| `{type: postgres}` | RDS instance, Secrets Manager secret, `secretsmanager:GetSecretValue` on **that one secret**, a security group rule from this service only, a NetworkPolicy egress rule to the DB |
| `{type: s3, access: read}` | Bucket, `s3:GetObject` on `bucket/*` and `s3:ListBucket` on `bucket` |
| `{type: sqs, name: x}` | Queue, `sqs:ReceiveMessage`/`DeleteMessage`/`GetQueueAttributes` on that queue |
| *(nothing declared)* | **No AWS permissions at all** |

That last row is the important one: a service that declares no dependencies gets an IRSA role with
**no policies attached**. Default-deny, by construction.

---

## Lab 3 — Generated observability

### Why it must not be opt-in

Observability added by hand is added when there's time, and there is never time. Generated
observability is always there, at zero marginal cost to the developer.

**"A service with no observability is not a service, it's a liability"** — and the platform is what
makes that statement enforceable rather than aspirational.

### Tier-derived configuration

```hcl
locals {
  tier_config = {
    critical = {
      min_replicas       = 3
      pdb_min_available  = 2
      slo_availability   = 99.9
      alert_severity     = "page"
      multi_az           = true
      backup_retention   = 14
    }
    standard = {
      min_replicas       = 2
      pdb_min_available  = 1
      slo_availability   = 99.5
      alert_severity     = "ticket"
      multi_az           = false
      backup_retention   = 7
    }
    experimental = {
      min_replicas       = 1
      pdb_min_available  = 0
      slo_availability   = null
      alert_severity     = null
      multi_az           = false
      backup_retention   = 1
      auto_expire_days   = 30
    }
  }
  cfg = local.tier_config[var.tier]
}
```

**One map is the entire tier abstraction.** Raising the critical SLO to 99.95% is a one-line change
that propagates to every critical service's alerts, recording rules, and dashboard — which is
something you cannot do when each team hand-wrote their own.

**`auto_expire_days` on `experimental` is the detail worth calling out:** experimental services
auto-expire after 30 days unless promoted. Without it, "experimental" becomes "production without
an SLO," which is the worst category. A platform that manages its own sprawl is thinking one step
past the happy path.

---

## Lab 4 — Cost at the moment of decision

```markdown
| Resource | Monthly |
|---|---|
| RDS db.t4g.small (Multi-AZ, tier=critical) | $58.40 |
| **Total** | **$60.70/month** |
```

A monthly cost report goes to a manager who cannot change the architecture. **A cost estimate in the
pull request goes to the person making the decision, at the moment they're making it** — and
sometimes they pick `standard` instead.

That's FinOps at the right layer: not a report, but a **visible consequence of a choice**. It is also
a genuinely good answer to "how would you control cloud costs?", because it's a mechanism rather than
a policy.

### 100% tag coverage by construction

```hcl
default_tags {
  tags = {
    Service    = var.name
    Owner      = var.owner
    Tier       = var.tier
    CostCenter = local.teams[var.owner].cost_center
    ManagedBy  = "platform"
  }
}
```
Manual tagging is always incomplete, and incomplete tagging means unattributable cost, which means
cost conversations stall at "we don't know what that is." Generated tagging makes cost attribution a
solved problem rather than an ongoing campaign.

---

## Lab 5 — Deprovisioning and errors

### The teardown order matters (week 16's lesson, again)

```
1. Delete the ArgoCD Application with prune
2. WAIT for Ingresses and LoadBalancer Services to be deleted
3. terraform destroy
```

**Step 2 is the one people miss.** The AWS Load Balancer Controller created those ALBs — Terraform
doesn't know they exist. Destroying the infrastructure without first deleting the Kubernetes objects
leaves load balancers running and billing indefinitely.

```yaml
      - name: wait for cloud resources to be released
        run: |
          kubectl delete application "$SERVICE" -n argocd --wait=true
          timeout 300 bash -c '
            until [ "$(kubectl get ingress,svc -n '"$SERVICE"' \
              --field-selector spec.type=LoadBalancer -o name 2>/dev/null | wc -l)" -eq 0 ]; do
              sleep 5
            done'
```

### The guardrails on deletion

```yaml
      - name: require explicit confirmation
        run: |
          gh pr view "$PR" --json labels -q '.labels[].name' | grep -q "confirm-delete:$SERVICE" \
            || { echo "::error::add the label confirm-delete:$SERVICE to proceed"; exit 1; }

      - name: refuse if there is no recent database snapshot
        run: |
          latest=$(aws rds describe-db-snapshots --db-instance-identifier "$SERVICE" \
            --query 'max_by(DBSnapshots,&SnapshotCreateTime).SnapshotCreateTime' --output text)
          # fail if older than 24h
```

**Deprovisioning should be as thoughtful as provisioning.** A platform that makes destruction as
frictionless as creation will eventually destroy something that mattered.

### The error message is the feature

```
services/payments-api/service.yaml line 14:
  spec.tier: "high" is not a valid tier.

  Valid tiers:
    critical      3 replicas across AZs, PDB, 99.9% SLO, pages on-call 24/7
    standard      2 replicas, 99.5% SLO, creates tickets in business hours
    experimental  1 replica, no SLO, no paging, auto-expires after 30 days

  Did you mean "critical"?

  Docs: https://platform.internal/docs/tiers
```

Four things: **where** (file and line), **what** (the invalid value), **the options with their
meaning** — not just their names — and **a suggestion**. The Levenshtein "did you mean" is twenty
lines and it's the part people remember.

**This is the most-read documentation in the platform**, because it arrives exactly when someone
needs it and it is the only docs a developer is guaranteed to see.

### The stranger test is Gate 6

> Hand the README to someone who has never seen the repo. Watch them. Do not help.

Every hesitation is a bug. This is the difference between a repo and a platform — and it is what
lets you talk about developer experience from experience rather than from a blog post.
