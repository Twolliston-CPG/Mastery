# Mock Exam — MCQ Extension 2 (Questions 61–80)

20 more targeted questions. Same format.

---

**61.** `terraform init -reconfigure` vs `-migrate-state` — key difference?
- a) Same command, two spellings
- b) `-reconfigure` discards existing state config and starts fresh; `-migrate-state` copies state to new backend
- c) `-reconfigure` is for providers; `-migrate-state` for backends
- d) `-migrate-state` is deprecated

**62.** You run `terraform apply` with a 30-minute `timeout` on a resource that normally takes 5 minutes. Provider actually hangs for 45 minutes. What does Terraform do at 30 min?
- a) Marks apply as failed, resource status "tainted" on next run
- b) Continues waiting indefinitely
- c) Rolls back
- d) Nothing — timeouts are advisory

**63.** `terraform workspace` CLI workspace — where are the state files stored on an S3 backend?
- a) Root of the bucket
- b) Under `env:/<workspace>/<key>`
- c) Separate buckets per workspace
- d) Always `default`

**64.** What's wrong with this code?
```hcl
resource "aws_instance" "web" {
  for_each      = var.instances
  ami           = each.value.ami
  instance_type = each.value.type
  count         = 2
}
```
- a) Missing `provider`
- b) `for_each` and `count` cannot both be set
- c) `each.value.type` should be `each.value.instance_type`
- d) Nothing wrong

**65.** `terraform init -backend=false` does what?
- a) Removes backend
- b) Skips backend config entirely (validate-only workflows)
- c) Uses local state
- d) Same as `-reconfigure`

**66.** Which flag produces machine-readable plan output suitable for piping to `jq`?
- a) `-json` on apply
- b) `terraform show -json tfplan`
- c) `terraform plan -out=tfplan && terraform show -json tfplan`
- d) Both b and c

**67.** You see `Error: Provider produced inconsistent final plan`. First suspects?
- a) Network problem
- b) Provider has a bug in a computed attribute OR you're feeding dynamic values to an attribute that expects a plan-time value
- c) State corruption
- d) Version mismatch

**68.** A module declares `required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }` and the root declares `~> 5.40`. Effective constraint?
- a) `~> 5.0` (loosest wins)
- b) `~> 5.40` (intersection — must satisfy both)
- c) Error
- d) Module wins always

**69.** Best way to share a secret value between two `aws_instance` resources in the same config without touching state twice?
- a) Two `random_password` resources
- b) One `random_password` resource, reference its `.result` attribute in both instances
- c) `terraform_remote_state`
- d) `locals`

**70.** `data "terraform_remote_state"` works with `backend = "local"` and a `path`?
- a) No
- b) Yes, but pointless in production
- c) Only with HCP
- d) Deprecated

**71.** Your config uses `provider "aws" { region = var.region }`. Plan errors with "Inconsistent conditional result types" on downstream resources. What's likely?
- a) var.region is null
- b) You're using `count` with `var.region == "us-east-1" ? 1 : 0` — types diverge
- c) Provider version mismatch
- d) Backend misconfigured

**72.** `moved { from = aws_vpc.a to = aws_vpc.b }` — you apply. Now you commit the config with `aws_vpc.b`. Later you delete the `moved` block. Run plan. What happens?
- a) Error — can't find `aws_vpc.a`
- b) Nothing — moved block has served its purpose, plan clean
- c) Re-destroys and recreates
- d) State becomes corrupt

**73.** The `vault_aws_access_credentials` data source returns creds that:
- a) Are permanent IAM user credentials
- b) Are short-lived STS credentials valid for a configurable TTL
- c) Are MFA-protected only
- d) Require a Vault token refresh each time

**74.** `-target=aws_instance.web[0]` with a `for_each` resource:
- a) Matches the instance
- b) Syntax error — use `["key"]` for for_each
- c) Matches any instance
- d) Deprecated

**75.** `terraform apply -refresh-only`:
- a) Applies without changes
- b) Updates state to match reality but makes no resource changes
- c) Same as `terraform refresh` (now deprecated)
- d) Same as `-target`

**76.** `TF_CLI_ARGS_plan="-input=false -lock-timeout=5m"` in CI — what's the effect?
- a) Nothing, not a real env var
- b) Appends those flags to every `terraform plan` invocation
- c) Replaces plan entirely
- d) Only applies on HCP

**77.** `terraform output` alone (no args) prints:
- a) All outputs from the most-recent apply's state
- b) Raw state
- c) The lock file
- d) Nothing in CI

**78.** You want a resource conditional on `var.create_enabled`. Idiomatic modern approach?
- a) `count = var.create_enabled ? 1 : 0`
- b) `for_each = var.create_enabled ? { x = {} } : {}`
- c) Both are valid; `for_each` gives a cleaner address for single-instance conditional resources
- d) Use two separate modules

**79.** HCP Terraform — what distinguishes "projects" from "organizations"?
- a) Projects are sub-orgs with separate billing
- b) Projects are grouping mechanisms within an org, with their own RBAC + variable sets
- c) Projects are legacy
- d) Same thing

**80.** The canonical refactor for a config with 10 `aws_instance` resources keyed by `count.index` when you need stable keys:
- a) `terraform state mv` each one manually
- b) Add a `moved` block per instance (`moved { from = aws_instance.x[0] to = aws_instance.x["primary"] }` …) and change the resource to `for_each`
- c) Destroy and recreate
- d) Terraform Enterprise only

---

Answers in `answers/mcq-extension-2-key.md`.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Mock Exam — MCQ Extension 2 (Questions 61–80)

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
