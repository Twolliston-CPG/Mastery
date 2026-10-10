# Vault hands-on lab

**Time:** ~60 minutes end-to-end.

## What you'll do

1. Run Vault in dev mode locally — no real secret store, but exercises the full API.
2. Write a secret to KV v2.
3. Read it from Terraform via the `vault_kv_secret_v2` data source.
4. Observe how the secret propagates to resources (with `sensitive = true`).
5. Confirm it's still plaintext in state — the lesson HashiCorp wants you to internalize.

## Prereqs

- `vault` CLI installed (`brew install vault` on macOS).
- Nothing else — no AWS, no cloud.

## Step 1 — start Vault dev server

In one terminal (leave it running):

```bash
vault server -dev -dev-root-token-id=root
```

Output includes an unseal key and root token. **Don't use dev mode in production.**

## Step 2 — configure the CLI

In a second terminal:

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'
vault status     # should show "Initialized true, Sealed false"
```

## Step 3 — write a secret

```bash
vault kv put secret/tfpro/db username=admin password=hunter2
vault kv get secret/tfpro/db
```

## Step 4 — read it from Terraform

```bash
cd vault-lab
terraform init
terraform plan
terraform apply -auto-approve
```

Inspect:

```bash
terraform output -json
terraform output db_username   # visible — non-sensitive
terraform output db_password   # shows "(sensitive value)"
```

## Step 5 — prove state is still plaintext

```bash
terraform show -json | jq '.values.outputs.db_password.value'
# "hunter2"   ← it's RIGHT THERE
```

This is the single most important Vault/Terraform takeaway: **`sensitive = true` hides from humans in CLI output. It does NOT encrypt state.** You still need an encrypted backend (S3 SSE, HCP) + strict IAM.

## Step 6 — rotate

```bash
vault kv put secret/tfpro/db username=admin password=correcthorsebatterystaple
terraform apply -auto-approve
terraform output db_password   # still hidden, but rotated in state
```

## Cleanup

```bash
# Kill the vault dev server (Ctrl+C in terminal 1) — all data is in-memory.
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
```

## Self-check

1. Why did `terraform apply` still need the value from Vault on every run?
2. What prevents `terraform show` from redacting the state?
3. How would you prevent Terraform from storing the value at all? (Hint: Terraform 1.10+ `ephemeral`.)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What you'll do
- Prereqs

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
