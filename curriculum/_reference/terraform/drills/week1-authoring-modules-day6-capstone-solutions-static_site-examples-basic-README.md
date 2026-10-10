# Basic example — `static_site`

Smallest invocation that satisfies the module's required variables.

## What it shows

- Module source as a relative path (`../../`) — registry convention for examples.
- Passing both required provider aliases via the `providers = {}` block.
- Using defaults for every optional field (`origin_bucket`, `custom_error_pages`, `cors_rules`, `tags`).

## Prerequisites

- A Route53 hosted zone for `example.com`. Replace `hosted_zone_id` with your real zone ID before applying.
- AWS credentials configured for the default region (here `eu-west-1`) with permission to create S3, CloudFront, ACM, and Route53 records.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Teardown

```bash
terraform destroy
```

Note: CloudFront distributions can take 15–20 minutes to disable before destroy completes. That's expected.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What it shows

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
