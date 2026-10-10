# Week 1 · Day 2 — `for_each`, `dynamic`, and Meta-Arguments

**Exam domains covered:** 2 (meta-arguments, dynamic configuration), 5 (provider meta-argument).

## Learning goals

1. Choose correctly between **`count`** and **`for_each`** — and know the three reasons `for_each` wins for non-trivial cases (stable identity, set/map inputs, readable plans).
2. Understand the **`for_each` type trap**: `for_each` accepts `set(string)` or `map(any)` — what happens with `toset()` on a list with duplicates, and why `for_each` values must be **known at plan time**.
3. Use **`dynamic` blocks** to generate nested blocks, including the **`content` + `iterator`** pattern and nested dynamics.
4. Apply every **`lifecycle`** meta-argument with confidence:
   - `create_before_destroy`
   - `prevent_destroy`
   - `ignore_changes` (attributes vs `all`)
   - `replace_triggered_by` (1.2+)
5. Use **`depends_on`** on resources *and* modules — and know why you should avoid it when possible.
6. Use the **`provider`** meta-argument (with aliases) to target multiple regions/accounts from one config.

## Why this matters for the exam

`for_each` + `dynamic` appear in virtually every Pro-level lab task. A classic trap: the lab hands you a list and asks you to make it idempotent — if you wrap with `toset()` without deduping semantics, apply works but plan is unstable. The lifecycle args show up in "refactor without downtime" tasks (hint: `create_before_destroy` is the answer). Provider aliasing appears in multi-region scenarios.

## `count` vs `for_each` cheat sheet

| Criterion | `count` | `for_each` |
|---|---|---|
| Input | number | `set(string)` or `map(any)` |
| Resource address | `r[0]`, `r[1]` | `r["key"]` |
| Stable on insert in middle? | **No** — shifts indices → destroys/creates | **Yes** — keyed |
| Output reference | `aws_x.r[*].id` (splat) | `values(aws_x.r)[*].id` or `[for k,v in aws_x.r : v.id]` |
| Conditional resource | `count = var.enabled ? 1 : 0` | `for_each = var.enabled ? { x = {} } : {}` |

**Rule of thumb:** `count` only for booleans (0 or 1). Collections → `for_each`.

## `for_each` pitfalls

- Values **must be known at plan time**. Using `for_each = toset([for x in aws_something.created : x.id])` where `aws_something` hasn't been created yet → `Error: The "for_each" map includes keys derived from resource attributes that cannot be determined until apply`.
- Workaround: use statically-known keys, then reference created resources by looking them up.
- `toset(list)` dedupes silently — watch for unintended collapses.

## `lifecycle` rules

| Arg | Use case | Gotcha |
|---|---|---|
| `create_before_destroy = true` | Zero-downtime replace (e.g. launch templates, IAM) | Some resources can't (unique names) — add `name_prefix` instead of `name` |
| `prevent_destroy = true` | Production DB/state bucket | Blocks even intentional `destroy` — remove the arg, re-apply, then destroy |
| `ignore_changes = [tags, ami]` | Drift you accept (external tagger, AMI refresh) | `ignore_changes = all` freezes the resource — use sparingly |
| `replace_triggered_by = [aws_x.y]` | Force replace when *another* resource changes | Requires a reference expression, not a string |

## `depends_on` — the escape hatch

- Terraform infers dependencies from **references**. If resource B reads no attribute of A but still needs A to exist first (IAM policy → Lambda, DNS → cert validation), use `depends_on = [aws_x.a]`.
- Also works at the **`module`** level: `depends_on = [module.network]`.
- Prefer implicit (reference) dependencies — `depends_on` hides intent.

## `provider` meta-argument

- Declare aliases in the provider block, reference per-resource:

```hcl
provider "aws"            { region = "us-east-1" }
provider "aws" { alias = "euw1"; region = "eu-west-1" }

resource "aws_s3_bucket" "replica" {
  provider = aws.euw1
  bucket   = "..."
}
```

- Modules accept provider aliases via `providers = { aws = aws.euw1 }` in the `module` block and declare them in `terraform.required_providers` inside the module with `configuration_aliases`.

## Exercises

1. **Plan diff test.** Inspect `security_groups.tf`. Remove `"app"` from the `security_groups` map — predict the plan before running `terraform plan`. Compare.
2. **Count vs for_each.** Change the `aws_iam_user.ops` from `for_each` to `count` and insert a new name at index 1. What does the plan show? Revert.
3. **Dynamic block.** In the SG, add a new rule type that requires nested `prefix_list_ids` — extend the dynamic block.
4. **Lifecycle.** Add `create_before_destroy = true` to `aws_launch_template.app`, rename it, then plan — note the ordering.
5. **Provider alias.** Uncomment the `aws.euw1` replica bucket — plan shows it in the right region.

## Cleanup

```bash
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
```

## Self-check

1. Why does `for_each = var.list` fail type-checking? What's the fix?
2. A resource with `prevent_destroy = true` is blocking your `destroy`. Shortest path to actually destroy it?
3. When does `ignore_changes` *not* save you from drift?
4. What's the single-line difference between a module using default provider vs an aliased one?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- count vs foreach cheat sheet
- foreach pitfalls
- lifecycle rules
- dependson — the escape hatch

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
