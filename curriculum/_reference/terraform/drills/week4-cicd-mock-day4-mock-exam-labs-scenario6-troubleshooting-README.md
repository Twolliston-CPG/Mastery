# Scenario 6 — Troubleshooting (22 min)

You've been handed a broken Terraform config. It contains **three distinct bugs** across three different categories:

1. A **provider version constraint** bug.
2. A **`for_each`** bug (keys derived from unknown values).
3. A **`moved` block** bug (references a source that doesn't exist).

## Your task

- `terraform init && terraform validate && terraform plan`
- Fix every error without deleting the intent of the config.
- Final state: `terraform plan` shows a clean plan **and** no warnings.

## Constraints

- No copy-paste from outside this folder.
- You may read `developer.hashicorp.com` only.
- Do **not** destroy any existing resources; all work is plan-only.

## Scoring (10 pts)

| Criterion | Pts |
|---|---|
| All three bugs identified and fixed | 6 |
| Fixes use the canonical tool (no hacks) | 2 |
| Plan is clean at the end | 2 |

## Hints (only read if stuck > 10 min)

1. `terraform init` fails first — look at the error about source/version.
2. The `for_each` error message explicitly tells you what to change.
3. The `moved` block's `from` address was in an *earlier* revision that no longer exists. The fix is to delete the orphaned `moved` block.

## When you're done

Open `../../answers/scenario6-explained.md` to compare your fix to the intended solution.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Hints (only read if stuck > 10 min)
- When you're done

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
