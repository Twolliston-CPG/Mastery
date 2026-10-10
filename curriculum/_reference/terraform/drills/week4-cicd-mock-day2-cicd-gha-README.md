# Week 4 · Day 2 — CI/CD with GitHub Actions

**Exam domain:** 3 — "Use Terraform workflow in automation".

## Learning goals

1. The **canonical Terraform pipeline** stages: `fmt` → `init` → `validate` → `plan` → (approval) → `apply`.
2. Use **`hashicorp/setup-terraform`** action to pin versions in CI.
3. **PR-time speculative plans** with plan-output-as-comment pattern.
4. **Merge-time applies** with protected environments.
5. Integrate **policy/security scanners**: tfsec, checkov, trivy.
6. Use **OIDC to AWS** from GitHub Actions — no static keys in GitHub.
7. Cache `.terraform/` and lock file between jobs.
8. `TF_IN_AUTOMATION=1` — suppresses interactive prompts.

## Minimum viable pipeline

See `.github/workflows/terraform.yml`. Two jobs:

1. **plan** — runs on every PR, comments the plan output, fails the check if `terraform plan -detailed-exitcode` returns 1 or 2 and merging would cause destroy.
2. **apply** — runs on push to `main`, requires manual approval via GitHub environment protection.

## OIDC from GitHub Actions to AWS

```yaml
permissions:
  id-token: write        # needed to fetch OIDC token
  contents: read

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-tf
          aws-region: us-east-1
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.14.8
      - run: terraform init
      - run: terraform plan -out=tfplan
```

The AWS IAM role's trust policy must allow `token.actions.githubusercontent.com` with `sub` matching your repo.

## Exam-relevant flags

| Flag | Purpose |
|---|---|
| `TF_IN_AUTOMATION=1` | Quieter output, no "If you ran this command…" hints |
| `TF_CLI_ARGS_plan="-input=false -no-color -lock-timeout=5m"` | Default flags for plan in CI |
| `terraform plan -detailed-exitcode` | 0=no diff, 1=error, 2=diff — pipeline gold |
| `terraform init -upgrade=false` | Honor lock file even if a newer version exists |
| `terraform apply -auto-approve` | Needed for non-interactive runs |
| `terraform plan -out=plan.bin && terraform apply plan.bin` | Binary plan handoff — no TOCTOU |

## Exercises

1. Commit the sample workflow in `.github/workflows/terraform.yml` to a scratch repo with one small HCL file.
2. Configure an OIDC role in AWS (reuse Week 3 Day 3 bootstrap, swap HCP for GitHub trust).
3. Push a PR — watch plan post as a comment.
4. Add `tfsec` or `checkov` as a step; intentionally include a public S3 to see it block the merge.
5. Merge — observe apply job.

## Self-check

1. `terraform plan -detailed-exitcode` returns 2. What does it mean?
2. Why use `plan -out=tfplan` + `apply tfplan` instead of `apply` directly in CI?
3. Where's the OIDC trust policy's `sub` field scoped — per repo or per branch?
4. `TF_IN_AUTOMATION=1` — does it change behavior or just output?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Minimum viable pipeline
- OIDC from GitHub Actions to AWS
- Exam-relevant flags

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
