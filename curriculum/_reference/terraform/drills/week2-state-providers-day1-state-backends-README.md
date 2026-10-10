# Week 2 · Day 1 — State, Backends, and Migration

**Exam domain:** 3 (collaborative workflows — remote state).

## Learning goals

1. Know what's in **`terraform.tfstate`** and why it's sensitive (plaintext secrets).
2. Difference between **local** and **remote** backends, and the three things remote gives you: locking, centralization, isolation.
3. Configure the **S3 backend** with a **DynamoDB lock table** — and know the exact IAM permissions needed.
4. Perform a **backend migration** with `terraform init -migrate-state`.
5. Know the other remote backends you might see: `azurerm`, `gcs`, `remote` (Terraform Cloud/Enterprise — now `cloud {}`), `http`, `kubernetes`, `pg`.
6. Understand **state locking** and how to recover from a stuck lock (`force-unlock`).
7. Know why `backend` blocks **can't use variables** and how to work around it with **partial configuration + `-backend-config`**.

## Hard-earned truths about state

- **State contains secrets in plaintext** (RDS passwords, access keys created by TF, SSH keys). Treat the bucket like a credential store: encryption, versioning, restricted IAM, no public access.
- **Two people applying at once = corrupt state**. Locking via DynamoDB (S3) or the backend's native mechanism is not optional in teams.
- **The `backend` block is evaluated *before* variables**. So you *cannot* do `bucket = var.state_bucket`. Solution: partial config.
- **Workspaces in CLI** (the `terraform.workspace` kind) create one state file per workspace *under a shared key* (`env:/dev/key`). Different from HCP workspaces which are fully separate.

## Partial backend config pattern

```hcl
# backend.tf
terraform {
  backend "s3" {
    # keys left empty — supplied at init time
  }
}
```

```bash
terraform init \
  -backend-config="bucket=tfpro-state-$ACCOUNT" \
  -backend-config="key=envs/dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=tfpro-locks" \
  -backend-config="encrypt=true"
```

This is **the** exam-favorite pattern because it lets one config target multiple state stores.

## Exercises

### Part A — Bootstrap the state backend (one-time, hand-rolled)
The classic chicken-and-egg: you need a bucket for state, but you want to manage it with Terraform. Solution: a tiny bootstrap config that uses **local** state to create the S3 bucket + DynamoDB table, then you hand-migrate.

1. `cd bootstrap/`
2. `terraform init && terraform apply` — creates bucket + lock table.
3. Note the output `bucket_name` — you'll use it below.

### Part B — Local state
1. `cd ../local/`
2. `terraform init && terraform apply` — provisions a tiny VPC, state lives in `./terraform.tfstate`.
3. `cat terraform.tfstate | jq '.resources[].type'` — see what's in there.
4. Grep for any secret values — note how little protection there is.

### Part C — Migrate to remote
1. `cd ../remote/` — this is a *copy* of `local/` with a `backend "s3"` block.
2. Copy the state file over: `cp ../local/terraform.tfstate .`
3. `terraform init -migrate-state -backend-config="bucket=<from step A>" ...`
4. Confirm the migration prompt. State is now in S3.
5. `terraform state list` — same resources, different location.
6. `aws s3 cp s3://<bucket>/envs/dev/terraform.tfstate -` — verify.

### Part D — Prove locking works
1. In terminal A: `terraform plan` and pause when it prompts (or run `terraform apply` and Ctrl+C during refresh).
2. In terminal B: `terraform plan` — should fail with a lock error.
3. Resolve: wait for A, or `terraform force-unlock <LOCK_ID>` if genuinely stuck.

### Part E — Workspace isolation
1. `terraform workspace new staging`
2. `terraform apply` — creates a *second* state file at `env:/staging/envs/dev/terraform.tfstate`.
3. `terraform workspace list`, `terraform workspace select default`.
4. Inspect S3 — note the key structure.

## Cleanup

```bash
# remote/
terraform workspace select default
terraform destroy -auto-approve
terraform workspace select staging && terraform destroy -auto-approve && terraform workspace select default && terraform workspace delete staging

# bootstrap/ (empty the bucket first!)
aws s3 rm s3://<bucket> --recursive
terraform destroy -auto-approve
```

## Self-check

1. Why can't the `backend` block reference `var.region`?
2. You ran `terraform apply` and someone power-cycled the machine mid-apply. The lock is stuck. What's the safe sequence?
3. Two engineers run `terraform apply` against the same S3 key with no DynamoDB table. What happens?
4. You want to move from S3 to HCP Terraform. What's the command?
5. What's stored in state that is *not* in config (three examples)?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Hard-earned truths about state
- Partial backend config pattern

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
