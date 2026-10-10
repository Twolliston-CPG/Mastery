# Scenario 6 — Fix Walkthrough

## Bug #1 — wrong provider source

Original:
```hcl
aws = { source = "aws/hashicorp", version = "~> 5.0" }
```

Fix:
```hcl
aws = { source = "hashicorp/aws", version = "~> 5.0" }
```

**Why it matters:** Sources are `<namespace>/<name>`. The AWS provider is published under the `hashicorp` namespace, not `aws`. `terraform init` fails before anything else — this is the gatekeeper bug.

## Bug #2 — `for_each` with apply-time keys

Original:
```hcl
for_each = toset([for p in random_pet.names : p.id])
```

Why it fails: `random_pet.names[*].id` is computed at apply, so keys are unknown at plan. Terraform refuses.

Fix — iterate over the static `count.index` set instead, look up the id inline:

```hcl
resource "aws_s3_bucket" "scratch" {
  for_each = toset([for i in range(var.bucket_count) : tostring(i)])
  bucket   = "tfpro-scenario6-${random_pet.names[tonumber(each.value)].id}"
}
```

Alternative (cleaner if you can change `random_pet` to `for_each`):

```hcl
locals {
  bucket_keys = toset([for i in range(var.bucket_count) : tostring(i)])
}

resource "random_pet" "names" {
  for_each = local.bucket_keys
  length   = 2
}

resource "aws_s3_bucket" "scratch" {
  for_each = random_pet.names
  bucket   = "tfpro-scenario6-${each.value.id}"
}
```

**Why it matters:** `for_each` keys **must be known at plan time**. This comes up every time you try to key one resource by the ids of another.

## Bug #3 — dangling `moved` block

Original:
```hcl
moved {
  from = aws_s3_bucket.legacy
  to   = aws_s3_bucket.scratch
}
```

There's no `aws_s3_bucket.legacy` anywhere — not in this state, not in any prior state this config has managed. The `moved` block is a no-op but noisy.

Fix — delete it. `moved` blocks should only exist between the old-address-that-was-managed and the new-address. Once the move has been applied on every runner, you can remove the block; leaving orphaned blocks is a code smell.

## Final plan

After all three fixes: `terraform plan` succeeds with either:
- "N to add" (if this is a fresh run), or
- "No changes" (if you've previously applied the fixed config).

## Lesson

1. **Init errors first** — provider source/version beats everything.
2. **`for_each` needs plan-time-known keys** — if your input depends on another resource's computed attrs, restructure.
3. **`moved` blocks are transient** — delete them once they've served their purpose, and never leave a dangling one around.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Bug #1 — wrong provider source
- Bug #2 — foreach with apply-time keys
- Bug #3 — dangling moved block
- Final plan

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
