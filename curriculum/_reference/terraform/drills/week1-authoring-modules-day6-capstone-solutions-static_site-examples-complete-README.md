# Complete example — `static_site`

Exercises every optional field in the module's variable surface. Use this to check behavior when you modify the module — if plan diffs unexpectedly here, you broke backwards compatibility.

## What it shows

- Multiple `domain_names` — CloudFront alternate names, multi-SAN ACM cert.
- `origin_bucket.versioning = true` and custom bucket tags merged with top-level `tags`.
- Two `custom_error_pages` (404 and 500), one using a shorter `error_caching_min_ttl`.
- One `cors_rules` entry with all fields populated (including the optional `allowed_headers`, `expose_headers`, `max_age_seconds`).
- Module-level `tags` plus `default_tags` on both providers — CloudFront's tag merge order is a known gotcha.

## Usage

```bash
terraform init
terraform plan
```

Do **not** apply unless you own `example.com` in the supplied hosted zone. Even then, `terraform destroy` on a CloudFront distribution takes 15–20 minutes.

## What to check on plan

- ACM cert resources appear under the `aws.us_east_1` alias, not the default.
- S3 bucket appears once, not once per domain name.
- Route53 records: one per name in `domain_names`.
- CloudFront distribution has the expected number of custom error responses (2) and no CORS-specific config (CORS is an S3 bucket CORS config, not CloudFront).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What it shows
- What to check on plan

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
