# Week 2 · Day 3 — Importing Existing Infrastructure

**Exam domain:** 1 (state management — "importing resources").

## Learning goals

1. **CLI `terraform import <addr> <id>`** — the classic, works in all versions, requires you to hand-write the resource block first.
2. **`import {}` block** (Terraform 1.5+) — declarative import, plan-able, reversible, survives across machines.
3. **`-generate-config-out=file.tf`** (1.5+) — generate HCL from the imported resource's state.
4. Understand what `import` does **not** do: it doesn't detect drift, doesn't copy defaults, and won't populate write-only fields (e.g. RDS passwords).
5. Importing collections: `for_each` import blocks.
6. Resources with **composite IDs** — how to look up the ID format per provider (and where: provider docs under each resource's "Import" section).

## The two import flows

### CLI (legacy, ubiquitous)
```bash
# 1. Hand-write a placeholder resource block.
#    resource "aws_instance" "web" { ami = "" instance_type = "" }
# 2. Import state.
terraform import aws_instance.web i-0123456789abcdef0
# 3. terraform plan — shows diff between real cloud state and your (empty) HCL.
# 4. Fill in HCL until plan is clean.
```

### Import block (modern, preferred)
```hcl
import {
  to = aws_instance.web
  id = "i-0123456789abcdef0"
}

# Either: write the resource block yourself.
# Or: `terraform plan -generate-config-out=generated.tf` and Terraform writes a starting point.
```

Then `terraform plan` reports the import as a plan action, and `terraform apply` executes it. After apply, **remove the `import {}` block** — it's not re-entrant.

## for_each imports
```hcl
import {
  for_each = toset(["i-111", "i-222", "i-333"])
  to       = aws_instance.fleet[each.value]
  id       = each.value
}
```

## Composite IDs — look these up cold
- `aws_iam_role_policy_attachment` → `role_name/policy_arn`
- `aws_route` → `route_table_id_destination`
- `aws_security_group_rule` (deprecated) → nasty composite
- `aws_s3_bucket_policy` → `bucket`
- Many `aws_route53_record` → `zone_id_name_type_set-identifier`

The exam will hand you a resource and an ID; knowing where to find the format saves minutes. The answer is always the provider docs under the resource name → "Import" heading.

## Exercises

1. **Hand-create** an EC2 instance via AWS console (free tier, t3.micro, default VPC). Note the instance ID.
2. **CLI import** into the `cli_import/` folder:
   - Fill in `main.tf` resource block (placeholder).
   - Run `terraform import aws_instance.manual <id>`.
   - `terraform plan` — fill in the HCL until plan is clean.
3. **Block import** into the `block_import/` folder:
   - Add the `import {}` block with the same id.
   - Run `terraform plan -generate-config-out=generated.tf`.
   - Inspect the generated HCL — note the defaults Terraform picked.
4. **Clean up** — remove the `import {}` block, re-plan, should be no changes.
5. **Destroy** — `terraform destroy` removes the instance (now that TF manages it).

## Self-check

1. What's in state after `terraform import` vs before `terraform apply` (if you import but don't apply)?
2. Can you import a resource whose HCL already exists in a different workspace/state?
3. `import {}` with `for_each` — what's the gotcha with `for_each` values that reference attributes of not-yet-imported resources?
4. You imported an RDS instance. The plan wants to change `password`. Why, and what do you do?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The two import flows
- foreach imports
- Composite IDs — look these up cold
- CLI (legacy, ubiquitous)

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
