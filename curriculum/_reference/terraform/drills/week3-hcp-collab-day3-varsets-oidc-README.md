# Week 3 · Day 3 — Variable Sets & Dynamic Provider Credentials (OIDC)

**Exam domain:** 6.

## Learning goals

1. **Workspace variables** vs **variable sets** — when to use each.
2. **Terraform variables** vs **environment variables** (the two categories).
3. **Sensitive** flag and **HCL** flag on variables.
4. **Variable precedence** in HCP runs (env → tfvars → var-set → workspace → CLI `-var`).
5. **Dynamic provider credentials** via OIDC — no more static AWS keys in workspaces.
6. Configure an **AWS IAM role** with an OIDC trust policy for `app.terraform.io`.
7. Set required workspace env vars: `TFC_AWS_PROVIDER_AUTH`, `TFC_AWS_RUN_ROLE_ARN`.

## Variable sets — when to use

- Reusable container of variables attached to one-or-many workspaces.
- Global var sets apply to every workspace in the org.
- Project-scoped var sets apply to workspaces in that project.
- Use for shared things: `aws_region`, tags, a common provider role ARN.

Precedence (lowest → highest):
1. Variable set defaults
2. Workspace-level variables
3. `.auto.tfvars` / `terraform.tfvars`
4. `-var` / `-var-file` on CLI (overrides everything)

## Env vars vs Terraform vars

| Category | Example | Purpose |
|---|---|---|
| Terraform | `vpc_cidr = "10.0.0.0/16"` | `var.vpc_cidr` in HCL |
| Environment | `AWS_REGION=us-east-1` | Exposed to provider SDKs & TF runtime |

`TFC_AWS_*`, `TF_LOG`, provider credentials — all go under **environment**.

## Dynamic credentials via OIDC — the sequence

1. **AWS side:** create an IAM OIDC identity provider trusting `app.terraform.io`.
2. **AWS side:** create an IAM role with a trust policy referencing that provider, scoped to your HCP org/workspace.
3. **HCP side:** set these env vars on the workspace:
   - `TFC_AWS_PROVIDER_AUTH = true`
   - `TFC_AWS_RUN_ROLE_ARN = arn:aws:iam::<acct>:role/<role>`
   - (Optional) `TFC_AWS_PLAN_ROLE_ARN`, `TFC_AWS_APPLY_ROLE_ARN` — different roles per phase.
4. The AWS provider detects these and swaps the token — no static keys anywhere.

**This is one of the highest-value Pro exam topics.** Practice setting it up once cold.

## Exercises

### Part A — Variable sets
1. In HCP UI → Settings → Variable Sets → Create.
2. Name: `aws-defaults`. Add:
   - env `AWS_DEFAULT_REGION = us-east-1` (sensitive = off)
   - tf `default_tags = { ManagedBy = "terraform" }` (HCL = on)
3. Apply to your project `tfpro-study`.
4. In a workspace, confirm those vars show up as inherited.

### Part B — OIDC to AWS (the crown jewel)
1. Use the AWS provisioning module in `./oidc-bootstrap/` — it creates the OIDC provider + role.
2. Fill in the TRUST_POLICY_WORKSPACE variable with your HCP org/workspace name.
3. Apply it (with your local AWS creds, one-time).
4. Take the output role ARN, put it on your HCP workspace as `TFC_AWS_RUN_ROLE_ARN`.
5. Remove any static `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` from the workspace.
6. Trigger a plan. It should succeed without static keys.

## Self-check

1. `var.region` is set in a variable set AND in `terraform.tfvars`. Who wins?
2. `AWS_ACCESS_KEY_ID` in a workspace env var conflicts with `TFC_AWS_RUN_ROLE_ARN`. Which one "wins"?
3. Two OIDC-enabled workspaces in the same org both need to assume *different* AWS roles. How?
4. Why is `TFC_AWS_PROVIDER_AUTH` required in addition to the role ARN?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Variable sets — when to use
- Env vars vs Terraform vars
- Dynamic credentials via OIDC — the sequence

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
