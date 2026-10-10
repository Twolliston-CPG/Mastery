# Capstone — Reference Solution

**Look at this AFTER you've attempted the assignment in `../` yourself.**

Comparing your implementation to this one teaches more than reading it cold. A non-trivial chunk of the exam tests your ability to *reason about* a module, not just write one — so the compare-and-contrast step matters.

## What's in here

- `static_site/` — the complete module (versions, variables, main, outputs, tests).
- `envs/dev/` — a root module that consumes it.

## Validating

```bash
cd static_site
terraform init
terraform validate
terraform test        # uses mock_provider, no real AWS calls
```

## Notes on design choices

- **Provider aliasing:** both `aws` and `aws.us_east_1` are declared under `configuration_aliases`. Caller must pass both.
- **Cert in us-east-1:** enforced by `precondition` on `aws_acm_certificate.this` — guards against someone wiring the wrong alias.
- **Custom error responses** use `for_each` (not `count`) keyed by the HTTP code — adding/removing entries won't churn the rest.
- **CORS is optional** — `dynamic "cors_rule"` fires only if the input list has items.
- **Check block** warns (doesn't block) when the cert has < 30 days remaining. Fires on every plan.
- **OAC over OAI:** CloudFront Origin Access Control is the current recommendation; OAI is legacy.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What's in here
- Validating
- Notes on design choices

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
