# Week 10 Assessment

> Closed book, 30 min. (Short this week — you sat an exam.)

## Part A (15 min)
1. What is in Terraform state, and name three reasons it matters operationally.
2. Does `sensitive = true` encrypt state? What does it do?
3. A secret leaked into state. What is the first action and why?
4. How does Terraform know to create the security group before the instance?
5. When is `depends_on` actually necessary, and what does over-using it cost?
6. `~` vs `-/+` in a plan. What decides which you get?
7. Two engineers run `apply` at the same time. What happens and why?
8. You killed an apply with Ctrl-C and now `plan` fails. Walk through the correct fix, in order.
9. How do you bring existing console-created infrastructure under Terraform? What is the acceptance
   criterion?
10. `moved` block vs `terraform state mv` — three differences.

## Part B — Write it (10 min)
11. A `terraform` block pinning the version, the AWS provider, and an S3 backend with locking
12. A variable with a validation restricting it to three values
13. A `lifecycle` block that prevents destruction and ignores changes to one tag
14. The command that shows drift only
15. The command that accepts drift into state without changing infrastructure

## Part C — Judgment (5 min)
16. `terraform plan` shows it will destroy your production RDS instance. Walk through what you do.
17. Nightly drift detection finds that someone changed a security group by hand yesterday. What do
    you do, and what determines the answer?

---

# Answer key

**A1.** A JSON mapping of configuration addresses to real resource IDs, every resource's full
attribute set, the dependency graph, a `serial`, and a `lineage`. It matters because: it is
**plaintext including secrets**; it is **shared mutable state** so concurrent writes corrupt it
(hence locking); and it can **drift** from reality.

**A2.** **No.** It only suppresses the value in CLI output and plan display. State remains plaintext.
Encrypt the backend instead.

**A3.** **Rotate the credential.** It is compromised the moment it exists in a place you didn't
intend. Encryption, access restriction, and state surgery all come after.

**A4.** An **implicit dependency** — `aws_instance.web` references `aws_security_group.web.id`, which
creates an edge in the DAG. Terraform derives ordering from references.

**A5.** Only for dependencies not expressed by a reference — IAM policy propagation, an S3 bucket
policy that must exist before a service writes, something managed outside Terraform. Over-using it
serializes the graph and slows applies, and it's a smell where a reference would do.

**A6.** The **provider schema**. Each attribute is either updatable in place or **ForceNew**. The
plan marks it `# forces replacement`.

**A7.** **State locking** makes one fail with "Error acquiring the state lock" rather than letting
both write and corrupt state. In CI, use a `concurrency` group with `cancel-in-progress: false` so
runs queue instead of racing or being cancelled mid-apply.

**A8.** (1) **Confirm no apply is actually running** — check CI and ask the team. (2)
`terraform force-unlock <LOCK_ID>` using the ID from the error. (3) Last resort: delete the lock
item directly. Force-unlocking a live apply corrupts state and orphans resources.

**A9.** An `import` block (plannable, reviewable, 1.5+) or `terraform import`, then write config to
match, optionally with `-generate-config-out`. **Acceptance criterion: `terraform plan` reports "No
changes."** Any remaining diff means applying would modify the real resource.

**A10.** `moved` lives in code / is reviewable in a PR / runs in CI / is in git history.
`state mv` is a local imperative command that is none of those. Prefer `moved`.

---

**B11.**
```hcl
terraform {
  required_version = "~> 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.68" }
  }
  backend "s3" {
    bucket       = "tfstate-123456789012-us-east-1"
    key          = "alpha/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

**B12.**
```hcl
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}
```

**B13.**
```hcl
lifecycle {
  prevent_destroy = true
  ignore_changes  = [tags["LastModified"]]
}
```

**B14.** `terraform plan -refresh-only`
**B15.** `terraform apply -refresh-only`

---

**C16.** **Do not apply.** Read the plan — Terraform marks the exact attribute with
`# forces replacement`. Usually: someone changed an immutable attribute (AZ, identifier), a provider
upgrade changed a default, or state lost track of the resource. Depending on which: revert the config
change, add `ignore_changes`, or `terraform import`. **And the preventive answer:
`prevent_destroy = true` on every production database**, so this fails at plan time instead of
depending on someone reading carefully at 5pm on a Friday.

**C17.** **It depends on why.** First check CloudTrail for who and when, then ask them. If it was an
emergency fix during an incident, **codify it** — reverting would re-break production — and then fix
the process that made a manual change necessary. If it was accidental or unauthorized, revert with
`terraform apply` and tighten IAM so console writes to production aren't possible. If it's genuinely
managed by another system, add `ignore_changes`. Automatically reverting drift without understanding
it is how you cause a second outage.

## Scoring
| | |
|---|---|
| 15–17 | Move on. |
| 11–14 | Redo Lab 2 (state) and Lab 3 (import). |
| < 11 | **Redo the whole week's labs.** State is the thing that goes wrong in real Terraform work and the thing interviewers probe. |
