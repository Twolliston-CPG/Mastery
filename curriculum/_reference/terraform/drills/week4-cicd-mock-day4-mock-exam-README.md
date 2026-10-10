# Week 4 · Day 4 — Mock Exam (Timed, 4 Hours)

**Goal:** Realistic simulation of the exam. Take it in one sitting. Don't peek.

## Format

- **90 min** — multiple choice (40 questions, see `mcq.md`)
- **15 min** — break
- **135 min** — lab tasks (6 scenarios, see `labs/`)

Set a timer. Take it in one sitting. Grade yourself.

## Rules

- No external references *except* `developer.hashicorp.com`.
- You can use `terraform console` and the CLI freely.
- No chatgpt / Claude / Copilot during the mock.
- If you finish early, review — don't submit.

## Grading

- MCQ: 40 questions × 1 pt = 40.
- Labs: 6 scenarios × 10 pts = 60.
- Passing: 75 / 100.

## Post-exam review

After grading, spend at least 90 minutes on the **specific domains** where you scored below 70%. See `../day5-weak-areas/` for targeted drills.

## Start

- `mcq.md` — the multiple-choice questions.
- `labs/` — six lab scenarios, each in its own folder with a `README.md` brief.
- `answers/` — answer key; open only after you're done.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Format
- Rules
- Post-exam review
- Start

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
