# Week 1 — Advanced Authoring & Modules (Domains 2 & 4)

**Goal:** Full fluency in dynamic HCL, module design, and native testing — the bedrock of every Pro-level lab task.

## Daily schedule

| Day | Topic | Folder | Est. time |
|---|---|---|---|
| 1 | Complex types · validation · pre/postconditions · `check` | `day1-types-validation/` | 2–3 hr |
| 2 | `for_each` · `dynamic` · `lifecycle` · `depends_on` · provider meta-arg | `day2-foreach-dynamic-meta/` | 2–3 hr |
| 3 | HCL functions & expressions · `templatefile` · splat vs `for` | `day3-functions-expressions/` | 2–3 hr |
| 4 | Module design · composition · `moved` · `configuration_aliases` | `day4-module-design/` | 3 hr |
| 5 | Native `terraform test` · mock_provider · expect_failures | `day5-terraform-test/` | 2 hr |
| 6 | **Capstone** — build & test a multi-region `static_site` module | `day6-capstone/` | 4 hr |
| 7 | Review + catchup + self-grading | — | 2 hr |

## Ground rules

1. Do not copy-paste. Type the HCL — muscle memory matters on a lab-based exam.
2. Run `terraform plan` **before** `apply`, always. Read the plan diff.
3. After each lab: `terraform destroy -auto-approve && rm -rf .terraform*` unless otherwise noted.
4. Keep a scratch notebook for the **self-check questions** at the end of each day's README. Answering them well is how you know the day stuck.

## End-of-week gate

Before starting Week 2 you should be able to, from a blank directory and without peeking:

- [ ] Write a variable with nested `optional()` types and two `validation` blocks.
- [ ] Explain aloud when `validation` vs `precondition` vs `postcondition` vs `check` fires.
- [ ] Convert a `count`-based resource to `for_each` without losing state (hint: `moved`).
- [ ] Generate nested blocks with `dynamic` including an `iterator`.
- [ ] Pass two provider aliases into a child module.
- [ ] Write a `.tftest.hcl` that uses `mock_provider` and `expect_failures`.

If any of these feel shaky, re-do that day before moving on.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Daily schedule
- Ground rules
- End-of-week gate

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
