# Week 2 · Day 6 — Capstone: Inherit, Import, Refactor, Migrate

**Goal:** You've just been handed an undocumented AWS environment. Your mission is to bring it under Terraform management, refactor it sanely, and move state to a production-grade remote backend — all without downtime.

## The scenario

Pretend a teammate left. The AWS account has:

- 1 VPC (`10.99.0.0/16`), hand-created
- 2 subnets in different AZs, `10.99.1.0/24` and `10.99.2.0/24`
- 1 security group allowing port 80 from 0.0.0.0/0
- 1 EC2 instance behind that SG
- 1 Elastic IP attached to the instance

Your goals:

1. **Bring everything into Terraform** without destroying/recreating.
2. **Modularize** — VPC+subnets into `modules/network`, SG+EC2+EIP into `modules/compute`.
3. **Move state from local to S3+DynamoDB** (reuse the bucket you created on Day 1).
4. **Rename** `aws_instance.inherited` → `module.compute.aws_instance.app` in a way that survives the import history.
5. **Add tests** — a `.tftest.hcl` with mocks that validates the structure produced by your modules.
6. **Document** — a short `RUNBOOK.md` explaining how someone else should bring up this stack from scratch.

## Setup

```bash
# 1. Create the baseline infra by hand (via console or CLI) — this is the "inherited" state.
#    Record every id you create.
# 2. cd day6-capstone/
# 3. Start with a single main.tf that uses `import {}` blocks for every resource.
# 4. Run: terraform plan -generate-config-out=generated.tf
# 5. Review generated.tf — clean it up, merge into your desired structure.
# 6. Iterate: plan should report imports, then clean.
```

## Milestones (check off as you go)

- [ ] All 6 resources imported, `terraform plan` shows **no changes**.
- [ ] Config split into `envs/dev/main.tf`, `modules/network/`, `modules/compute/`.
- [ ] `moved` blocks cover every relocation — plan still shows no changes.
- [ ] Backend migrated from local to S3 with `terraform init -migrate-state`.
- [ ] State locking confirmed (try two terminals).
- [ ] `terraform test` green with `mock_provider`.
- [ ] `terraform destroy` cleanly removes everything.

## Rubric (self-score out of 25)

| Area | Pts |
|---|---|
| All resources imported correctly | 6 |
| Modularization is clean (no leaky abstractions) | 5 |
| `moved` blocks used correctly | 4 |
| Backend migration successful + locking verified | 4 |
| Tests run and assert meaningful things | 3 |
| RUNBOOK is reproducible by a stranger | 3 |

## Gotchas the exam *loves*

- Importing an `aws_instance` without `associate_public_ip_address` set — plan wants to "change" it. Either match the current value in HCL or use `ignore_changes`.
- Forgetting that `aws_eip` on a VPC has `domain = "vpc"` — older docs show `vpc = true` which is deprecated.
- `aws_subnet` without `map_public_ip_on_launch` — defaults differ by how the subnet was created.
- RDS password on import — always drifts; use `ignore_changes = [password]` OR manage the secret via `random_password` + `aws_secretsmanager_secret_version`.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The scenario
- Milestones (check off as you go)
- Rubric (self-score out of 25)
- Gotchas the exam loves

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
