# Scenario 2 — Import + Refactor Walkthrough

## Step-by-step

```bash
# 1. Add the import block + empty resource for the generator.
# (See main.tf — uncomment the import block, leave module.compute out for now.)

terraform init
terraform plan -generate-config-out=generated.tf
# Terraform writes generated.tf with the real HCL for the instance.

# 2. Review generated.tf — confirm ami, instance_type, tags match AWS reality.
#    Move the resource block into modules/compute/main.tf.
#    Delete generated.tf.

# 3. Add module "compute" { source = "./modules/compute" } block to main.tf.

# 4. At this point, import is targeting aws_instance.app but the resource
#    now lives at module.compute.aws_instance.app. Two ways to fix:
#    a) Change the import.to to module.compute.aws_instance.app
#    b) Keep import.to = aws_instance.app, then add moved block

# Option (b) is more exam-realistic: you're simulating an older import being
# refactored after the fact.

terraform plan
# Expected: 1 to import, 1 "has moved to", 0 to add/change/destroy

terraform apply

# 5. One successful apply is all `moved` and `import` blocks need.
#    Delete both blocks — next plan should still show "No changes."
```

## Why `moved` not `state mv`

`terraform state mv` would also work, but:
- It's manual (every runner needs to remember).
- It's not in the diff.
- `moved` is idempotent and declarative.

## Final state

```hcl
module "compute" {
  source = "./modules/compute"
}
```

No `import`, no `moved`, no leftover `aws_instance.app` at the root. Clean.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Step-by-step
- Why moved not state mv
- Final state

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
