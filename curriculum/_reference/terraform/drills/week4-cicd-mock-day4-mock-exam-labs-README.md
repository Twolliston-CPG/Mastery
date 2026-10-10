# Mock Lab Scenarios (135 min, 6 scenarios)

Timebox yourself: **~22 min per scenario**. Don't get stuck on one — flag and move on.

## Scenario 1 — State migration under pressure

- Given a folder with local-state config + a running `aws_vpc`, migrate state to S3+DynamoDB with zero resource changes.
- Success: `terraform plan` after migration shows "No changes."

## Scenario 2 — Import + refactor

- An undocumented `aws_instance` exists (id handed to you). Import it, add `moved` blocks so the final layout is `module.compute.aws_instance.app`, and ensure `plan` shows no changes.

## Scenario 3 — Module with for_each + dynamic + validation

- Build a module `sg_factory` that accepts `map(object)` of SGs each with a list of rules.
- Must validate port ranges, use `for_each` for SGs, `dynamic "ingress"` for rules, and provide a `.tftest.hcl` with `expect_failures` for at least one invalid input.

## Scenario 4 — Cross-workspace data (HCP)

- Two HCP workspaces: `net-mock` (outputs `vpc_id`, `subnet_ids`) and `app-mock` (consumes them via `terraform_remote_state`).
- Wire state sharing + a run trigger.
- Success: changing a subnet in `net-mock` kicks off `app-mock`'s plan automatically.

## Scenario 5 — Policy-gated change

- Attach `limit-instance-size.sentinel` as `soft-mandatory` to a workspace.
- Submit a PR that adds `m5.large` — the speculative plan must fail on the policy.
- Change to `t3.medium` — plan must pass.

## Scenario 6 — Troubleshooting

- You're handed a broken config in `scenario6/`. It has three different bugs across:
  - provider version constraint
  - `for_each` unknown keys
  - `moved` block pointing at a non-existent source
- Fix all three without destroying any resources.

## Grading

Each scenario: 10 pts
- 4 pts for end state correctness
- 3 pts for approach (did you use the canonical tool?)
- 3 pts for cleanup (no orphaned resources, state intact)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Scenario 1 — State migration under pressure
- Scenario 2 — Import + refactor
- Scenario 3 — Module with foreach + dynamic + validation
- Scenario 4 — Cross-workspace data (HCP)

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
