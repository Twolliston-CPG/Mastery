# Terraform Pro — Spaced Repetition Flashcards

Use Anki, Mochi, or a paper deck. Format: `Q → A`. Drill daily — 15 min > 2 hr cram.

## How to use

- Cover the A side; read Q aloud; answer aloud; flip.
- Mark each card **Again / Hard / Good / Easy**.
- Weeks 1–3: run through all cards once, save misses.
- Week 4: daily focus on Again + Hard pile.

---

## Domain 1 — Resource Lifecycle

**Q** What does `terraform plan -detailed-exitcode` return, and what do the codes mean?
**A** 0 = no changes, 1 = error, 2 = changes present. CI gate.

**Q** Difference between `terraform state rm` and `terraform destroy`?
**A** `state rm` forgets the resource (it lives on in the cloud); `destroy` deletes the cloud object.

**Q** Three ways to import a resource in Terraform 1.5+?
**A** CLI `terraform import`, `import {}` block, `import {}` + `-generate-config-out`.

**Q** Command to forcibly release a stuck state lock?
**A** `terraform force-unlock <LOCK_ID>` — never do this if a genuine apply is running.

**Q** What does `replace_triggered_by` take?
**A** A reference expression (resource or attribute), not a string.

**Q** How do you target a single resource for apply?
**A** `terraform apply -target=aws_instance.web` — discouraged except for recovery.

**Q** What command replaces a resource's cloud object without code changes?
**A** `terraform apply -replace=aws_instance.web`.

**Q** Where is the S3 backend's state lock stored?
**A** The DynamoDB table you configured; the key is `<bucket>/<key>-md5`.

**Q** What's the difference between `terraform plan -refresh-only` and a normal plan?
**A** `-refresh-only` updates state from the real world but does not propose resource changes.

---

## Domain 2 — Dynamic Configuration

**Q** Order of evaluation: validation, precondition, postcondition, check?
**A** validation (parse) → precondition (plan) → postcondition (apply, after create/read) → check (plan + apply, warn only).

**Q** `can()` vs `try()` — when to use each?
**A** `can()` returns bool — use in conditions. `try()` returns value or fallback — use defensively.

**Q** What types does `for_each` accept?
**A** `set(string)` or `map(any)`. Keys must be known at plan time.

**Q** Why does `for_each = toset([for r in aws_x.y : r.id])` fail?
**A** Keys derived from unknown (not-yet-created) attributes — use static keys instead.

**Q** What's the `%{~}` in a template directive?
**A** Strips whitespace/newline on that side (left `~%{` or right `%{~}`).

**Q** `optional(string, "default")` does what?
**A** Marks the attribute optional and supplies a default if caller omits it.

**Q** Difference between `sensitive = true` and `ephemeral = true`?
**A** `sensitive` redacts output but still stores in state; `ephemeral` never enters state or plan output.

**Q** A map comprehension with grouping — syntax?
**A** `{ for u in users : u.team => u.name... }` — `...` groups values into lists.

---

## Domain 3 — Collaborative Workflows

**Q** Partial backend config — why use it?
**A** `backend` blocks can't reference variables; partial + `-backend-config` at init works around.

**Q** Two workspace selection mechanisms in the `cloud {}` block?
**A** `name = "..."` for single; `tags = [...]` for multi-workspace (select with `terraform workspace select`).

**Q** Command to migrate state between backends?
**A** `terraform init -migrate-state` (with new `backend` configured).

**Q** `terraform_remote_state` requires what on the producer side?
**A** State-sharing enabled for the specific consumer workspace.

**Q** What happens when `cloud {}` and `backend "remote" {}` both exist?
**A** Terraform errors — they are mutually exclusive.

**Q** How to pre-generate multi-platform checksums in the lock file?
**A** `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 …`.

---

## Domain 4 — Modules

**Q** Required files for a module in the HashiCorp-idiomatic layout?
**A** `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`.

**Q** Module on the registry — repo naming convention?
**A** `terraform-<PROVIDER>-<NAME>`, module code at repo root.

**Q** When is `configuration_aliases` required in a module?
**A** When the module needs the caller to pass explicit provider aliases via `providers = {}`.

**Q** `moved {}` block syntax to rename a resource inside a module?
**A** `moved { from = module.a.aws_x.old  to = module.a.aws_x.new }`.

**Q** Can `moved` move a resource between two different root modules (state files)?
**A** No — both sides must be in the same state.

**Q** Difference between `source = "app.terraform.io/..."` and `source = "terraform-aws-modules/..."`?
**A** First is a private (HCP) registry; second is the public registry shorthand.

**Q** When do you use `for_each` on a `module` block?
**A** 1.2+. When you want to instantiate a module multiple times with distinct inputs and stable keys.

---

## Domain 5 — Providers

**Q** What does `~> 5.2` mean?
**A** `>= 5.2, < 6.0` — pessimistic, locks rightmost component.

**Q** What about `~> 5.2.3`?
**A** `>= 5.2.3, < 5.3.0` — locks patch.

**Q** `.terraform.lock.hcl` — commit or ignore?
**A** **Commit.** Pins versions and records per-platform checksums.

**Q** How to override the lock just for one run?
**A** `terraform init -upgrade`.

**Q** Two ways to authenticate the AWS provider besides static keys?
**A** `profile = "..."` (shared credentials), `assume_role { ... }` (STS with optional OIDC).

**Q** How do you declare two `aws` providers with different configs in the same root module?
**A** Two `provider "aws" {}` blocks, the second with `alias = "..."`. Reference with `provider = aws.alias`.

**Q** Env var to turn on full request/response logging?
**A** `TF_LOG=TRACE` (or DEBUG/INFO/WARN/ERROR). Optional `TF_LOG_PATH=./tf.log`.

**Q** `terraform providers schema -json` — what's it for?
**A** Full JSON schema for every installed provider — authoritative source for resource attrs.

---

## Domain 6 — HCP Terraform

**Q** Three run workflows in HCP?
**A** CLI-driven, VCS-driven, API-driven.

**Q** Speculative plan — when does it fire?
**A** On every PR targeting the VCS workspace's tracked branch. It can't apply.

**Q** Env vars needed for dynamic AWS creds via OIDC in HCP?
**A** `TFC_AWS_PROVIDER_AUTH=true` plus `TFC_AWS_RUN_ROLE_ARN=<arn>` (and optionally `TFC_AWS_PLAN_ROLE_ARN`/`TFC_AWS_APPLY_ROLE_ARN`).

**Q** Three Sentinel enforcement levels?
**A** advisory (warn), soft-mandatory (block, admins override), hard-mandatory (block, nobody overrides).

**Q** Where does the Sentinel policy check happen in a run?
**A** After plan, after cost estimation, before apply (before approval).

**Q** What's a Run Task?
**A** A webhook integration called during a run phase; lets any external scanner (Checkov, tfsec) pass/fail the run.

**Q** Agent execution mode — when?
**A** When HCP can't reach your cloud directly (private network, VPN, internal endpoints).

**Q** Variable precedence in HCP (low → high)?
**A** Var-set default → workspace vars → `.auto.tfvars` → CLI `-var`/`-var-file`.

**Q** What does state sharing control?
**A** Which other workspaces are allowed to read this one's outputs via `terraform_remote_state`.

**Q** Run triggers chain what?
**A** Workspace B auto-runs after workspace A applies (configured on B).

---

## Cross-cutting

**Q** What's in state that isn't in config (three examples)?
**A** Resource IDs, provider-computed attrs (e.g. public_ip), serial/version numbers.

**Q** Why is state sensitive?
**A** Contains secrets in plaintext (DB passwords, keys, tokens) by default.

**Q** Which command lets you inspect state as JSON?
**A** `terraform show -json | jq …` or `terraform state pull | jq …`.

**Q** How to test a module with zero cloud calls?
**A** `.tftest.hcl` + `mock_provider` block (Terraform 1.7+).

**Q** Validate variable-level rejection in a test?
**A** `expect_failures = [var.name_of_variable]` inside the `run` block.

**Q** What does `TF_IN_AUTOMATION=1` do?
**A** Suppresses interactive hints in output. Doesn't change behavior.

**Q** Fastest way to check an HCL expression's value?
**A** `terraform console` — REPL over your config.

---

## Exam-day "oh no" reminders

**Q** Cloud for CloudFront ACM certs?
**A** Must be **us-east-1** no matter where the rest of the stack is.

**Q** Why can't `backend` block reference `var.X`?
**A** Backend resolves **before** variables do.

**Q** `for_each` keys derived from unknown values — what error?
**A** "The 'for_each' map includes keys derived from resource attributes that cannot be determined until apply."

**Q** How do you destroy a resource with `prevent_destroy = true`?
**A** Remove/change the lifecycle arg, re-apply, then run destroy.

**Q** Imported RDS plans to change password — why and fix?
**A** Real password is write-only, Terraform has no value. Fix: match in HCL or `ignore_changes = [password]`.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Domain 1 — Resource Lifecycle
- Domain 2 — Dynamic Configuration
- Domain 3 — Collaborative Workflows
- Domain 4 — Modules

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
