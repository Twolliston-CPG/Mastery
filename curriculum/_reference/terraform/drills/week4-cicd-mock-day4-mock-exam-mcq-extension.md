# Mock Exam — MCQ Extension (Questions 41–60)

20 additional questions covering corners the first set didn't hit. Same rules — cover the answer, work through all 20, then check against `answers/mcq-extension-key.md`.

---

**41.** You want `terraform plan` to tolerate a temporarily-unreachable data source without failing the run. Best tool?
- a) `lifecycle { ignore_changes = all }`
- b) `try(data.x.y.z, "fallback")`
- c) Remove the data source
- d) `-target=data.x.y`

**42.** A provider block has `alias = "audit"`. From a module, you want to use this alias. The module declares:
```hcl
required_providers {
  aws = { source = "hashicorp/aws", configuration_aliases = [aws.audit] }
}
```
What does the **caller** write in the `module` block?
- a) `provider = aws.audit`
- b) `providers = { aws.audit = aws.audit }`
- c) Nothing — it's automatic
- d) `aliases = ["audit"]`

**43.** You store a sensitive secret using:
```hcl
variable "db_password" { type = string, sensitive = true }
```
Which of these does NOT hide it?
- a) `terraform plan` output
- b) `terraform apply` output
- c) `terraform state show aws_db_instance.prod`
- d) Error messages that interpolate the value

**44.** `terraform_remote_state` with `backend = "remote"` — what authenticates the consumer workspace?
- a) AWS STS
- b) A token from HCP (cached by `terraform login`)
- c) Nothing — it's anonymous
- d) GitHub OAuth

**45.** In HCP, two workspaces share a variable set. One overrides a variable at workspace level. Which wins?
- a) Variable set default (var set always wins)
- b) Workspace variable (lower scope wins)
- c) Neither — error
- d) Both, concatenated

**46.** `terraform apply -replace=aws_instance.web` does what?
- a) Forces an in-place update
- b) Destroys + recreates the resource on the next apply
- c) Imports a replacement
- d) Requires `-auto-approve`

**47.** `ignore_changes = [tags]` + external tagger sets a new tag. On next plan:
- a) The new tag is added to Terraform's desired state
- b) Terraform plans to remove the new tag
- c) Terraform ignores the tag change, plan is clean
- d) Apply fails

**48.** Canonical way to pin a provider for reproducibility across platforms:
- a) Commit `.terraform.lock.hcl` with checksums for each platform you run on
- b) Commit the `.terraform/` directory
- c) Use `version = "= X.Y.Z"` only
- d) Use a filesystem mirror

**49.** `terraform taint` — current status?
- a) Removed entirely in 1.0
- b) Deprecated; replaced by `terraform apply -replace=...`
- c) Still the recommended way
- d) Moved to HCP only

**50.** You removed a `resource` block from HCL. `terraform plan` wants to destroy the resource but it's a production DB. Best next step?
- a) Run `terraform apply`
- b) Add a `removed {}` block with `lifecycle { destroy = false }` before applying
- c) `terraform state rm` manually
- d) Cancel the apply and discuss with ops

**51.** `terraform providers lock` stores checksums for:
- a) Every platform Terraform is built for
- b) Only the platform where you ran the command, unless you specify `-platform` flags
- c) Cloud credentials
- d) State file versions

**52.** You fix a bug by upgrading `aws ~> 5.40` → `~> 5.60`. Local runs fine. CI fails with "inconsistent dependency lock file." Cause?
- a) CI uses a different Terraform version
- b) Lock file has checksums for macOS but CI is Linux — run `terraform providers lock -platform=linux_amd64 ...`
- c) CI has no network
- d) Rollback required

**53.** `terraform output -json` returns:
- a) The raw state file
- b) Outputs keyed by name, with `value` and `sensitive` fields
- c) Provider schemas
- d) Only non-sensitive outputs

**54.** Run Task in HCP — fires at which phase?
- a) Before init
- b) During plan (pre-apply)
- c) After apply
- d) Configurable — pre-plan, post-plan, pre-apply

**55.** You want a module to accept an `aws` provider and an `aws.us_east_1` alias. Caller does NOT pass `providers = {}`. What happens?
- a) Fallback to default provider
- b) Error — `configuration_aliases` requires explicit passing
- c) Silent miscompile
- d) Works, provider alias inherited

**56.** Policy check fails on a `hard-mandatory` Sentinel policy. Who can override?
- a) Org owner
- b) Workspace admin
- c) Nobody — run is blocked
- d) Anyone with `write` on the workspace

**57.** The workspace's execution mode is `agent`. What does this mean?
- a) HCP's shared runners execute
- b) Your self-hosted agent polls HCP and runs the plan/apply locally on your infra
- c) Runs happen in your developer terminal
- d) A CI pipeline is required

**58.** `terraform console` + `split("/", "a/b/c")` returns:
- a) `"a/b/c"`
- b) `["a", "b", "c"]`
- c) `tolist(["a", "b", "c"])`
- d) Error

**59.** Best way to allow the same HCL to produce dev vs prod differently:
- a) Multiple configs, shared modules, different root directories per env (envs/dev, envs/prd)
- b) `terraform.workspace` switching inside a single config
- c) Conditional `for_each` on environment
- d) Hardcoded per env

**60.** Given:
```hcl
variable "x" { type = string  default = null }
```
What's the type constraint effectively? Allowed inputs?
- a) Required string
- b) Optional string — any string OR null
- c) Must be empty string
- d) Compile error

---

When done, check `answers/mcq-extension-key.md`.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Mock Exam — MCQ Extension (Questions 41–60)

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
