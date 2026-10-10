# Domain 5 — Providers (the Teacher's Voice)

---

## 1. Version constraints — the pessimistic operator

| Constraint | Equivalent |
|---|---|
| `~> 5.2` | `>= 5.2, < 6.0` |
| `~> 5.2.3` | `>= 5.2.3, < 5.3.0` |
| `>= 5.0` | any 5.x or above (dangerous) |
| `5.2.3` | exactly 5.2.3 |

**Rule of thumb:** Modules pin major (`~> 5.0`), root configs pin minor when you don't want silent feature drift.

**Gotcha:** Terraform picks the highest version that satisfies *all* constraints in your module tree. One module requiring `~> 4.0` will block a root that wants `~> 5.0` — init fails with "no matching version."

**Self-test:** Root says `~> 5.0`, module A says `>= 5.3`, module B says `~> 5.2.0`. What version resolves?

**Lab:** `week2/day5-providers-deep-dive`

---

## 2. The lock file — `.terraform.lock.hcl`

- **Commit it.** It pins exact version + per-platform checksums.
- `terraform init` honors it. `terraform init -upgrade` ignores current pins and resolves fresh (then rewrites the lock).
- Multi-platform teams: `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`.

**Analogy:** `package-lock.json` for Terraform.

**Gotcha:** A dev on Mac commits the lock. CI on Linux fails with "checksum missing for linux_amd64." The Mac dev must regenerate with `-platform=linux_amd64` and commit.

**Self-test:** When is `init -upgrade` the right call, and when is it actively dangerous?

---

## 3. AWS auth — four ways

1. **Static creds** — `access_key`/`secret_key` in provider (don't commit).
2. **Env vars** — `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`.
3. **Profile** — `provider "aws" { profile = "dev" }` (reads `~/.aws/credentials`).
4. **`assume_role`** — STS role chain, optionally via OIDC from HCP.

```hcl
provider "aws" {
  region = "us-east-1"
  assume_role {
    role_arn     = "arn:aws:iam::111:role/terraform"
    session_name = "tf-run"
  }
}
```

**Analogy:** `assume_role` is a hotel keycard: limited, dated, revocable. Static keys are a house key.

**Gotcha:** In HCP with OIDC (`TFC_AWS_PROVIDER_AUTH=true`), the provider block doesn't need `access_key` or `profile` — HCP injects temporary creds as env vars at run time.

**Self-test:** What does HCP inject into the runtime environment when OIDC is on?

---

## 4. Provider aliases — multi-region / multi-account

```hcl
provider "aws" { region = "us-east-1" }

provider "aws" {
  alias  = "euw1"
  region = "eu-west-1"
}

resource "aws_s3_bucket" "eu" {
  provider = aws.euw1
  bucket   = "data-eu"
}
```

**Gotcha:** You can't reference an alias that the root never declared. If a module needs `aws.replica`, it must use `configuration_aliases` AND the caller must pass `providers = { aws.replica = aws.euw1 }`.

**Self-test:** One AWS account, two regions — minimum provider blocks needed?

---

## 5. `TF_LOG` — debugging providers

| Level | When |
|---|---|
| `TRACE` | full request/response, noisy |
| `DEBUG` | resource ops, retries |
| `INFO` | high-level |
| `WARN` | only warnings |
| `ERROR` | only errors |

```bash
TF_LOG=TRACE TF_LOG_PATH=./tf.log terraform apply
```

**Analogy:** Chrome DevTools Network tab for Terraform.

**Gotcha:** Also `TF_LOG_PROVIDER=DEBUG` to quiet Terraform core and only see provider-level logs. Tokens *can* leak into TRACE output — scrub before pasting in tickets.

**Self-test:** Provider errors with "unexpected EOF." What env var and level do you set first?

**Lab:** `week4/day3-troubleshooting`

---

## 6. `terraform providers schema -json`

Dumps the full JSON schema for every provider your config uses — every resource, every attribute, required vs optional, sensitive flags. Authoritative over docs when docs lag.

```bash
terraform providers schema -json | jq '.provider_schemas."registry.terraform.io/hashicorp/aws".resource_schemas.aws_instance.block.attributes | keys'
```

**Self-test:** Doc says an attr exists but `terraform plan` complains "unknown argument." Fastest way to confirm?

---

## Flashcards

Domain 5 in `/FLASHCARDS.md` — 8 cards.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Version constraints — the pessimistic operator
- The lock file — .terraform.lock.hcl
- AWS auth — four ways
- Provider aliases — multi-region / multi-account

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
