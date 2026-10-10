# Scenario 1 — Migration Walkthrough

## 1. Baseline with local state

```bash
cd scenario1-state-migration
terraform init
terraform apply -auto-approve
terraform state list
# aws_subnet.public
# aws_vpc.this
```

## 2. Add the backend block

Edit `main.tf`, add `backend "s3" {}` (empty — values supplied below).

## 3. Migrate

```bash
terraform init -migrate-state \
  -backend-config="bucket=$TFSTATE_BUCKET" \
  -backend-config="key=week4-scenario1/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=tfpro-locks" \
  -backend-config="encrypt=true"
```

Terraform prompts: "Do you want to copy existing state to the new backend?" → `yes`.

## 4. Verify

```bash
terraform state list          # same 2 resources
terraform plan                # No changes.
aws s3 ls s3://$TFSTATE_BUCKET/week4-scenario1/
```

## 5. Prove locking

Terminal A:
```bash
terraform plan                # let it start refreshing, hit Ctrl+C mid-refresh to leave lock
```

Terminal B:
```bash
terraform plan
# Error: Error acquiring the state lock
# Lock Info:
#   ID:        <UUID>
```

Resolve with `terraform force-unlock <UUID>` if nobody is actually running.

## Why each step matters

- **Partial config** — the config cannot reference variables in the backend block. Partial + `-backend-config` is the canonical workaround.
- **`-migrate-state`** — tells Terraform "copy current state to the new backend" instead of asking "delete and start fresh."
- **Locking** — without DynamoDB, two concurrent applies can corrupt state. The lock lives in the table at key `<bucket>/<key>-md5`.

## Common wrong answers

- Using `terraform state pull` + `terraform state push` manually — works, but skips locking setup and is brittle.
- Editing `terraform.tfstate` directly — never.
- Deleting local state then re-importing — destroys provider-computed attrs and IDs; takes forever.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Baseline with local state
- Add the backend block
- Migrate
- Verify

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
