# Ephemeral values lab (Terraform 1.10+)

## What you'll do

1. Generate a password with `ephemeral "random_password"` — never persists.
2. Compare to a regular `resource "random_password"` — which IS persisted.
3. Inspect state to see the difference directly.

## Prereqs

- Terraform `>= 1.10`.
- No cloud credentials — everything is local / random.

## Run

```bash
cd ephemeral-lab
terraform init
terraform apply -auto-approve

terraform show -json | jq '.values.root_module'
# See: `persisted_password` is in state with its value
# See: `ephemeral_password` has no value — it lives only for the run
```

## Key idea

| | `random_password` (resource) | `ephemeral "random_password"` |
|---|---|---|
| In state? | Yes (plaintext unless sensitive+redacted) | **No** |
| Recomputed each run? | No — stable across applies | **Yes — fresh every run** |
| Use case | Stable passwords for DB instances | Short-lived tokens, session creds, bootstrap-only values |

## Self-check

1. What does an ephemeral value's `terraform show -json` look like?
2. Can you reference `ephemeral.random_password.x.result` in a resource that *stores* it?
3. When would you want a password to rotate every apply? (Hint: you usually don't — be cautious.)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What you'll do
- Prereqs
- Key idea

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
