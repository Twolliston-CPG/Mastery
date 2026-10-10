# Week 10 Solutions

Working Terraform: [`../projects/alpha-cloud-foundation/`](../../projects/alpha-cloud-foundation/)

---

## Lab 1 — HCL

### `~` vs `-/+` in a plan

```
~ instance_type = "t3.micro" -> "t3.small"          # in-place update, brief reboot
-/+ availability_zone = "us-east-1a" -> "us-east-1b" # forces replacement
```

Every provider attribute is either updatable in place or **ForceNew**. The provider schema decides,
and the plan always tells you with `# forces replacement`. **Read the plan.** The number of
production incidents caused by someone applying without reading a plan that said
`1 to destroy` is not small.

### Implicit vs explicit dependencies

```hcl
resource "aws_instance" "web" {
  vpc_security_group_ids = [aws_security_group.web.id]   # implicit edge -- Terraform sees it
}
```
Terraform builds its DAG from **references**. Because the instance references the SG's `id`, the SG
is created first and destroyed last. No `depends_on` needed.

`depends_on` is for dependencies Terraform **cannot see**:
```hcl
resource "aws_instance" "app" {
  depends_on = [aws_iam_role_policy.app]   # IAM propagation isn't expressed in an attribute
}
```
Over-using `depends_on` serializes your graph and slows applies. It's a smell when it's used where a
reference would do.

### Why a data source instead of a hardcoded AMI

AMI IDs are **region-specific and change with every patch release**. Hardcoding one means the config
breaks in another region and silently goes stale. The `aws_ami` data source with `most_recent = true`
always resolves the current one.

**The counter-argument worth knowing:** `most_recent = true` means your config is not deterministic —
a plan today and a plan next month can differ with no code change, which can cause an unexpected
instance replacement. In production you often **pin** the AMI ID in a variable and bump it
deliberately, or use an SSM parameter you control. Being able to state both sides is the mature
answer.

---

## Lab 2 — State

### What's actually in it

```json
{
  "version": 4,
  "terraform_version": "1.9.5",
  "serial": 12,
  "lineage": "a1b2c3d4-...",
  "resources": [{
    "mode": "managed",
    "type": "aws_instance",
    "name": "web",
    "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
    "instances": [{
      "schema_version": 1,
      "attributes": { "id": "i-0abc", "ami": "ami-0xyz", "...": "every attribute" },
      "dependencies": ["aws_security_group.web"]
    }]
  }]
}
```

- **`serial`** increments on every write — this is how the backend detects a conflicting write
- **`lineage`** identifies the state's identity; pushing state with a different lineage is refused
- **`dependencies`** is the recorded graph, used to order *destroys* correctly even after you've
  deleted the config

### Backend bootstrap: the chicken-and-egg problem

You need an S3 bucket to store state, but creating the bucket with Terraform means storing *that*
state somewhere. Three answers:

1. **A separate `bootstrap/` directory with local state, committed to git.** Applied once, rarely
   changed. Simple and explicit — this is what most teams do and what the Alpha reference uses.
2. Create the bucket with the CLI or CloudFormation.
3. Create it with local state, then migrate the bootstrap config's own state into the bucket it just
   created (`terraform init -migrate-state`). Clever, and slightly fragile.

Any of the three is defensible. Having an opinion and a reason is what matters.

### `use_lockfile` vs DynamoDB

Terraform 1.10+ supports S3-native conditional-write locking via `use_lockfile = true` — no DynamoDB
table needed. Older versions require `dynamodb_table` with a `LockID` string partition key.

You will meet both. Existing codebases are full of the DynamoDB pattern, so know it:
```hcl
backend "s3" {
  bucket         = "tfstate-..."
  key            = "path/terraform.tfstate"
  dynamodb_table = "terraform-locks"
  encrypt        = true
}
```

### BF-33 — the correct order

```bash
# 1. CONFIRM nobody is actually applying. Check CI runs. Ask the team.
aws dynamodb get-item --table-name terraform-locks \
  --key '{"LockID":{"S":"bucket/path/terraform.tfstate"}}'
# read: Who, Created, Operation

# 2. Then unlock
terraform force-unlock <LOCK_ID>
```

**Force-unlocking a genuinely running apply corrupts state and orphans real resources.** The
interview answer is: *"I'd verify no apply is in flight — CI and teammates — then force-unlock with
the ID from the error. The dangerous move is force-unlocking reflexively."*

### BF-36 — secrets in state

```bash
terraform state pull | grep -i password
```

They are there, in plaintext, regardless of `sensitive = true` — which only suppresses **CLI
output**.

**Remediation order:**
1. **Rotate the credential.** It is compromised. Everything else is secondary.
2. Encrypt the backend (SSE-KMS), enable versioning, block public access
3. Restrict bucket access to the CI role only
4. Stop generating secrets in Terraform where possible —
   `manage_master_user_password = true` on RDS puts it straight into Secrets Manager and Terraform
   never sees the value

---

## Lab 3 — Import and drift

### Import: plan to empty

```bash
terraform plan -generate-config-out=generated.tf
```
Terraform writes a config block matching the real resource. It is a **starting point**, not final —
it includes computed attributes and defaults you should strip. Iterate until `terraform plan` reports
**"No changes."** Anything else means applying would modify the real resource.

`import` blocks (1.5+) are better than `terraform import` because they are **plannable and
reviewable** — they appear in the plan output and live in a PR, rather than being an imperative
action someone ran on their laptop.

### `moved` vs `state mv`

```hcl
moved {
  from = aws_instance.web
  to   = module.compute.aws_instance.web
}
```
| | `moved` block | `terraform state mv` |
|---|---|---|
| Where it lives | In code, in the PR | A local command |
| Reviewable | Yes | No |
| Runs in CI | Yes | No |
| Auditable | Git history | Nowhere |

`moved` blocks are how you refactor a module structure without destroying and recreating every
resource. **Refactoring without downtime is exactly the kind of thing that distinguishes someone who
has maintained Terraform from someone who has only written it.**

### Drift — the decision, not the command

The command is easy (`plan -refresh-only`). The judgment is the answer:

> *"Drift isn't automatically something to revert. First I'd find out why it happened. If someone
> made an emergency fix at 2am, reverting it re-breaks production — the right move is to codify it
> and then fix the process that made a manual change necessary. If it was accidental or
> unauthorized, revert and tighten IAM. If it's something legitimately managed by another system,
> add `ignore_changes`."*

That answer is a level above the expected one.

**Prevention:** scheduled nightly `terraform plan` in CI with an alert on a non-empty plan; IAM that
denies console writes in production; a break-glass role that pages when used.
