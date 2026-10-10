# Week 10 — ★ SAA EXAM · Terraform I

> **Thesis:** month 2 built it by hand so month 3 can prove it belongs in code. Terraform
> immediately after SAA is the correct order — you already know what the resources *are*, so
> Terraform is a syntax-and-lifecycle problem rather than two problems at once.

| | |
|---|---|
| **Hours** | 35–45 |
| **★ Milestone** | **AWS Solutions Architect – Associate exam** |
| **⚑ Milestone** | **Project ALPHA kickoff** |
| **Break/Fix** | BF-33, BF-35 |
| **Exit check** | `terraform import` an existing resource and plan to empty |

## Day plan
| Day | Focus |
|---|---|
| **Mon** | Final light review. `_reference/aws/phase-6-practice-review-exam-strategies-last-minute-review.md`. Early night. |
| **Tue** | **★ SIT THE EXAM.** Then take the rest of the day off. Genuinely. |
| Wed | Terraform: HCL, providers, resources, variables, outputs (Lab 1) |
| Thu | **State** — what it is, backends, locking, drift (Lab 2) |
| Fri | `import`, `state mv`, `moved` blocks + Break/Fix (Lab 3) |
| Sat | **⚑ Project Alpha kickoff** — repo, structure, first module (Lab 4) |
| Sun | Review; read week 11 |

## Reading map
- `_reference/terraform/labs/phase-1-foundations-lab-1.1-environment-setup.md` → `1.4`
- `_reference/terraform/labs/phase-2-core-lab-2.1-providers.md` → `2.4-state-management.md`
- `_reference/terraform/drills/feynman-domains-01-resource-lifecycle.md`
- `_reference/terraform/drills/feynman-domains-05-providers.md`
- `_reference/terraform/drills/week2-state-providers-day1-state-backends-README.md`
- `_reference/terraform/drills/week2-state-providers-day3-import-README.md`
- **Drill:** `_shared/drills/terraform-recall.md` — Tiers 1, 2, 5

**Free primary sources:** developer.hashicorp.com/terraform — the tutorials are genuinely good, and
the provider registry docs are the reference you will live in.

## Labs
[labs/LABS.md](labs/LABS.md) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md) ·
Project Alpha starter: [`../projects/alpha-cloud-foundation/`](../projects/alpha-cloud-foundation/)

| # | Lab | Time |
|---|---|---|
| 1 | HCL fundamentals — Terraform the week-5 instance | 3h |
| 2 | State: remote backend, locking, corruption recovery | 3h |
| 3 | Import, state manipulation, drift + Break/Fix | 3h |
| 4 | **Project Alpha kickoff** | 4h |

## Exit criteria
- [ ] SAA exam sat (pass or a scheduled retake)
- [ ] Terraform the week-5 EC2 instance; `destroy` and `apply` until it's muscle memory
- [ ] Remote backend on S3 with locking; recover from deliberately corrupted local state
- [ ] `terraform import` a console-created resource and plan to **empty**
- [ ] Change something in the console and read the drift in `plan`
- [ ] Alpha repo created with the directory structure and the first module
