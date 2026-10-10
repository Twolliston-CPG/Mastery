# Domain 4 — Modules (the Teacher's Voice)

---

## 1. Idiomatic layout

**`module/`**

| File | What it is |
|---|---|
| `main.tf` | resources |
| `variables.tf` | inputs |
| `outputs.tf` | exports |
| `versions.tf` | terraform + provider version constraints |
| `README.md` | required for registry |
| `examples/` | registry requires at least one |


**Analogy:** A library's public interface: `variables.tf` is the function signature, `outputs.tf` is the return value, `main.tf` is the body, `README.md` is the docstring.

**Gotcha:** Registry repos must be named `terraform-<PROVIDER>-<NAME>` (e.g., `terraform-aws-vpc`), public, tagged with semver.

**Self-test:** Your module's `README.md` is missing. Registry rejects it. Why does the registry care?

**Lab:** `week1/day4-module-design`

---

## 2. `configuration_aliases` + provider pass-through

A module that needs multi-region/multi-account providers declares:

```hcl
# modules/compute/versions.tf
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.primary, aws.replica]
    }
  }
}
```

The caller then passes them explicitly:

```hcl
module "compute" {
  source = "../../modules/compute"
  providers = {
    aws.primary = aws        # default alias from root
    aws.replica = aws.euw1
  }
}
```

**Analogy:** A function that takes two DB connections as parameters — the caller must supply both, by name.

**Gotcha:** If the module declares `configuration_aliases` but the caller omits `providers = {}`, init fails with "module requires provider aws.replica". The caller's root provider aliases don't auto-flow.

**Self-test:** Why can't the module just define its own `provider "aws" { alias = "replica" }` block?

**Lab:** `week1/day4-module-design`

---

## 3. Module source types

| Source | Syntax | `version` arg? |
|---|---|---|
| Local | `source = "./modules/net"` | No |
| Git (HTTPS) | `source = "git::https://…git?ref=v1.2.0"` | No — use `?ref=` |
| GitHub shorthand | `source = "github.com/org/repo//path"` | No |
| Public registry | `source = "terraform-aws-modules/vpc/aws"` | Yes |
| HCP private registry | `source = "app.terraform.io/acme/vpc/aws"` | Yes |
| S3 archive | `source = "s3::https://…/mod.zip"` | No |

**Gotcha:** `version =` only works with registries. Git sources pin via `?ref=tag`. Mixing will error.

**Self-test:** `source = "terraform-aws-modules/vpc/aws"` with `version = "~> 5.0"` — which registry resolves this?

---

## 4. `moved {}` — refactor into modules without destroying

```hcl
# Before: root had aws_vpc.main.
# Now you're extracting to module.network.

moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.this
}
```

`terraform plan` reports **"has moved to"** instead of destroy+create. After one successful apply, delete the `moved` block.

**Gotcha:** `moved` only works within the same state file. Cross-state refactors need `state rm` + `import`.

**Self-test:** You rename a resource *inside* a module (`aws_vpc.old` → `aws_vpc.new`). Where does the `moved` block live — in the module, or in the caller?

---

## 5. `for_each` on modules (since 1.2)

```hcl
module "env" {
  source   = "./modules/env"
  for_each = toset(["dev", "stg", "prd"])
  env_name = each.key
}
```

Addresses become `module.env["dev"]`, `module.env["stg"]`. Stable under insert/remove — same reason you favor `for_each` over `count` for resources.

**Gotcha:** Converting `count` → `for_each` on a module (or vice versa) **changes the address**. You need a `moved` block for every instance, or you'll destroy and recreate.

**Self-test:** You had `module "env"` with `count = 3`. You switch to `for_each = toset(["a","b","c"])`. How many `moved` blocks, and what do they say?

---

## 6. `terraform test` + `mock_provider`

```hcl
# tests/plan.tftest.hcl
mock_provider "aws" {}

run "valid_cidr" {
  command = plan
  variables {
    vpc_cidr = "10.0.0.0/16"
  }
  assert {
    condition     = module.network.vpc_id != ""
    error_message = "VPC not planned"
  }
}

run "reject_bad_cidr" {
  command = plan
  variables {
    vpc_cidr = "not-a-cidr"
  }
  expect_failures = [var.vpc_cidr]
}
```

**Analogy:** Unit tests with a stubbed AWS — no billing, fast, CI-safe.

**Gotcha:** `expect_failures` lists the expression that *should* reject (usually a `validation` block's variable). If the run succeeds unexpectedly, the test fails.

**Self-test:** Your test expects `var.instance_type` to be rejected. What do you put in `expect_failures`?

**Lab:** `week1/day5-terraform-test`

---

## 7. Version pinning — `~>` semantics

| Constraint | Means |
|---|---|
| `1.2.0` | exactly `1.2.0` |
| `~> 1.2` | `>= 1.2, < 2.0` (lock major) |
| `~> 1.2.3` | `>= 1.2.3, < 1.3.0` (lock minor) |
| `>= 1.2, < 2.0` | explicit range |

**Rule of thumb:** Lock major in modules (`~> 5.0`), lock minor in root when stability matters more than features (`~> 5.3.0`).

**Self-test:** `~> 1.2` allows which of `1.2.9`, `1.3.0`, `2.0.0`?

---

## Flashcards

Domain 4 in `/FLASHCARDS.md` — 7 cards.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Idiomatic layout
- configurationaliases + provider pass-through
- Module source types
- moved {} — refactor into modules without destroying

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
