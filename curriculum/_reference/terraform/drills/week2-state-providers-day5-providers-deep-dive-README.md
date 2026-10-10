# Week 2 · Day 5 — Provider Deep Dive

**Exam domain:** 5 (Configure and Use Terraform Providers).

## Learning goals

1. **Plugin architecture** — providers are out-of-process binaries; Terraform speaks to them over gRPC (protocol v5 / v6).
2. **`required_providers`** block — `source`, `version`, `configuration_aliases`.
3. **Version constraint grammar**: `= 1.2.3`, `!= 1.2.3`, `> 1.2`, `>= 1.2, < 2.0`, `~> 1.2` (pessimistic, right-most wildcard), `~> 1.2.3` (only patch).
4. **`terraform providers`** subcommands: `providers`, `providers lock`, `providers mirror`, `providers schema`.
5. **`.terraform.lock.hcl`** — why it's committed, how `terraform init -upgrade` interacts with it, and cross-platform checksums.
6. **Provider authentication** — env vars, shared credentials file, profile, `assume_role`, OIDC.
7. **Troubleshooting** — `TF_LOG=TRACE`, `TF_LOG_PATH`, request/response bodies, common failure modes.
8. **Aliases & multi-provider configurations** — when you'd use two `aws` providers with different roles.

## Version constraints — examples

| Constraint | Meaning |
|---|---|
| `= 5.42.0` | Exactly 5.42.0 |
| `~> 5.0` | `>= 5.0, < 6.0` — major locked |
| `~> 5.42` | `>= 5.42, < 6.0` — allows 5.43, 5.99 |
| `~> 5.42.0` | `>= 5.42.0, < 5.43.0` — only patch bumps |
| `>= 5.0, < 5.50` | Explicit range |
| `!= 5.42.0` | Avoid a known-bad version |

## The lock file (`.terraform.lock.hcl`)
- Created by `terraform init`, **commit it**.
- Contains the exact version selected plus **per-platform checksums**.
- `terraform init -upgrade` re-resolves versions against your constraints.
- `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 ...` pre-populates checksums for CI runners on different OSes.
- Without this, an init in CI can fail with "inconsistent dependency lock file".

## Authentication — AWS examples

```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "prod"                      # shared credentials file
}

# OR via role assumption
provider "aws" {
  region = "us-east-1"
  assume_role {
    role_arn     = "arn:aws:iam::111111111111:role/terraform"
    session_name = "tf-pro-study"
    external_id  = "xyz"
  }
}

# Modern OIDC (for CI/CD without long-lived keys) — no HCL, set env:
# AWS_ROLE_ARN, AWS_WEB_IDENTITY_TOKEN_FILE, AWS_REGION
```

## Multi-provider: same provider, different roles

```hcl
provider "aws" {
  alias  = "audit"
  assume_role { role_arn = "arn:...:role/audit-read" }
}

data "aws_caller_identity" "audit" {
  provider = aws.audit
}
```

## Troubleshooting

```bash
export TF_LOG=TRACE                # trace level
export TF_LOG_PATH=./tf.log        # file instead of stderr
terraform plan
```

- Look for `HTTP request` blocks with status codes.
- `TF_LOG_PROVIDER=DEBUG` limits to provider chatter only.
- Inspect `.terraform/providers/` to see what binaries are installed.

## `terraform providers` examples

```bash
terraform providers                        # tree of providers per module
terraform providers schema -json | jq      # full provider schema — useful for "what attrs does this resource support"
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64
terraform providers mirror ./mirror        # download to a local mirror (air-gapped installs)
```

## Exercises

1. `cd constraints/`, try each version constraint in the table; run `terraform init -upgrade` and note what got installed.
2. `terraform providers schema -json | jq '.provider_schemas | keys'` — list all known provider schemas.
3. Set `TF_LOG=TRACE` and `terraform plan` — find the HTTP request to STS `GetCallerIdentity`.
4. Simulate CI: `rm -rf .terraform .terraform.lock.hcl && terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`, commit the lock, then `terraform init` and confirm no network fetch is needed if the cache is warm.
5. Aliased auth test: declare two `aws` providers with different regions, provision a tiny resource in each.

## Self-check

1. What's the difference between `version = "~> 5.0"` and `version = "~> 5.0.0"`?
2. You deleted `.terraform.lock.hcl` on purpose. Next init picks a newer version. Is this always safe?
3. How do you get Terraform to ignore the lock file just this once?
4. Your plan fails with "error calling STS: access denied". Where do you look first?
5. In `configuration_aliases`, do the aliases need to match the caller's alias names exactly?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Version constraints — examples
- The lock file (.terraform.lock.hcl)
- Authentication — AWS examples
- Multi-provider: same provider, different roles

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
