# Week 1 · Day 4 — Module Design, Composition, Versioning, Refactoring

**Exam domain covered:** 4 (Create, Maintain, and Use Terraform Modules).

## Learning goals

1. Design a **root module + two child modules** using the recommended directory structure (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`).
2. Compose modules — pass outputs of one as inputs to another *without* reaching into private state.
3. Pass provider aliases into child modules with **`configuration_aliases`** + the `providers = {}` block.
4. Consume modules from **four source types**: local path, Git, HTTPS, Terraform Registry, HCP private registry.
5. **Refactor existing flat config into modules** using **`moved`** blocks (Terraform 1.1+) so state doesn't get recreated.
6. Version modules with `version = "~> 1.2"` and a `CHANGELOG.md`.
7. Know the difference between **`count`/`for_each` on modules** (1.2+) vs inside modules.

## Directory layout

**`day4-module-design/`**

- `modules/`
  - `network/` — leaf: VPC + subnets
    - `main.tf`
    - `variables.tf`
    - `outputs.tf`
    - `versions.tf`
    - `README.md`
  - `compute/` — leaf: SGs + instances, consumes network outputs
    - `...`
- `envs/`
  - `dev/` — root: wires modules together
    - `main.tf`
    - `variables.tf`
    - `outputs.tf`
    - `versions.tf`


## Key patterns to internalize

### Provider pass-through
Inside a child module that needs explicit providers (multi-region, multi-account):
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

Root module invocation:
```hcl
module "compute" {
  source    = "../../modules/compute"
  providers = {
    aws.primary = aws            # default alias from root
    aws.replica = aws.euw1
  }
  # ...
}
```

### `for_each` on modules
```hcl
module "env" {
  source   = "./modules/env"
  for_each = toset(["dev", "stg", "prd"])
  env_name = each.key
}
```
Module addresses become `module.env["dev"]`, stable on insert — the same reason we favor `for_each` over `count` on resources.

### Source variants

| Syntax | When to use |
|---|---|
| `source = "./modules/network"` | Local dev, monorepo |
| `source = "git::https://git.example.com/tf.git//modules/net?ref=v1.2.0"` | Private Git |
| `source = "github.com/hashicorp/example"` | Public shorthand |
| `source = "terraform-aws-modules/vpc/aws"` + `version = "~> 5.0"` | Public registry |
| `source = "app.terraform.io/org/vpc/aws"` + `version = "..."` | HCP Terraform private registry |
| `source = "s3::https://s3.../mod.zip"` | S3-backed artifacts |

### `moved` blocks — refactor without destroy

You previously had:
```hcl
resource "aws_vpc" "main" { cidr_block = "10.0.0.0/16" }
```

You want to extract it into `module.network`. Add:
```hcl
moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.this
}
```

`terraform plan` now reports *Renamed* / *Moved* instead of destroy+create. After one successful apply, you can delete the `moved` block.

## Exercises

1. **Wire it up.** Run `terraform -chdir=envs/dev init && plan` — verify the graph resolves with no errors.
2. **Module for_each.** Duplicate `envs/dev` as `envs/stg`, or change the root to use `for_each` across environments — observe addresses change from `module.network` to `module.network["dev"]`.
3. **`moved` block drill.** In `envs/dev/main.tf`, there's an in-place `aws_eip` that should belong inside the `compute` module. Follow the comments to:
   - Move the resource block into the module.
   - Add a `moved` block in the root.
   - Plan — it should show "has moved to" not "will be destroyed".
4. **Publish simulation.** Change `source = "../../modules/network"` to a Git-style URL (comment out for now) — understand the `ref=` vs `version =` distinction.

## Self-check

1. Why does a module using `configuration_aliases` still need the caller to pass `providers = {}`?
2. You renamed a resource inside a module; do you need a `moved` block? (Where does the `from =` live?)
3. What's the difference between `version = "1.2.0"`, `version = "~> 1.2"`, and `version = ">= 1.2, < 2.0"`?
4. Can a child module declare its own `backend {}`? Why/why not?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Directory layout
- Key patterns to internalize
- Provider pass-through
- foreach on modules

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
