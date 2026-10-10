# Scenario 1 — State Migration Under Pressure (22 min)

## The setup

You inherited a Terraform config that uses **local state** to manage a production VPC. Ops wants it migrated to S3 + DynamoDB immediately — and they **cannot tolerate any resource being destroyed or recreated**.

## Starting point

**`scenario1-state-migration/`**

| File | What it is |
|---|---|
| `main.tf` | The current configuration, using local state |
| `terraform.tfstate` | Present after you apply once to create the baseline |

You also have access to an existing state bucket + lock table (use whatever you set up in Week 2 Day 1's bootstrap, or the values in `terraform.tfvars.example`).

## Your task

1. Apply the current config (local state) so you have a real VPC and subnet to protect.
2. Migrate state to the S3 backend with DynamoDB locking.
3. Verify that `terraform plan` shows **No changes.**
4. Prove locking works (two terminals, second one should fail).

## Constraints

- The `main.tf` **must not change** functionally — same VPC, same CIDR, same subnet.
- You may add a `backend` block, but variables cannot be used inside it.
- Pass backend config via `-backend-config` at init (partial config).

## Success criteria

- State file has moved to S3 (key `week4-scenario1/terraform.tfstate`).
- `terraform state list` shows the same 2 resources.
- `terraform plan` — No changes.
- Second concurrent plan errors on lock.

## When done

Compare to `../../answers/solutions/scenario1/`.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The setup

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
