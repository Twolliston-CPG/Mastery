# Week 4 · Day 5 — Targeted Weak-Area Drilling

Based on your Day 4 mock exam results, drill the domains where you scored below 70%.

## Scoring template

| Domain | MCQ correct / total | Lab score / max | Verdict |
|---|---|---|---|
| 1 — Resource lifecycle | __ / 7 | __ / 10 | |
| 2 — Dynamic configuration | __ / 7 | __ / 10 | |
| 3 — Collaborative workflows | __ / 7 | __ / 10 | |
| 4 — Modules | __ / 6 | __ / 10 | |
| 5 — Providers | __ / 6 | __ / 10 | |
| 6 — HCP Terraform | __ / 7 | __ / 10 | |

## Targeted re-drills

If weak on…

- **Domain 1 (state)** → redo Week 2 Days 1–3 capstone style from scratch.
- **Domain 2 (dynamic config)** → rebuild Week 1 Day 3 + Day 5 tests entirely.
- **Domain 3 (collab/remote state)** → rebuild Week 3 Day 1 + add a `terraform_remote_state` consumer.
- **Domain 4 (modules)** → redo Week 1 Day 6 capstone from scratch, fully.
- **Domain 5 (providers)** → read every page under developer.hashicorp.com/terraform/language/providers/* and practice `terraform providers lock` with three platforms.
- **Domain 6 (HCP)** → redo Week 3 Day 6 capstone with a fresh org.

## Drill cadence

- 2 hours re-drilling the weakest domain.
- 1 hour on the 2nd weakest.
- 30 min of flash-style practice (re-do 10 random MCQ questions from the mock).

## Re-take the mock

If time permits, a second mock in Day 6 morning with a fresh mindset. Aim for +10 pts over the first attempt.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Scoring template
- Targeted re-drills
- Drill cadence
- Re-take the mock

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
