# Week 13 — Alpha Completion + Terraform Associate Prep ★ GATE 3

> **Thesis:** shipping is a skill. A project that is "almost done" in week 16 is worth nothing;
> a project shipped in week 13 with three known rough edges is worth a great deal. Finish it.

| | |
|---|---|
| **Hours** | 35–45 |
| **⚑ Deliverable** | **Project ALPHA shipped** — public, documented, diagrammed, cost-annotated |
| **★ GATE 3** | `terraform apply` from a **clean AWS account** produces a working Alpha, CI runs plan-on-PR and apply-on-merge, zero static credentials, state remote and locked |
| **Next week** | Terraform Associate exam + **applications begin** |

## The week in one figure

**Figure 13.1 — Project Alpha as a reviewer sees it.** Shipping is a skill. The figure is the gate: one command in a clean account produces a working three-tier environment, delivered by a pipeline with no static credentials, with the documentation that lets a stranger believe it.

![Figure 13.1 — Project Alpha as a reviewer sees it](content/figure-13.1-project-alpha-as-a-reviewer-sees.png)

**Say it, badge by badge:** [`content/FIGURE.md`](content/FIGURE.md) — the spoken script for each of the 13 badges, about three and a half minutes; [`content/figure-13.1-numbered-spoken.pdf`](content/figure-13.1-numbered-spoken.pdf) is the printable two-page version. Read the figure before the day plan; say the script on Friday.

---

## Day plan
| Day | Focus |
|---|---|
| Mon–Tue | ⚑ Alpha to acceptance criteria: observability module, runbooks, teardown verification |
| Wed | ⚑ Alpha docs: README, architecture diagram, ADRs, cost table, "what broke" |
| Thu | ⚑ **Deploy into a clean AWS account** to prove the one-command claim. Measure everything. |
| Fri | Terraform Associate: objectives sweep + practice exam #1 |
| Sat | Terraform Associate: practice exam #2 + weak-area remediation. **Book the exam.** |
| Sun | **Week 14 prep** — résumé, LinkedIn, target list. Read `JOB-SEARCH.md`. |

## Terraform Associate prep — 15 hours is enough

After four weeks of real Terraform you do not need a course. You need an **objectives sweep** to
close the gaps that real work skips.

**The gaps, specifically:**
| Topic | Why it's a gap |
|---|---|
| **HCP Terraform / Terraform Cloud** | Heavily examined, rarely used in a self-taught project. Workspaces, VCS-driven runs, variable sets, remote execution modes, private module registry. |
| Sentinel and policy as code | Concept-level only, but it appears |
| The exact CLI workflow | `init`/`get`/`providers`/`workspace` subcommand behavior, flag names |
| Terraform Cloud vs CLI state | Where state lives in each execution mode |
| Provisioners | You should never use them; the exam still asks |
| `terraform.io` docs navigation | Exam questions quote the docs |

**Materials:**
- `_reference/terraform/drills/week3-hcp-collab-day1-hcp-fundamentals-README.md` → `day5-sentinel-opa`
- `_reference/terraform/drills/week4-cicd-mock-day4-mock-exam-mcq.md` + `-answers-mcq-key.md`
- `_reference/terraform/drills/week4-cicd-mock-day4-mock-exam-mcq-extension.md` + key
- `_reference/terraform/drills/feynman-exam-traps.md` ← read this twice
- `_reference/terraform/drills/FLASHCARDS.md`
- The official HashiCorp study guide and exam objectives (short, and genuinely sufficient)

## Labs
[labs/LABS.md](labs/LABS.md) · [labs/FIGURES.md](labs/FIGURES.md) (figures 13.2 to 13.6, one per lab) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md)

## ★ GATE 3 — see [assessment.md](assessment.md)
