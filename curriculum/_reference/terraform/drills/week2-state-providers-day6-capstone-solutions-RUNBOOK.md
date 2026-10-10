# Capstone Runbook

## Purpose

Bring the inherited AWS stack under Terraform management, refactor it into modules, and migrate state to S3+DynamoDB.

## Prerequisites

- Terraform `>= 1.7`.
- AWS credentials authorized for `ec2:*`, `iam:*`, `s3:*`, `dynamodb:*` in us-east-1.
- Day 1's state-bootstrap already applied (S3 bucket + DynamoDB lock table).

## 0. Create the inherited infra

```bash
bash scripts/create-inherited.sh
# Capture the printed import blocks.
```

## 1. Import into local state

Paste the printed `import {}` blocks into `envs/dev/main.tf` (below the modules).

```bash
cd envs/dev
terraform init
terraform plan -generate-config-out=generated.tf    # optional review step
terraform apply                                     # plan should read: N to import, 0 to add/destroy
```

After success:
- `terraform state list` shows all 7 resources.
- `terraform plan` shows **No changes.**

## 2. Remove the `import {}` blocks from main.tf

One successful apply per resource per runner is enough; `import` blocks are single-use.

## 3. Migrate state to S3+DynamoDB

Uncomment the `backend "s3" {}` block in `versions.tf`, then:

```bash
terraform init -migrate-state \
  -backend-config="bucket=${TFSTATE_BUCKET}" \
  -backend-config="key=week2-capstone/envs/dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=tfpro-locks" \
  -backend-config="encrypt=true"
```

Terraform will prompt: confirm with `yes`.

Verify:
```bash
terraform state list               # same resources
aws s3 ls s3://$TFSTATE_BUCKET/week2-capstone/envs/dev/
```

## 4. Prove locking works

```bash
# Terminal A
terraform plan                     # leave hanging mid-refresh

# Terminal B
terraform plan                     # must fail with "Error acquiring state lock"
```

## 5. Run tests

```bash
cd ../../modules/compute
terraform init
terraform test                     # all pass with mock_provider
```

## Destroy

```bash
cd envs/dev
terraform destroy -auto-approve
```

## Known quirks

- **Import drift on `tags`:** AWS may have auto-applied tags (e.g. via an org policy) that don't appear in HCL. Options:
  1. Match them in HCL.
  2. Add `ignore_changes = [tags["AutoTag"]]` for specific keys.
  3. Use `default_tags {}` + `ignore_changes = [tags]` at the resource level.
- **`aws_eip_association.id` format:** it's `eipassoc-xxxxx`, not the allocation id.
- **`aws_security_group_rule`:** the composite-ID format is ugly — prefer inline `ingress` on the SG.
- **After migrating to S3,** the old local `terraform.tfstate` file is **still on disk**. Delete it to avoid confusion.

## Incident playbook

| Symptom | First action |
|---|---|
| `Error acquiring state lock` | Check Slack, then `terraform force-unlock <id>` if truly stuck |
| State is missing a resource | `terraform state pull` and compare serial to S3 versioned history |
| A plan wants to destroy something real | **Abort.** Inspect HCL, ensure resource block still exists. Re-import if state was lost. |
| Apply partially failed | Re-run `apply` — Terraform is designed to be idempotent through partial failures |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Purpose
- Create the inherited infra
- Import into local state
- Remove the import {} blocks from main.tf

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
