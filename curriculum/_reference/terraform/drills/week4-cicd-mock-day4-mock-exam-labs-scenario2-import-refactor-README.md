# Scenario 2 — Import + Refactor (22 min)

## The setup

An EC2 instance exists in AWS with ID `i-REPLACEME`. It was created by hand; it's not in any Terraform state. Your task:

1. Bring it under Terraform management.
2. Place it at the final address `module.compute.aws_instance.app`.
3. `terraform plan` must show **no changes** at the end.

## Starting point

```
scenario2-import-refactor/
├── main.tf      # placeholder — needs fixing up
```

## Your task

- Use an `import {}` block (Terraform 1.5+) for the initial import.
- Use `-generate-config-out=generated.tf` to bootstrap the HCL.
- Refactor into a `module "compute"` layout.
- Use `moved {}` blocks so the state migrates without destroy/create.

## Constraints

- No `terraform state mv` CLI ops. Everything declarative in the config.
- No destroying the instance.

## Success criteria

1. The instance is tracked at `module.compute.aws_instance.app` in state.
2. `terraform plan` → No changes.
3. A git diff of your `main.tf` shows: an `import` block (later removed), a `module "compute"` block, and `moved` blocks.

## When done

Compare to `../../answers/solutions/scenario2/`.

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
