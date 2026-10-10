# Scenario 3 — Build the `sg_factory` Module (22 min)

## The brief

Build a reusable module that accepts a **`map(object)` of security group specs** and creates one AWS security group per entry, each with a variable-length list of ingress rules.

## Requirements

- Module name: `sg_factory`.
- Input: `security_groups` (map keyed by SG name).
- Each SG has:
  - `description` (string)
  - `ingress` (list of objects: from_port, to_port, protocol, cidr_blocks)
- **Validate** that every port range is 1 ≤ from ≤ to ≤ 65535.
- Use `for_each` at the resource level for SGs.
- Use `dynamic "ingress"` for rules inside each SG.
- Output: `map of SG name → SG id`.

## Tests

Provide a `.tftest.hcl` file with:
- A plan that verifies 2 SGs and the expected number of rules per SG.
- **A negative test** using `expect_failures = [var.security_groups]` to prove bad input is rejected.

## Starting point

**`scenario3-sg-factory-module/`**

- `versions.tf` — stub
- `variables.tf` — TODO
- `main.tf` — TODO
- `outputs.tf` — TODO
- `tests/`
  - `plan.tftest.hcl` — TODO


## Success criteria

- `terraform init && terraform validate` clean.
- `terraform test` green: at least 3 test cases pass, including the negative.

## When done

Compare to `../../answers/solutions/scenario3/`.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Tests

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
