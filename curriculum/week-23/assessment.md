# Week 23 Assessment

> Closed book, 25 min. **The build is the real assessment this week.**

## Part A (15 min)
1. Why Actions + Terraform rather than Crossplane for Charlie? When would you switch?
2. What is the idempotency test for the platform, and how do you wire it into CI?
3. Explain "least privilege by construction" and why it's a stronger control than a policy document.
4. A service declares no dependencies. What AWS permissions does it get?
5. Why must observability be generated rather than opt-in?
6. What does a single `tier_config` map buy you? Give two things you can change in one place.
7. What is `auto_expire_days` on the experimental tier for, and what problem does it prevent?
8. Why is a cost estimate in the PR worth more than a monthly cost report?
9. Why does generated tagging matter for FinOps?
10. Give the deprovisioning order and explain why step 2 exists.
11. Name two guardrails on deletion.
12. What four things must a good validation error contain?

## Part B — The build (checklist)
- [ ] `service.yaml` merged → everything provisioned, zero manual steps
- [ ] Re-running on an unchanged file produces no changes
- [ ] A service with no dependencies has an IRSA role with no policies attached
- [ ] Every service gets a dashboard, alerts, an SLO, and a runbook stub automatically
- [ ] Cost estimate appears as a PR comment
- [ ] Deleting the file deprovisions cleanly, including cloud resources Kubernetes created
- [ ] Six invalid inputs each produce a helpful, actionable error
- [ ] Two example services: one minimal, one with Postgres + S3

---

# Answer key

**A1.** Actions + Terraform needs no new runtime, is debuggable by reading a workflow log, and is
**explainable line by line** — which is what Charlie is demonstrating. **Switch to Crossplane** when
you want continuous reconciliation of cloud resources (drift corrected automatically, not detected
nightly) or when you want the platform API to be Kubernetes CRDs so existing RBAC and GitOps tooling
applies to it.

**A2.** Re-run the flow on an unchanged file: `terraform plan -detailed-exitcode` must return **0**.
A non-zero result means something non-deterministic — usually `timestamp()`, a `random_*` resource
without `keepers`, or a data source whose value moves. Wire it in as a post-provision test step.

**A3.** The developer declares **what they need** (`s3, readwrite`) and the platform decides **what
that means in IAM** — generating a policy scoped to exactly that bucket. It's stronger than a policy
document because it **doesn't depend on anyone being careful at 5pm**: the secure thing is now the
free thing, and `s3:*` on `*` is no longer the path of least resistance.

**A4.** **None.** An IRSA role with no policies attached. Default-deny by construction.

**A5.** Observability added by hand is added when there's time, and there is never time. Generating
it makes it always present at zero marginal cost to the developer — so it is never the thing dropped
under deadline pressure, which is exactly when it is dropped by hand.

**A6.** It is the entire tier abstraction in one place. **You can change the critical SLO from 99.9%
to 99.95%** and every critical service's recording rules, burn-rate alerts, and dashboard update. Or
**add a topology spread constraint to all critical services** in one line. Neither is possible when
every team hand-wrote their own.

**A7.** It auto-expires experimental services after 30 days unless promoted. **Without it,
"experimental" becomes "production without an SLO"** — the worst category, because it has real users
and no reliability commitment. A platform that manages its own sprawl is thinking past the happy
path.

**A8.** A monthly report goes to a manager who **cannot change the architecture**. A cost estimate in
the PR goes to the person making the decision, **at the moment they're making it** — and sometimes
they choose `standard` instead of `critical`. It is a mechanism rather than a policy.

**A9.** Manual tagging is always incomplete, and **incomplete tagging means unattributable cost**,
which means cost conversations stall at "we don't know what that is." Generated tagging gives 100%
coverage by construction, making cost attribution a solved problem rather than an ongoing campaign.

**A10.** (1) Delete the ArgoCD Application with prune. (2) **Wait for Ingresses and LoadBalancer
Services to be gone.** (3) `terraform destroy`. (4) Archive the repo. **Step 2 exists because the AWS
Load Balancer Controller created those ALBs — Terraform doesn't know they exist.** Destroying without
it orphans load balancers that keep billing indefinitely. (Week 16.)

**A11.** A required `confirm-delete: <service-name>` label on the PR, and refusing if the RDS
instance has no snapshot within 24 hours. **Deprovisioning should be as thoughtful as provisioning** —
a platform that makes destruction frictionless will eventually destroy something that mattered.

**A12.** **Where** (file and line) · **what** is wrong (the invalid value) · **the valid options with
their meaning**, not just their names · **a suggestion** ("did you mean X?"). Plus a docs link. It is
the most-read documentation in the platform because it arrives exactly when needed.

## Scoring
| | |
|---|---|
| 10–12 + build checklist complete | On track for Gate 6. |
| 7–9 | Finish the build. The written answers matter less than the working platform this week. |
| < 7 or build incomplete | **Prioritize the build.** Week 24 is docs and polish; week 25 is interviewing. Charlie must work by Friday. |
