# Week 23 — The Platform Build

> **Thesis:** everything from months 1–5 composes here. Charlie is not a new set of technologies —
> it is the Terraform, CI/CD, GitOps, security gates, and observability you already built, wired
> together behind one contract.

| | |
|---|---|
| **Hours** | 35–45 (incl. ~6h job search) |
| **⚑ Charlie** | PR-driven onboarding working end to end |
| **Break/Fix** | A malformed `service.yaml` — the error message *is* the feature |

## The week in one figure

**Figure 23.1 — One pull request to a running service.** Nothing here is new technology. It is Terraform, CI, GitOps, the security gates, and observability from months 1 to 5, wired together behind one contract. Follow the blue path from a file to a service with zero manual steps.

![Figure 23.1 — One pull request to a running service](content/figure-23.1-one-pull-request-to-a-running.png)

**Say it, badge by badge:** [`content/FIGURE.md`](content/FIGURE.md) — the spoken script for each of the 10 badges, about three and a half minutes; [`content/figure-23.1-numbered-spoken.pdf`](content/figure-23.1-numbered-spoken.pdf) is the printable two-page version. Read the figure before the day plan; say the script on Friday.

---

## Day plan
| Day | Focus | Lab |
|---|---|---|
| Mon | The platform controller: validate → plan → provision | Lab 1 |
| Tue | Generated infrastructure: namespace, IAM, ECR, DNS, ArgoCD app | Lab 2 |
| Wed | Generated observability: dashboard, alerts, SLO, runbook stub | Lab 3 |
| Thu | Generated pipeline + FinOps: cost estimate in the PR | Lab 4 |
| Fri | Deprovisioning, error handling, the two example services | Lab 5 |
| Sat | End-to-end run; 20 applications | — |
| Sun | Review; plan week 24 | — |

## Reading map
- `_reference/platform-engineering/labs-lab-07-self-service-infrastructure-workflows.md`
- `_reference/platform-engineering/labs-lab-08-developer-onboarding-automation.md`
- `_reference/platform-engineering/labs-lab-03-platform-cli-development.md`
- `_reference/platform-engineering/labs-lab-06-policy-as-code-governance.md`
- `_reference/kubernetes/04-platform/03-developer-platform-exercises-02-crossplane-self-service.md`
- `_reference/kubernetes/04-platform/03-developer-platform-exercises-04-platform-guardrails.md`
- `_reference/devsecops/implementation/appendix-new-service-checklist.md`
- `_reference/devsecops/implementation/appendix-cost-analysis.md`

## Labs
[labs/LABS.md](labs/LABS.md) · [labs/FIGURES.md](labs/FIGURES.md) (figures 23.2 to 23.7, one per lab plus the Go deeper labs) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md) · · [Kubernetes thread](../KUBERNETES-THREAD.md#week-23)
Reference: [`../projects/charlie-platform/`](../projects/charlie-platform/)

## Exit criteria
- [ ] Adding `services/<name>/service.yaml` and merging provisions everything
- [ ] **Zero manual steps** between merge and a running service
- [ ] A malformed file fails fast with an error that says exactly how to fix it
- [ ] Every service automatically gets a dashboard, alerts, an SLO, and a runbook stub —
      **the developer does not opt in**
- [ ] A cost estimate appears as a PR comment before merge
- [ ] Deleting the file deprovisions cleanly
- [ ] Two example services exist, both provisioned through the platform
