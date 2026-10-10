# Week 16 — EKS and GitOps with ArgoCD

> **Thesis:** managed Kubernetes on AWS, and declarative delivery. IRSA is the week's centerpiece —
> it is the Kubernetes answer to the same question IMDSv2 answered in week 5: *how does a workload
> get cloud credentials without a credential?*

| | |
|---|---|
| **Hours** | 35–45 (incl. ~4h job search) |
| **Deliverable** | Blog post #9 — "IRSA explained: how a pod gets AWS credentials without any credentials" |
| **★ COST WEEK** | **EKS bills per hour. `terraform destroy` EVERY night. No exceptions.** |

> ## Cost discipline
> An EKS control plane is roughly **$0.10/hour = $73/month**, plus nodes, plus the ALB. Two
> deliberate weeks (16 and 19) with nightly teardown costs perhaps $15 total. Leaving one cluster
> running for the rest of the program costs several hundred dollars.
> ```bash
> bash ../_setup/03-teardown.sh     # every single night
> ```

## Day plan
| Day | Focus | Lab |
|---|---|---|
| Mon | EKS via Terraform: cluster, node groups, access entries | Lab 1 |
| Tue | **IRSA** — the mechanism, end to end | Lab 2 |
| Wed | AWS Load Balancer Controller, External Secrets, EBS CSI | Lab 3 |
| Thu | ArgoCD: apps, app-of-apps, sync waves, drift | Lab 4 |
| Fri | Break/Fix + cost review | Lab 5 |
| Sat | Deploy the week-14/15 stack to EKS via ArgoCD; 15 applications | — |
| Sun | Blog post #9; **destroy everything**; plan week 17 | — |

## Reading map
- `_reference/kubernetes/04-platform/01-gitops-argocd-README.md`
- `_reference/kubernetes/04-platform/01-gitops-argocd-exercises-01-argocd-setup.md`
- `_reference/kubernetes/04-platform/01-gitops-argocd-exercises-02-app-of-apps.md`
- `_reference/kubernetes/04-platform/01-gitops-argocd-exercises-03-applicationsets.md`
- `_reference/kubernetes/03-production/02-security-rbac-exercises-07-workload-identity.md`
- `_reference/kubernetes/02-core-ops/03-configuration-secrets-exercises-03-secrets-management.md`
- `_reference/cicd-gitops/argocd/ARGOCD_MASTERY_ROADMAP.md`
- `_reference/cicd-gitops/argocd/phase-4-sync-lifecycle-README.md`
- `_reference/devsecops/implementation/cross-cutting-secret-management.md`

## Labs
[labs/LABS.md](labs/LABS.md) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md)

## Exit criteria
- [ ] EKS provisioned by Terraform, destroyed and re-created at least twice
- [ ] A pod reading a specific S3 bucket with **no credentials mounted** — and you can explain the
      full token exchange
- [ ] ALB provisioned by an Ingress resource via the AWS Load Balancer Controller
- [ ] External Secrets pulling from AWS Secrets Manager into a Kubernetes Secret
- [ ] ArgoCD app-of-apps deployed; a Git change syncs within 3 minutes
- [ ] A manual cluster change **reverts automatically**
- [ ] **Everything destroyed; bill checked**
