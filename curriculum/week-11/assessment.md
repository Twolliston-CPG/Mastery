# Week 11 Assessment

> Closed book, 35 min.

## Part A (15 min)
1. `count` vs `for_each` — explain the failure mode of `count` with a concrete example.
2. Name the two cases where `count` is still correct.
3. Why must a module never contain a `provider` block? Give two consequences.
4. Why `name_prefix` instead of `name`, and what does it enable?
5. `moved` block vs `terraform state mv` — three differences. Which do you prefer and why?
6. What is the acceptance criterion for a `moved` refactor?
7. `terraform_remote_state` vs SSM parameters — give the **security** argument.
8. What does `expect_failures` in `terraform test` assert, and why is it more valuable than a
   happy-path test?
9. Why is `soft_fail: true` on a security scanner worse than having no scanner?
10. Your `for_each` fails with "value depends on resource attributes that cannot be determined until
    apply." What's wrong and how do you fix it?

## Part B — Write it (10 min)
11. A `for_each` over a map of objects creating subnets with a name tag from the key
12. A `dynamic` block generating ingress rules from a variable
13. A `moved` block relocating `aws_instance.web` into `module.compute`
14. A variable validation rejecting any CIDR smaller than /16
15. A `terraform test` run block asserting a validation rejects bad input

## Part C — Judgment (10 min)
16. You inherit a module using `count` over a list of 12 subnets in production. You need to remove
    subnet #4. What do you do?
17. Checkov reports 23 findings on a repo you've inherited. The team wants to ship today. What's
    your plan?
18. A colleague proposes `source = "git::https://.../modules.git//network?ref=main"`. What's your
    objection?

---

# Answer key

**A1.** `count` addresses resources positionally. Removing the middle element of a 3-item list shifts
index 2 down to 1, so Terraform sees `[1]` as having a changed `cidr_block` (ForceNew → replace) and
`[2]` as removed (destroy). One removal, two resources destroyed. `for_each` uses stable string keys,
so removing `"b"` destroys exactly `["b"]`.

**A2.** (1) Conditional creation — `count = var.enabled ? 1 : 0`. (2) N genuinely indistinguishable
resources with no identity beyond "one of N."

**A3.** Providers are configured in the root and inherited. A provider inside a module means the
module **cannot be used with `for_each`/`count`**, and **cannot be used with provider aliases** for
multi-region or multi-account. Use `providers = { aws = aws.us_east }` at the call site instead.

**A4.** `name_prefix` lets AWS append a random suffix, so `create_before_destroy` can create the
replacement before destroying the original **without a name collision**. With `name`, replacement
fails. It enables zero-downtime replacement of security groups, launch templates, target groups, and
IAM roles.

**A5.** `moved` lives in code / is reviewable in a PR / runs in CI / is recorded in git history.
`state mv` is a local imperative command that is none of those. **Prefer `moved`** — refactoring
should be reviewable.

**A6.** `terraform plan` reports **"No changes."** Zero adds, zero destroys. Anything else means the
move is wrong.

**A7.** Reading another configuration's state via `terraform_remote_state` requires read access to
the **entire state file** — which contains every secret that configuration ever touched, in
plaintext. SSM parameters let you grant read on specific paths. It also decouples the consumer from
the producer's state layout and makes the values readable by non-Terraform tools.

**A8.** That a **validation actually rejects** bad input. A `validation` block nobody has tested might
have a typo in its condition and silently allow everything. Testing that the guardrail guards is
worth more than testing the happy path, which usually works by construction.

**A9.** Because a gate that never fails is not a gate — and the moment a *real* finding appears,
nobody notices. Worse, it creates the appearance of security scanning without the substance. If the
gate is too noisy, fix the noise with documented per-check exceptions; don't disable failure.

**A10.** The `for_each` keys depend on an attribute that isn't known until apply — typically a
resource ID. Fix by keying on something **static** (a variable, a local built from variables) and
putting the computed value in `each.value`'s consumers rather than in the key.

---

**B11.**
```hcl
resource "aws_subnet" "this" {
  for_each          = var.subnets   # map(object({ cidr = string, az = string }))
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = { Name = "subnet-${each.key}" }
}
```

**B12.**
```hcl
dynamic "ingress" {
  for_each = var.ingress_rules
  content {
    from_port   = ingress.value.port
    to_port     = ingress.value.port
    protocol    = "tcp"
    cidr_blocks = ingress.value.cidrs
    description = ingress.key
  }
}
```

**B13.**
```hcl
moved {
  from = aws_instance.web
  to   = module.compute.aws_instance.web
}
```

**B14.**
```hcl
variable "vpc_cidr" {
  type = string
  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) <= 16
    error_message = "vpc_cidr must be /16 or larger to fit /20 app subnets."
  }
}
```

**B15.**
```hcl
run "rejects_small_cidr" {
  command   = plan
  variables { vpc_cidr = "10.0.0.0/24" }
  expect_failures = [var.vpc_cidr]
}
```

---

**C16.** **Do not just edit the list.** First `terraform plan` to see the blast radius — it will want
to replace subnets 4 through 11. Then migrate to `for_each` with `moved` blocks mapping every current
index to a stable key, verify `plan` is empty, merge that refactor on its own. *Then* remove the
subnet in a second PR, where the plan shows exactly one destroy. Two PRs, each individually safe.

**C17.** Triage rather than blanket-skip. Sort by severity and by whether the finding is reachable.
Fix everything cheap and real today — encryption at rest, public access blocks, missing
logging — that's usually most of the list. For anything that genuinely cannot be fixed today, add an
**inline skip with a written justification and an owner**, and file tickets. Keep the gate
hard-failing so new findings still block. What I would not do is `soft_fail: true`, because that
silently disables the gate forever.

**C18.** `?ref=main` tracks a branch, so the module can change under you **with no commit in your
repository**. Your CI can produce a different plan tomorrow for the same code — an unreproducible
build, and a genuinely nasty incident when it happens during an unrelated deploy. Pin a tag
(`?ref=v1.2.0`) or a registry version constraint.

## Scoring
| | |
|---|---|
| 15–18 | Move on. |
| 11–14 | Redo Lab 2. `count` vs `for_each` is the most-asked Terraform question. |
| < 11 | Redo Labs 1 and 2 before week 12. Module design is the skill that gets paid. |
