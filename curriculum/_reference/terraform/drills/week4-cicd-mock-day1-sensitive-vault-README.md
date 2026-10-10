# Week 4 · Day 1 — Sensitive Data, Vault Integration, Ephemeral Values

**Exam domain:** 2 — "Analyze best practices for sensitive data management and Vault integration".

## Learning goals

1. **`sensitive = true`** on variables and outputs — what it hides and what it doesn't (hint: still in state!).
2. **`nonsensitive()`** to explicitly un-mark a value.
3. **`ephemeral` values** (Terraform 1.10+) — values that never touch state or plan output.
4. **Vault provider** — `vault_kv_secret_v2`, `vault_generic_secret`, `vault_aws_access_credentials`.
5. **Dynamic secrets** from Vault — database creds, cloud creds — instead of baked-in long-lived values.
6. **`data "external"`** as a last-resort fallback for secrets from unsupported sources.
7. Secret **rotation** patterns with `ignore_changes`, `replace_triggered_by`, and version awareness.

## What `sensitive` actually does

- Hides value from `terraform plan`/`apply` console output.
- Hides value from error messages (in most cases — exam corner case: won't hide if the value itself causes a type error).
- **Does NOT encrypt state**. State is still plaintext. Use an encrypted backend (S3 SSE, HCP) + tight IAM.
- Propagates: if `sensitive` variable feeds an output, the output is auto-sensitive unless `nonsensitive()`.

## Ephemeral values (1.10+)

```hcl
variable "db_password" {
  type      = string
  ephemeral = true
  sensitive = true
}

ephemeral "random_password" "db" {
  length = 32
}

resource "aws_db_instance" "this" {
  password = ephemeral.random_password.db.result   # never written to state
}
```

- `ephemeral = true` on a variable makes it only valid in *this* run; not persisted.
- Use `ephemeral "resource_type" "name"` blocks for runtime-only providers (e.g. fresh passwords).
- Only certain attributes accept ephemeral values — provider docs mark them.

## Vault integration — typical flow

```hcl
provider "vault" {
  address = "https://vault.example.com:8200"
  # Auth: env VAULT_TOKEN, OR auth_login blocks for AWS/AppRole/OIDC
}

data "vault_kv_secret_v2" "db" {
  mount = "secret"
  name  = "prod/postgres"
}

resource "aws_db_instance" "prod" {
  username = data.vault_kv_secret_v2.db.data["username"]
  password = data.vault_kv_secret_v2.db.data["password"]
}
```

For **dynamic** AWS creds:
```hcl
data "vault_aws_access_credentials" "creds" {
  backend = "aws"
  role    = "terraform"
  type    = "sts"
}

provider "aws" {
  access_key = data.vault_aws_access_credentials.creds.access_key
  secret_key = data.vault_aws_access_credentials.creds.secret_key
  token      = data.vault_aws_access_credentials.creds.security_token
  region     = "us-east-1"
}
```

Each apply fetches a fresh short-lived credential.

## Exercises

1. **Sensitive drill.** Declare a `db_password` variable with `sensitive = true`. Reference in `aws_db_instance.password`. Run `terraform plan` — confirm the value doesn't show. Check state with `terraform show -json | jq '.values.root_module.resources[].values.password'` — confirm it *is* there. Discuss implications.
2. **`nonsensitive` escape hatch.** Build an output `output "password_length"` that returns `length(nonsensitive(var.db_password))` — prove you can derive non-secret info.
3. **Ephemeral demo.** Use `ephemeral "random_password"` + `aws_db_instance`. Inspect state — confirm the password is **not** persisted. Try again without ephemeral — note the difference.
4. **(Optional) Vault dev-mode.** `vault server -dev` locally, put a KV pair, read it via the `vault_kv_secret_v2` data source.

## Self-check

1. Why is `sensitive = true` not sufficient for compliance?
2. You use `sensitive = true` on var A, then do `output "x" { value = "prefix-${var.A}" }`. Is the output sensitive?
3. What's the single biggest difference between `sensitive` and `ephemeral`?
4. Can an `ephemeral` value be referenced by `for_each`?
5. If Vault is down, what happens to your Terraform apply that pulls secrets from it?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What sensitive actually does
- Ephemeral values (1.10+)
- Vault integration — typical flow

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
