# Week 4 — Sensitive Data, CI/CD, Troubleshooting, Mock Exams

**Goal:** Close the gap between "I know it" and "I can do it in 4 hours under time pressure." Cross-cutting topics, pipelines, debugging, and realistic mock exercises.

## Daily schedule

| Day | Topic | Folder |
|---|---|---|
| 1 | Sensitive data · Vault integration · `sensitive = true` · ephemeral values | `day1-sensitive-vault/` |
| 2 | CI/CD with GitHub Actions · plan gating · cost/policy checks | `day2-cicd-gha/` |
| 3 | Troubleshooting playbook · `TF_LOG` · corrupted state recovery · common errors | `day3-troubleshooting/` |
| 4 | Mock exam — 4 hours, timed, mix of lab tasks + MCQ | `day4-mock-exam/` |
| 5 | Weak-area drilling based on Day 4 scores | `day5-weak-areas/` |
| 6 | Final review · exam-day logistics · relax | `day6-final-review/` |

## End-of-week gate

- [ ] Complete the mock exam in 4 hours, scoring ≥ 75% on both lab and MCQ sections.
- [ ] Explain aloud the full flow of `TF_LOG=TRACE` for a failed provider call.
- [ ] Integrate Vault dynamic secrets into a live Terraform run.
- [ ] Ship a GitHub Actions pipeline that gates merges on `terraform plan` + tfsec + policy checks.

## Exam-day checklist

- [ ] Government-issued ID ready (proctoring).
- [ ] Quiet room, clear desk, webcam access.
- [ ] Stable internet; close Zoom/Slack/Docker.
- [ ] Stretch, hydrate, breathe. You'll do fine.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Daily schedule
- End-of-week gate
- Exam-day checklist

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Terraform manages your infrastructure."* |
| ✓ | *"`plan` is a three-way comparison: the configuration (desired), the state file (what Terraform believes it created), and a refresh against the real API (what exists). Almost every confusing result is one of those three drifting from the other two."* |

**Trace it:** `terraform apply` on one resource: config → plan → API call → state write. Then say what happens if the process dies between the API call and the state write.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [the purpose of Terraform state](https://developer.hashicorp.com/terraform/language/state/purpose) — almost every confusing result is a three-way disagreement, spelled out there.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#terraform)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
