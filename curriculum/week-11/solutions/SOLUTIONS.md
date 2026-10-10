# Week 11 Solutions

Reference modules: [`../projects/alpha-cloud-foundation/modules/`](../../projects/alpha-cloud-foundation/modules/)

---

## Lab 1 — Module design

### Why a module must not contain a `provider` block

```hcl
# WRONG -- inside a module
provider "aws" {
  region = var.region
}
```

Providers are configured in the **root** module and inherited. A module with its own provider block:
- cannot be used with `for_each` or `count` (Terraform refuses)
- cannot be used with multiple provider aliases (multi-region, multi-account)
- produces a deprecation warning and, on removal, an error

**The correct pattern for multi-region:**
```hcl
# root module
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}
provider "aws" {
  alias  = "eu_west"
  region = "eu-west-1"
}

module "network_us" {
  source    = "./modules/network"
  providers = { aws = aws.us_east }
}
module "network_eu" {
  source    = "./modules/network"
  providers = { aws = aws.eu_west }
}
```
The module declares what it needs in `versions.tf` via `configuration_aliases` if it needs more than
one, and the root supplies them.

### `name` vs `name_prefix`

```hcl
resource "aws_security_group" "web" {
  name_prefix = "app-web-"
  lifecycle { create_before_destroy = true }
}
```
With `name`, replacing a security group fails: Terraform tries to create the new one before
destroying the old, and the name collides. `name_prefix` lets AWS append a random suffix, so
`create_before_destroy` works and you get **zero-downtime replacement**.

This pattern — `name_prefix` + `create_before_destroy` — appears on security groups, launch
templates, target groups, IAM roles, and DB subnet groups. It is a small thing that separates
modules that work in production from modules that work once.

---

## Lab 2 — `for_each` vs `count`

### The plan output, annotated

```
# aws_subnet.bad[1] will be updated in-place
  ~ cidr_block = "10.0.2.0/24" -> "10.0.3.0/24"    # forces replacement

# aws_subnet.bad[2] will be destroyed
```

Removing `10.0.2.0/24` from position 1 shifted `10.0.3.0/24` from index 2 to index 1. Terraform
compares by **address**, so `[1]` now describes a different CIDR — and `cidr_block` is ForceNew, so
it replaces. `[2]` no longer exists in config, so it is destroyed.

**In production this is an outage.** Two subnets replaced means every ENI in them — instances, RDS,
load balancer nodes — destroyed and recreated.

### The recovery, both ways

```bash
# imperative
terraform state mv 'aws_subnet.bad[0]' 'aws_subnet.good["a"]'

# declarative -- preferred, because it is in the PR
moved {
  from = aws_subnet.bad[0]
  to   = aws_subnet.good["a"]
}
```
Verify with `terraform plan` → **"No changes."** Anything else means the move is wrong.

### When `count` is still right

Exactly two cases:

```hcl
# 1. Conditional creation
resource "aws_nat_gateway" "this" {
  count = var.enable_nat ? 1 : 0
}

# 2. N genuinely indistinguishable resources
resource "aws_instance" "worker" {
  count = var.worker_count      # no identity beyond "one of N"
}
```
Everything else: `for_each`.

**The one-sentence interview answer:**
> *"`count` addresses resources by position, so removing one from the middle shifts every index after
> it and Terraform destroys and recreates them. `for_each` addresses them by a stable string key, so
> removing one affects only that one. I use `for_each` unless I want a simple 0-or-1 conditional or
> N genuinely identical things."*

### `toset` vs a map

`for_each` accepts a `set(string)` or a `map(any)`. With a set, `each.key == each.value`. With a map
you get a meaningful key **and** a richer value:

```hcl
for_each = toset(["a", "b"])              # each.key = "a", each.value = "a"
for_each = { a = "10.0.1.0/24" }          # each.key = "a", each.value = "10.0.1.0/24"
for_each = { a = { cidr = "...", az = "us-east-1a" } }   # object values
```
**`for_each` cannot take a value that isn't known at plan time.** If the keys depend on a resource
that doesn't exist yet, you get "The for_each value depends on resource attributes that cannot be
determined until apply." The fix is to key on something static (a variable) rather than on a computed
attribute.

---

## Lab 3 — Environments and refactoring

### The dev/prod diff test

```bash
diff environments/dev/main.tf environments/prod/main.tf
```
**Every line of that diff should be an input value.** If you see a resource, a conditional, or a
`count` that exists in one and not the other, that logic belongs in a module behind a variable.

In the Alpha reference the entire diff is: environment name, VPC CIDR, AZ count, `single_nat_gateway`,
log retention, instance type, ASG sizes, `multi_az`, and backup retention. Nine values.

### `terraform_remote_state` vs SSM

```hcl
# Tight coupling -- consumer depends on the producer's STATE LAYOUT
data "terraform_remote_state" "network" {
  backend = "s3"
  config  = { bucket = "...", key = "alpha/dev/terraform.tfstate" }
}

# Loose coupling -- consumer depends on a CONTRACT
resource "aws_ssm_parameter" "vpc_id" {      # producer publishes
  name  = "/alpha/dev/vpc_id"
  type  = "String"
  value = aws_vpc.this.id
}

data "aws_ssm_parameter" "vpc_id" {          # consumer reads
  name = "/alpha/dev/vpc_id"
}
```

| | `terraform_remote_state` | SSM parameters |
|---|---|---|
| Coupling | To the state file and its output names | To a documented parameter path |
| Read access | Requires read on the **whole state file** — which contains every secret | Requires read on specific parameters |
| Consumers | Terraform only | Anything: apps, scripts, CI, other tools |

**That second row is the security argument and it's the strong one.** Granting a team
`terraform_remote_state` access to your state means granting them read access to every credential in
it. SSM lets you scope it.

This is also the pattern Project Charlie uses in week 23 for its platform contract.

---

## Lab 4 — Testing

### What `terraform test` is actually for

```hcl
run "rejects_small_vpc_cidr" {
  command = plan
  variables { vpc_cidr = "10.99.0.0/24" }
  expect_failures = [var.vpc_cidr]
}
```

The happy-path assertions are worth something, but **`expect_failures` is where the value is** — it
asserts that your guardrails actually guard. A validation block nobody has tested is a validation
block that might have a typo in its condition and silently allow everything.

`command = plan` runs are fast and create nothing. `command = apply` creates real resources and
destroys them at the end of the run — use it for integration tests only, and be aware it costs money
and time.

### Reading checkov output properly

```bash
checkov -d . --framework terraform --compact
```
For each finding, three possible responses:
1. **Fix it.** Most findings are correct — encryption at rest, public access blocks, logging.
2. **Skip it with an inline justification:**
   ```hcl
   # checkov:skip=CKV_AWS_18:The only bucket is state; access logging would recurse. See ADR-0005.
   resource "aws_s3_bucket" "state" {}
   ```
3. **Skip it globally with an ADR** (Alpha's `docs/adr/0005-checkov-exceptions.md`).

**What you must not do is `soft_fail: true`.** A gate that never fails is not a gate, and the moment
a *real* finding appears nobody notices. If the gate is too noisy to keep hard, fix the noise —
don't disable the gate.

That distinction — "I keep the gate hard-failing and document exceptions individually" — is a
genuinely good answer to "how do you handle security scanner findings?"

---

## Lab 5 — Break/Fix

### BF-36: the remediation order, once more

```bash
terraform state pull | grep -i password
```
1. **Rotate the credential.** It is compromised.
2. Encrypt the backend, enable versioning, block public access.
3. Restrict bucket access to the CI role.
4. Stop generating secrets in Terraform: `manage_master_user_password = true` on RDS.

The reason order matters: steps 2–4 prevent the *next* leak. Only step 1 addresses *this* one, and
every hour it is delayed is an hour the credential is usable.

### BF-40: the drift paragraph

> Drift is not automatically something to revert. The first question is *why*. I would check
> CloudTrail for who changed it and when, then ask them. If it was an emergency fix during an
> incident, reverting it re-breaks production — the right action is to codify the change in
> Terraform and then fix the process that made a manual change necessary. If it was accidental or
> unauthorized, revert with `terraform apply` and tighten IAM so console writes to production are not
> possible. If it is something legitimately managed by another system, add `ignore_changes` and
> document why. Automated drift *detection* is valuable; automated drift *remediation* can cause the
> second outage.
