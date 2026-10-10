# Week 4 · Day 3 — Troubleshooting Playbook

**Exam domain:** 5 (troubleshoot provider errors), plus cross-cutting skills the lab section demands.

## Learning goals

1. Canonical debug sequence when anything fails.
2. Parse `TF_LOG=TRACE` output productively — what to grep for.
3. Recover from common state problems:
   - Stuck lock
   - Corrupted state
   - Accidental `state rm`
   - Drift between code and cloud
4. Recognize and fix the top 15 errors you'll encounter.

## The four-step debug sequence

1. **Read the error**. Seriously — Terraform errors are explicit. 70% of the time the fix is in the message.
2. **`terraform validate`** — is it even syntactically valid?
3. **`TF_LOG=DEBUG terraform plan 2>&1 | tee tf.log`** — enough signal without drowning.
4. **`TF_LOG=TRACE`** — only if `DEBUG` didn't show the HTTP call. Look for `HTTP Request:` blocks.

## Stuck lock recovery

```bash
# DynamoDB-backed lock
aws dynamodb delete-item \
  --table-name tfpro-locks \
  --key '{"LockID":{"S":"tfpro-state-xxx/envs/dev/terraform.tfstate-md5"}}'

# OR the TF way (safer — confirms with you)
terraform force-unlock <LOCK_ID_from_error>
```

Never `force-unlock` if another `apply` is genuinely running. Corrupt state can take hours to rebuild.

## Corrupted state

1. Stop. Don't run more commands against that state.
2. `aws s3api list-object-versions --bucket tfpro-state-xxx --prefix envs/dev/terraform.tfstate`
3. Restore the previous version:
   ```bash
   aws s3api get-object --bucket tfpro-state-xxx --key envs/dev/terraform.tfstate --version-id <VER> state.json
   terraform state push state.json
   ```
4. `terraform plan` — sanity check.

(This is why bucket versioning is non-negotiable.)

## Top 15 errors to recognize on sight

| Error fragment | Root cause | Fix |
|---|---|---|
| `Error acquiring the state lock` | Another run or stuck lock | `force-unlock` |
| `Invalid function argument` | Wrong type at function call | Check types with `terraform console` |
| `Reference to undeclared resource` | Typo or missing `depends_on` | Grep for the name |
| `Inconsistent dependency lock file` | Upstream provider bump | `terraform init -upgrade` or fix lock |
| `Provider produced inconsistent final plan` | Provider bug or dynamic value used wrong | Pin provider, use `lifecycle.ignore_changes` |
| `Cycle:` in the graph | Mutual references | Break with data source or `depends_on` |
| `for_each ... not yet known` | Keys reference unknown values | Use static keys, derive resources by lookup |
| `backend configuration changed` | Backend block modified | `terraform init -reconfigure` or `-migrate-state` |
| `Resource already exists` on import-adjacent flows | You `apply`ed without importing first | `terraform import` then retry |
| `Provider not available for installation` | Wrong source / registry | Fix `required_providers.source` |
| `Plan: 0 to add, X to destroy` on upgrade | Breaking change in provider | Pin back, read upgrade guide |
| `The argument "X" is required` | Missing required arg | Schema changed — check provider docs |
| `does not have an attribute named` | Schema mismatch | Upgrade or rename attribute |
| `Cannot set both X and Y` | Mutually exclusive args | Pick one — check docs |
| `AccessDenied` from AWS | IAM gap | Decode with `aws sts decode-authorization-message` |

## `terraform console` is your friend

```bash
terraform console
> var.app_config
> local.enabled
> cidrsubnet("10.0.0.0/16", 8, 3)
> [for k, v in local.map : k if v.enabled]
```

Use console to test expressions before pasting them into HCL.

## Exercises

1. Break things on purpose in `broken/` — each file has a different intentional error. Fix them without peeking at the `.solved` copies.
2. Get one `apply` to fail mid-way (e.g. interrupt with Ctrl+C). Practice recovery.
3. With `TF_LOG=TRACE`, find the exact HTTP call made to create an IAM user.
4. Simulate a stuck lock with two concurrent applies, resolve with `force-unlock`.

## Self-check

1. Where is the state lock *actually* stored for the S3 backend?
2. `Error: Provider produced inconsistent final plan` — two common causes?
3. Your `plan` shows a change, `apply` succeeds, next `plan` shows the same change again. What's happening and how to diagnose?
4. Which env var silences the "no changes" exit-code thing for scripts?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The four-step debug sequence
- Stuck lock recovery
- Corrupted state
- Top 15 errors to recognize on sight

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
