# Capstone Runbook — End-to-End HCP Terraform

## Prerequisites (do these first, once)

1. **HCP account + org.** Sign up at https://app.terraform.io/signup. Create an organization (any name; it becomes `var.organization`).
2. **User API token.** Profile → Tokens → Create. Export:
   ```bash
   export TFE_TOKEN="<paste>"
   ```
3. **GitHub VCS link.** Settings → VCS Providers → Connect GitHub App. Note the resulting `oauth-token-xxxxxxxxxxxx` — it's `var.oauth_token_id`.
4. **OIDC IAM role.** Apply `week3-hcp-collab/day3-varsets-oidc/oidc-bootstrap/` in AWS to create the IAM OIDC provider + role. Grab the role ARN — it's `var.aws_run_role_arn`.
5. **GitHub repo.** Create a repo with two subdirs `network-dev/` and `app-dev/`. Copy the contents of `solutions/network-dev/` and `solutions/app-dev/` into them. Push to `main`.

## Step 1 — Apply the HCP bootstrap

```bash
cd hcp-bootstrap

cat > terraform.tfvars <<EOF
organization      = "your-org-name"
github_repo       = "your-gh-user/your-repo-name"
oauth_token_id    = "ot-xxxxxxxxxxxxx"
aws_run_role_arn  = "arn:aws:iam::123456789012:role/tfpro-hcp-oidc"
EOF

terraform init
terraform apply
```

This creates:
- Project `tfpro-capstone`
- Workspaces `network-dev`, `app-dev` (VCS-driven, remote execution)
- Variable set `aws-defaults` with `AWS_DEFAULT_REGION` and OIDC env vars
- Policy set `guardrails` with `limit-instance-size.sentinel` at `soft-mandatory`
- State sharing from `network-dev` → `app-dev`
- Run trigger from `network-dev` → `app-dev`

## Step 2 — Add the consumer's org variable

The `app-dev` workspace needs `var.organization`. Easiest way: workspace-level variable in HCP UI, OR add to the variable set (make it a Terraform-category variable).

## Step 3 — Trigger the initial runs

1. Make a trivial commit to `main` in the GitHub repo.
2. In HCP UI, open `network-dev` → the speculative plan runs → confirm apply.
3. Due to the run trigger, `app-dev` automatically starts a run.
4. `app-dev` run → plan succeeds → confirm apply. (`t3.micro` passes the Sentinel policy.)

## Step 4 — Prove the Sentinel policy blocks violations

1. Open a PR changing `app-dev/main.tf` `instance_type = "t3.micro"` to `"m5.large"`.
2. Watch HCP post a speculative plan comment; the Sentinel policy check fails.
3. Change back to `t3.micro`, push — plan passes. Merge.

## Step 5 — Clean up

**Order matters — app-dev first, then network-dev.**

```bash
# From the HCP UI: Queue Destroy Plan on app-dev. Apply.
# Then: Queue Destroy Plan on network-dev. Apply.
# Finally: tear down the bootstrap.
cd hcp-bootstrap
terraform destroy
```

## Gotchas

- **`tfe_workspace_settings.remote_state_consumer_ids` only works if `global_remote_state = false`.** If you leave it global, every workspace can read; you don't need the consumer list.
- **`tfe_policy_set_parameter` attachment varies by provider version.** If it errors, remove that resource — the `tfe_policy_set` already points at the `policies_path` and will auto-include files.
- **Dynamic credentials fail** if the IAM trust policy doesn't include your specific org/workspace in the `sub` condition. Rerun `oidc-bootstrap` with the right `hcp_organization`.
- **VCS branch mismatch:** the workspace watches `main` by default here; change if your repo uses `master`.
- **Run trigger fires before state sharing is ready:** if you see "workspace X cannot read state of Y," confirm the workspace_settings resource applied cleanly.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Prerequisites (do these first, once)
- Gotchas

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
