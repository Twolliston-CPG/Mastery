# Break/Fix: Terraform & CI/CD (BF-33 – BF-40)

---

## BF-33 — State lock stuck

**SYMPTOM:** `Error acquiring the state lock. Lock Info: ID: abc-123, Who: user@host`

**BREAK:** Start an apply, kill it with `kill -9` mid-run.

**DIAGNOSIS:**
```bash
aws dynamodb get-item --table-name terraform-locks \
  --key '{"LockID":{"S":"my-bucket/path/terraform.tfstate"}}'
# Read: Who, Created, Operation -- is a real apply still running somewhere?
```

**FIX — in this order:**
1. **Confirm nobody is actually applying.** Check CI runs and ask the team. Force-unlocking a live
   apply corrupts state.
2. `terraform force-unlock <LOCK_ID>`
3. Last resort: delete the DynamoDB lock item directly

**WHY THE LOCK EXISTS:** Two concurrent applies against one state file produce a corrupted state and
orphaned real resources. The lock is protecting you.

**INTERVIEW ANSWER:** "I'd verify no apply is in flight — CI and teammates — then `force-unlock` with
the ID from the error. The dangerous move is force-unlocking reflexively."

---

## BF-34 — `count` index shift destroys the wrong resources

**SYMPTOM:** You removed one subnet from a list of five. The plan shows **3 destroys and 3 creates**.

**BREAK:**
```hcl
variable "subnets" { default = ["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24"] }
resource "aws_subnet" "this" {
  count      = length(var.subnets)
  cidr_block = var.subnets[count.index]
}
```
Now delete the middle element.

**DIAGNOSIS:** `terraform plan` — addresses are `aws_subnet.this[0]`, `[1]`, `[2]`. Removing the
middle element shifts everything after it down by one, so `[1]` and `[2]` now describe different
CIDRs and must be replaced.

**FIX — use `for_each` with stable keys:**
```hcl
variable "subnets" {
  default = {
    a = "10.0.1.0/24"
    b = "10.0.2.0/24"
    c = "10.0.3.0/24"
  }
}
resource "aws_subnet" "this" {
  for_each   = var.subnets
  cidr_block = each.value
}
```
Addresses become `aws_subnet.this["a"]`, `["b"]`, `["c"]`. Removing `"b"` destroys exactly one thing.

**EMERGENCY FIX without recreating:** `terraform state mv 'aws_subnet.this[2]' 'aws_subnet.this[1]'`

**THE RULE:** `count` for *"do I want N identical things or zero"*. `for_each` for *"I have a set of
distinct named things."* In practice `for_each` is right ~90% of the time. **This is the most
commonly asked Terraform interview question.**

---

## BF-35 — Plan wants to destroy and recreate unexpectedly

**SYMPTOM:** A tag change produces `# forces replacement` on an RDS instance.

**DIAGNOSIS:** Read the plan carefully — Terraform marks the exact attribute:
```
~ resource "aws_db_instance" "main" {
    ~ availability_zone = "us-east-1a" -> "us-east-1b" # forces replacement
```

**ROOT CAUSES:**
1. A `ForceNew` attribute changed (AZ, subnet, name on some resources)
2. A data source returns a different value on each plan
3. Provider upgrade changed a default
4. Something outside Terraform modified the resource (drift)

**FIXES:**
```hcl
lifecycle {
  ignore_changes        = [tags["LastModified"]]  # ignore noisy attributes
  create_before_destroy = true                    # avoid downtime on replacement
  prevent_destroy       = true                    # hard stop on prod databases
}
```

**RULE:** `prevent_destroy = true` on every production database and every state bucket. It has saved
more careers than any other single line of HCL.

---

## BF-36 — Secret leaked into state

**SYMPTOM:** `grep -i password terraform.tfstate` returns a plaintext credential.

**ROOT CAUSE:** **Terraform state stores every attribute in plaintext, including
`sensitive = true` ones.** `sensitive` only hides values from CLI *output*; it does nothing to state.

**FIX — the actual remediation, in order:**
1. **Rotate the credential.** It is compromised. Everything else is secondary.
2. Encrypt state at rest: S3 with SSE-KMS, bucket versioning on, public access blocked
3. Lock the state bucket down to the CI role only
4. Stop generating secrets in Terraform — reference them instead:
```hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/db/password"
}
resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db.secret_string
}
```
Note this *still* lands in state — which is why step 1 is rotation and step 2 is encryption. The
fully-clean pattern is to let the resource generate it (`manage_master_user_password = true` on RDS)
so Terraform never sees the value at all.

**INTERVIEW ANSWER:** "State is plaintext. `sensitive` is a display flag, not encryption. So: encrypt
the backend, restrict access to it, keep secrets out of Terraform where possible, and if one leaks,
rotate first."

---

## BF-37 — OIDC trust policy rejects the token

**SYMPTOM:** GitHub Actions: `Not authorized to perform sts:AssumeRoleWithWebIdentity`.

**DIAGNOSIS:** Read the trust policy's `sub` condition against the token's actual `sub` claim.

```json
{
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:ref:refs/heads/main"
    }
  }
}
```

**ROOT CAUSES:**
1. **`sub` doesn't match.** A PR run's sub is `repo:org/repo:pull_request`, not
   `...:ref:refs/heads/main`. A tag run is `...:ref:refs/tags/v1`. An environment run is
   `repo:org/repo:environment:production`.
2. Using `StringEquals` where you need `StringLike` with a wildcard
3. Missing `id-token: write` permission in the workflow
4. OIDC provider thumbprint/ARN wrong
5. `aud` not set to `sts.amazonaws.com`

**FIX — allow branches and PRs deliberately:**
```json
"StringLike": { "token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:*" }
```
…but scope it down for production. `repo:org/repo:*` means **any branch in that repo can assume the
role** — which means anyone who can open a PR can reach your AWS account. For a production role,
pin to `environment:production` and use a protected GitHub environment with required reviewers.

**SAY THIS IN AN INTERVIEW:** The wildcard-vs-pinned-sub tradeoff is a genuine security decision and
very few juniors know it exists.

---

## BF-38 — Works locally, fails in CI

**SYMPTOM:** `terraform apply` is clean on your laptop; the identical commit fails in GitHub Actions.

**DIAGNOSIS:**
```bash
terraform version                    # version pinned in CI? probably not
env | grep -i 'aws\|tf_'             # local env vars CI doesn't have
cat .terraform.lock.hcl              # committed? platform hashes present?
```

**ROOT CAUSES:**
1. Different Terraform or provider version — **pin both**
2. Local `AWS_PROFILE` / `~/.aws/credentials` that CI doesn't have
3. `.terraform.lock.hcl` not committed, or missing the CI platform's hashes
4. Local state vs remote state
5. A `terraform.tfvars` that is gitignored

**FIX:**
```hcl
terraform {
  required_version = "~> 1.9.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}
```
```bash
terraform providers lock \
  -platform=darwin_arm64 -platform=linux_amd64      # both platforms in the lock file
```
Commit `.terraform.lock.hcl`. Always.

**THE PRINCIPLE:** "Works on my machine" is a dependency-pinning failure. Pin the tool, pin the
providers, commit the lock file, and inject config through variables rather than ambient environment.

---

## BF-39 — Concurrent applies race

**SYMPTOM:** Two PRs merge within a minute. One apply overwrites the other's changes, or state
conflicts.

**ROOT CAUSE:** Two workflow runs applying the same state concurrently. The lock makes one fail
rather than corrupt — but a failed production apply at 2pm is still an incident.

**FIX:**
```yaml
concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: false      # QUEUE them; never cancel a running apply
```

**`cancel-in-progress: false` IS THE IMPORTANT PART.** Cancelling a running `terraform apply` leaves
a stuck lock (BF-33) and possibly half-created infrastructure. Queue, never cancel.

---

## BF-40 — Drift: someone changed it in the console

**SYMPTOM:** `terraform plan` shows changes nobody made in code.

**DIAGNOSIS:**
```bash
terraform plan -refresh-only        # shows ONLY real-world drift
terraform show -json | jq '.values.root_module.resources[] | {address, values}'
# Then CloudTrail: who changed it, and when?
aws cloudtrail lookup-events --lookup-attributes \
  AttributeKey=ResourceName,AttributeValue=<resource>
```

**THE DECISION — and this is the interesting part:**
| Situation | Action |
|---|---|
| Emergency fix someone made under pressure | **Codify it.** Update the Terraform to match reality. |
| Unauthorized or accidental change | **Revert it.** `terraform apply` restores desired state. |
| Legitimately managed outside Terraform | `lifecycle { ignore_changes = [...] }` or move it out |

**FIX:** `terraform apply -refresh-only` accepts drift into state without changing infrastructure.

**PREVENT:** Scheduled drift detection in CI (nightly `plan`, alert on non-empty), IAM that denies
console writes to production, and a break-glass role that is loud when used.

**INTERVIEW ANSWER:** "Drift isn't automatically a problem to revert — first I'd find out *why* it
happened. If it was an emergency fix, reverting it re-breaks production." That answer is a level
above the expected one.
