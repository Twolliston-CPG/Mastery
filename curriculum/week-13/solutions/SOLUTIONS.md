# Week 13 Solutions

---

## The clean-account test — what it actually catches

Every time someone runs this, the same five things break:

| Failure | Why it happens |
|---|---|
| **Hardcoded account ID** in `backend.tf` | You wrote it once and forgot it varies |
| **Hardcoded AMI ID** | Works in your region, fails elsewhere |
| A resource that already existed in your account | You never created it with Terraform; it was there from week 5 |
| **Missing IAM permission** the CI role happened to have | Your laptop is admin; the role isn't |
| **Undocumented manual step** | You did it once, months ago, and it's not in the README |

The last one is the important one. **The README is the deliverable**, and the only way to test it is
to follow it as a stranger would. Improvising while running your own instructions means the
instructions are wrong.

### The trick if you only have one account

```bash
make destroy ENV=dev
make destroy ENV=prod
aws s3 rm "s3://$(cd bootstrap && terraform output -raw state_bucket)" --recursive
cd bootstrap && terraform destroy
# Now clone into a fresh directory and follow the README from step one.
```

---

## Measurement reference values

For a typical Alpha on `t3.micro` with an Amazon Linux 2023 AMI:

| Metric | Typical | If yours is much worse |
|---|---|---|
| `apply` from clean (dev) | 8–14 min | RDS creation dominates (~10 min). Normal. |
| `apply` from clean (prod, Multi-AZ) | 15–25 min | Multi-AZ RDS is slow to create. Normal. |
| `apply` incremental (no changes) | 20–40 s | Mostly refresh time. `-refresh=false` speeds it up but hides drift. |
| PR opened → plan comment | 2–4 min | checkov is usually the slow step; cache it |
| Merge → deployed | 3–6 min + approval wait | |
| Instance terminated → healthy target | 2.5–5 min | Package installs at boot. A pre-baked AMI cuts this to ~60s. |
| RDS Multi-AZ failover | 60–120 s | |

**Write your real numbers in the README.** The gap between "it deploys automatically" and "deploy is
4m20s, the bottleneck is the AMI package install, I'd fix it with Packer" is the gap between a
junior answer and a strong one.

---

## Common Gate 3 failures, and the fix

### "It works in my account but not a clean one"
Grep for anything account-specific:
```bash
git grep -InE '[0-9]{12}' -- '*.tf' '*.tfvars.example' '*.md'
git grep -InE 'ami-[0-9a-f]{8,}' -- '*.tf'
git grep -InE 'vpc-|subnet-|sg-' -- '*.tf'
```
Everything found should be a variable, a data source, or a documented placeholder.

### "CI can plan but not apply"
The apply role's permissions are narrower than your laptop's admin. Build it from the **plan
output** — the resource types in the plan tell you exactly which actions are needed. Or run with a
broad role once, then scope down using CloudTrail:
```bash
aws cloudtrail lookup-events --lookup-attributes \
  AttributeKey=Username,AttributeValue=gha-apply --max-results 50 \
  --query 'Events[].EventName' --output text | tr '\t' '\n' | sort -u
```
**Building least privilege from CloudTrail evidence rather than guessing** is a real technique and a
good thing to be able to describe.

### "`destroy` fails"
Usual causes:
- **S3 bucket not empty** → `force_destroy = true` on lab buckets, or empty it first
- **RDS deletion protection** → `deletion_protection = false` in non-prod
- **ENIs still attached** → a Lambda or a load balancer node not yet released; wait and retry
- **`prevent_destroy`** doing its job → that's correct; comment it out deliberately for the lab

### "checkov fails on something I can't fix"
Write the ADR (see `docs/adr/0005-checkov-exceptions.md`). A documented, justified, dated exception
is a *better* artifact than a clean scan achieved by disabling the gate — and it is something you can
actually talk about.

---

## The "What broke" section — how to write it well

Three entries minimum. Each one: symptom → what was actually wrong → how you found it → prevention.

**Weak:**
> Had some trouble with the load balancer health checks but fixed it.

**Strong:**
> **ALB returned 503 for every request.** Instances were Running and the app responded to `curl` from
> inside the VPC. `aws elbv2 describe-target-health` showed `Target.Timeout` rather than
> `Target.FailedHealthChecks` — which was the clue: the ALB couldn't reach the instances at all.
> The app security group allowed the VPC CIDR, but the ALB's ENIs were in a subnet I'd re-CIDR'd, so
> the rule no longer covered them. Fixed by referencing the ALB's **security group ID** as the source
> instead of a CIDR, which follows the ALB wherever it lives. I now use SG-to-SG references
> everywhere and treat a CIDR-based intra-VPC rule as a smell.

The second version demonstrates a diagnostic method, a specific tool, a root cause, and a
generalized lesson. **It also hands the interviewer their next question, pre-answered.**

---

## Terraform Associate: the traps

From `_reference/terraform/drills/feynman-exam-traps.md`, the ones that catch people:

1. **`terraform init` does not download modules from a `source` that changed** unless you pass
   `-upgrade` or delete `.terraform/modules`. `terraform get -update` also does it.
2. **Workspaces do not isolate the backend** — all workspaces share one backend, with separate state
   *keys*. This is why they're wrong for prod/dev separation (ADR-0004).
3. **`terraform destroy` is `terraform apply -destroy`.** They're the same operation.
4. **Variable precedence**, highest to lowest: `-var` / `-var-file` on the command line (last wins) →
   `*.auto.tfvars` (alphabetical) → `terraform.tfvars` → `TF_VAR_*` environment variables → default.
   **Command line beats environment variables** — people get this backwards.
5. **`terraform fmt` changes files by default.** `-check` only reports.
6. **Provisioners are a last resort** and `local-exec`/`remote-exec` do not run on subsequent applies
   unless the resource is replaced. The exam asks; the answer in real work is "use cloud-init."
7. **HCP Terraform execution modes:** *remote* runs the plan/apply on HashiCorp's infrastructure;
   *local* uses HCP only for state; *agent* runs on your own agent in a private network.
8. **Sentinel policies run between plan and apply**, and can be advisory, soft-mandatory, or
   hard-mandatory.
9. `terraform state list` shows **addresses**; `terraform show` shows **attributes**.
10. A **partial backend configuration** (`backend "s3" {}` with values supplied via
    `-backend-config`) is how you keep environment-specific backend settings out of the code.
