# Week 1 · Day 5 — Native `terraform test` Framework

**Exam domains covered:** 2 (dynamic configuration validation), 4 (module quality).

## Learning goals

1. Write `*.tftest.hcl` files using `run`, `variables`, and `assert` blocks.
2. Pick between `command = "plan"` (fast, no cloud calls) and `command = "apply"` (real resources).
3. Use **`mock_provider`** (Terraform 1.7+) to test modules without any cloud.
4. Override specific resources/data with **`override_resource`**, **`override_data`**, **`override_module`**.
5. Chain `run` blocks so later assertions reference outputs of earlier runs (state continuity).
6. Know how `terraform test` integrates with CI — exit codes, `-verbose`, `-filter`.

## Test file anatomy

```hcl
# module/tests/basic.tftest.hcl
variables {
  name       = "test"
  cidr_block = "10.0.0.0/16"
}

run "plan_only_validates_inputs" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Expected 2 public subnets by default."
  }
}

run "apply_happy_path" {
  command = apply

  assert {
    condition     = output.vpc_cidr == "10.0.0.0/16"
    error_message = "VPC CIDR mismatch."
  }
}
```

## Mocking providers (no AWS calls)

```hcl
mock_provider "aws" {
  mock_resource "aws_vpc" {
    defaults = { id = "vpc-mock-123", arn = "arn:aws:ec2:::vpc/vpc-mock-123" }
  }
  mock_data "aws_availability_zones" {
    defaults = { names = ["us-east-1a", "us-east-1b"] }
  }
}

run "fast_plan_with_mocks" {
  command = plan
  providers = { aws = aws }
  assert {
    condition     = aws_vpc.this.id == "vpc-mock-123"
    error_message = "Mock did not apply."
  }
}
```

- Run with `terraform test` from the module root (or from the root module).
- By default, tests execute in the order of the files and within each file in the order of `run` blocks.
- Filter: `terraform test -filter=tests/basic.tftest.hcl -verbose`.

## Exercises

1. **Plan-only run.** `cd module && terraform test` — two tests should pass (defaults + invalid input rejection).
2. **Break it on purpose.** Change `public_subnet_count`'s validation upper bound from 6 to 2, rerun tests — see which assertion now fails and *why* it fails at plan time.
3. **Add an apply test.** Add a `run "apply"` block that provisions in us-east-1. Only run it if you're OK spending pennies and destroying promptly.
4. **Add a mock test.** Create `tests/mocks.tftest.hcl` with a `mock_provider "aws"` (see snippet above). Ensure it runs in under a second with no real AWS calls.

## Commands

```bash
cd module
terraform init
terraform test               # run all
terraform test -verbose      # full plan/apply diff per run
terraform test -filter=tests/basic.tftest.hcl
```

## Self-check

1. What's the key difference between a `plan` run and an `apply` run in test terms?
2. If `run "a"` applies and `run "b"` applies after it, does `run "b"` see `run "a"`'s state?
3. When would you prefer `override_resource` over a full `mock_provider`?
4. Can test runs use variables that aren't declared in the module?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Test file anatomy
- Mocking providers (no AWS calls)

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
