# Capstone Runbook (template)

Fill this in as the **final** deliverable — it's how you prove the scenario is reproducible.

## Purpose

Bring the inherited `tf-pro capstone` stack under Terraform management and migrate state to S3+DynamoDB.

## Prerequisites

- AWS credentials with `ec2:*`, `s3:*`, `dynamodb:*`, `iam:*` (scope down in prod).
- Terraform `>= 1.7`.
- S3 state bucket + DynamoDB lock table already provisioned (see `../day1-state-backends/bootstrap/`).

## Bring-up (from scratch)

```bash
# 1. Create the inherited infra (or skip if using real inherited resources).
bash scripts/create-inherited.sh

# 2. Initialize with local state.
cd /path/to/capstone
terraform init

# 3. Apply the import blocks (plan should show N to import, 0 to add/destroy/change).
terraform plan -generate-config-out=generated.tf
# Review generated.tf, merge into your desired structure.
terraform apply

# 4. Refactor into modules.
# (See module folders and `moved` blocks in main.tf.)
terraform plan   # expect: N "has moved to" entries, 0 destroys
terraform apply

# 5. Migrate state to S3.
terraform init -migrate-state \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=week2-capstone/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=tfpro-locks" \
  -backend-config="encrypt=true"
```

## Verify

```bash
terraform state list           # all expected resources
terraform plan                 # No changes
terraform test                 # mocked tests green
```

## Destroy

```bash
terraform destroy -auto-approve
aws s3 rm s3://$STATE_BUCKET/week2-capstone/ --recursive
```

## Known quirks

- Importing `aws_eip_association` requires the **association id** (`eipassoc-…`), not the allocation id.
- `aws_security_group_rule` composite IDs are fragile — prefer the inline `ingress` blocks on the SG.
- On the first plan after import, `tags` may drift — match them in HCL or use `ignore_changes = [tags["Foo"]]`.

## Incident playbook (if things go sideways)

1. Don't destroy anything. Take a backup: `terraform state pull > emergency-state-$(date +%s).json`.
2. Check Slack/#infra for other concurrent changes.
3. If lock is stuck: `terraform force-unlock <id>` only after confirming no one else is applying.
4. If state is corrupt: `aws s3api list-object-versions --bucket $STATE_BUCKET --prefix week2-capstone/` and restore the last-good version.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Purpose
- Bring-up (from scratch)
- Verify
- Destroy

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
