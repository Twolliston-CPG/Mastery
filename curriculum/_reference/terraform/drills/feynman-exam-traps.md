# Exam Traps — Patterns HashiCorp Uses

Distilled from the 80 MCQs + 6 lab scenarios in this repo. If an MCQ "feels obvious," slow down — these are the patterns it's built on.

---

## Trap 1 — "Destroy" vs "Stop Managing"

Question form: *"How do you remove X from management without deleting the cloud object?"*

Wrong-but-tempting: `terraform destroy -target=X`, `terraform state delete`.
Right: **`removed {}` block** (modern) or **`terraform state rm`** (CLI).

Why people miss it: "remove" and "destroy" sound like synonyms in English. They're opposite operations in Terraform.

---

## Trap 2 — Plan-time vs apply-time knowability

Question form: *"Why does `for_each = toset([for r in aws_x.y : r.id])` fail?"*

Wrong-but-tempting: "the list is empty," "`toset` needs a map."
Right: **keys must resolve at plan time; resource IDs aren't known until apply.**

Any `for_each`, `count`, or `depends_on` trick usually boils down to: **did this value resolve at plan?**

---

## Trap 3 — Backend can't reference variables

Question form: *"Why can't `backend "s3" { bucket = var.state_bucket }` work?"*

Right: **Backends resolve before variables are evaluated.** Use partial backend config + `-backend-config=...` at init.

Same reason `terraform { cloud { organization = var.org } }` errors.

---

## Trap 4 — `moved` scope

Question form: *"Which of these is `moved` unable to do?"*

`moved` **cannot cross state files.** Everything else it can do — rename, lift-into-module, convert count→for_each, change for_each keys.

Cross-state refactor = `state rm` on one side + `import` on the other.

---

## Trap 5 — The three condition blocks that block vs the one that doesn't

Question form: *"Which block lets the run continue even on failure?"*

Answer: **`check` block** (warning only). Everything else — `validation`, `precondition`, `postcondition` — halts the run.

---

## Trap 6 — `sensitive` doesn't mean "not in state"

Question form: *"Your DB password is marked `sensitive = true`. Is it safe from someone with read access to the state bucket?"*

**No.** Sensitive only redacts from CLI output. State still has it in plaintext. Bucket ACL + encryption + `ephemeral = true` (where applicable) are the real defenses.

---

## Trap 7 — Provider version resolution

Question form: *"Root: `~> 5.0`. Module A: `>= 5.3`. Module B: `~> 5.2.0`. Which version installs?"*

Terraform picks the highest version satisfying **all** constraints. Intersection of:
- `~> 5.0` → `>= 5.0, < 6.0`
- `>= 5.3`
- `~> 5.2.0` → `>= 5.2.0, < 5.3.0`

Intersection: `>= 5.3 AND < 5.3.0` = **empty** → init fails.

Trap: the MCQ may list `5.2.9` as a choice ("last compatible version") but constraint B excludes it.

---

## Trap 8 — `replace_triggered_by` takes a reference, not a string

Wrong: `replace_triggered_by = ["aws_launch_template.web.id"]`
Right: `replace_triggered_by = [aws_launch_template.web]` (or `.latest_version`)

---

## Trap 9 — `configuration_aliases` + the caller's `providers = {}`

Question form: *"Module declares `configuration_aliases = [aws.primary, aws.replica]`. Root module has `provider "aws"` and `provider "aws" { alias = "euw1" }`. Init fails. Why?"*

Answer: the caller never specified `providers = { aws.primary = aws, aws.replica = aws.euw1 }` on the module block. Root's aliases **don't auto-flow**; the mapping is explicit.

---

## Trap 10 — HCP speculative plan ≠ apply-capable

Question form: *"A PR shows a plan; the team approves the PR. Does HCP apply?"*

No. Speculative plans can **never** apply. The merge triggers a new, real plan → apply.

---

## Trap 11 — OIDC env vars

Question form: *"What three env vars enable HCP OIDC for AWS?"*

- `TFC_AWS_PROVIDER_AUTH=true`
- `TFC_AWS_RUN_ROLE_ARN=...` (the default)
- Optional: `TFC_AWS_PLAN_ROLE_ARN`, `TFC_AWS_APPLY_ROLE_ARN` for least-priv phase separation.

**NOT** needed: `AWS_ACCESS_KEY_ID` (HCP injects creds).

---

## Trap 12 — Sentinel runs **after** cost estimation, **before** apply approval

Question form: *"In which order does HCP evaluate plan, cost estimate, Sentinel, apply?"*

Order: **plan → cost estimate → Sentinel → approval → apply.**

---

## Trap 13 — Variable precedence with priority flag

Question form: *"Workspace sets `env = "prod"`. Priority variable set at org sets `env = "stg"`. What runs?"*

Priority variable sets **flip to top of precedence**, so `"stg"` wins. Without the priority flag, workspace var would win.

---

## Trap 14 — Lockfile platforms

Question form: *"Mac dev commits the lockfile. Linux CI fails `init` with 'checksum missing for linux_amd64'. What's the fix?"*

Answer: regenerate with `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 …` on **any** machine, commit the updated lock. Do not `init -upgrade` in CI as a workaround — that silently bumps versions.

---

## Trap 15 — Imported RDS plans to change password

Real password is write-only → Terraform has no value in state → plan shows drift.

Fix: either set `password = "<real>"` in HCL (use sensitive var) OR `lifecycle { ignore_changes = [password] }`.

---

## Trap 16 — `terraform init -upgrade` is destructive

Question form: *"You ran `terraform init -upgrade` to fix a checksum error. What did you also do?"*

You overrode the lockfile's pinned versions. Your team now resolves different versions than before. If the bump was unintended, revert the lockfile in git.

---

## Trap 17 — ACM + CloudFront region

CloudFront's control plane is only in us-east-1. ACM certs for CloudFront must be there too — even if the app lives in eu-west-1.

```hcl
provider "aws" { alias = "us_east_1"  region = "us-east-1" }

resource "aws_acm_certificate" "cf" {
  provider = aws.us_east_1
  # ...
}
```

---

## Trap 18 — `data "terraform_remote_state"` can only read outputs

Not resources directly. If the producer workspace doesn't `output "vpc_id"`, you can't read `.resources.vpc.id`.

---

## Trap 19 — `force-unlock` after a real apply is running

Never. You'll corrupt state by letting a second apply write while the first is mid-flight. Only force-unlock when you're 100% sure the lock is stranded (process died, SIGKILL'd the CLI, etc.).

---

## Trap 20 — `-target` discouragement

Question form: *"When is `-target` the right answer?"*

Almost never. It's a recovery tool — plan shows changes outside your target, state can drift. Acceptable uses: breaking dependency cycles during refactor, emergency recovery. Default answer: **don't use it.**

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Trap 1 — "Destroy" vs "Stop Managing"
- Trap 2 — Plan-time vs apply-time knowability
- Trap 3 — Backend can't reference variables
- Trap 4 — moved scope

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
