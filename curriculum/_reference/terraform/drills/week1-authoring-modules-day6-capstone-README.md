# Week 1 · Day 6 — Capstone: Build the `static_site` module

**Goal:** Synthesize everything from Days 1–5 into one reusable, tested, multi-region module.

## The brief

You're building an internal Terraform module `static_site` for your org. Consumers should be able to write:

```hcl
module "site" {
  source  = "../../modules/static_site"
  providers = {
    aws           = aws            # default region (e.g. eu-west-1)
    aws.us_east_1 = aws.us_east_1  # REQUIRED for ACM cert (CloudFront only trusts us-east-1 certs)
  }

  name         = "marketing"
  domain_names = ["www.example.com", "example.com"]
  origin_bucket = {
    versioning = true
    tags       = { Owner = "growth" }
  }
  custom_error_pages = {
    "404" = { response_code = "404", response_page_path = "/errors/404.html" }
    "500" = { response_code = "500", response_page_path = "/errors/500.html" }
  }
}
```

## Functional requirements

1. **S3 origin bucket** with:
   - Private ACL, block public access fully enabled.
   - Versioning togglable via input (default `false`).
   - Dynamic CORS rules when `cors_rules` input is non-empty.
2. **CloudFront distribution** with an OAC (Origin Access Control) pointing at the bucket.
3. **ACM certificate** in `us-east-1` (required by CloudFront) via a provider alias.
4. **Route53 records** for each `domain_names` entry, pointing at the distribution.
5. **Custom error responses** built with `dynamic "custom_error_response"` from a `map(object)` input.
6. **Outputs:** `bucket_name`, `distribution_id`, `distribution_domain_name`, `certificate_arn`.

## Non-functional requirements (what the exam grader would look for)

- [ ] `required_version = ">= 1.6.0"` and pinned provider versions (`~> 5.0`).
- [ ] `configuration_aliases = [aws, aws.us_east_1]` in the module's `required_providers`.
- [ ] Input validation on `domain_names` (must be non-empty + each entry a valid DNS name via regex).
- [ ] Input validation on `name` (DNS-safe lowercase).
- [ ] `precondition` on the ACM cert ensuring it was created in us-east-1 (`self.arn` contains `:us-east-1:`).
- [ ] `postcondition` on the distribution ensuring `status == "Deployed"` after apply (or skip if you don't `apply`).
- [ ] `for_each` (not `count`) for custom_error_pages and domain_names.
- [ ] `dynamic` block for CORS + custom_error_response.
- [ ] A `check` block that warns if the cert has < 30 days to expiry.
- [ ] `.tftest.hcl` suite with at minimum:
   - Plan test with `mock_provider "aws"` for both the default alias and the `us_east_1` alias.
   - Negative test (`expect_failures`) for an invalid domain name.
- [ ] `README.md` in the module with the standard sections: Usage, Inputs, Outputs, Requirements.

## Rubric (self-score out of 20)

| Area | Pts |
|---|---|
| Provider aliasing wired end-to-end | 4 |
| Input validation (≥ 3 `validation` blocks) | 3 |
| Custom conditions (pre/post/check) applied meaningfully | 3 |
| Dynamic + for_each used idiomatically | 3 |
| `.tftest.hcl` passes (`terraform test`) | 4 |
| Outputs complete & typed | 1 |
| README quality | 2 |

## Where to start

1. Open `modules/static_site/` — skeleton files are pre-created with TODOs.
2. Do the easy stuff first: `variables.tf` with validations, `versions.tf` with aliases, `outputs.tf`.
3. Then `main.tf` — build bucket → OAC → cert → distribution → records in that order.
4. Write tests in `modules/static_site/tests/` as you go — don't save them for the end.
5. Wire the root `envs/dev/main.tf` and run `terraform plan` — do NOT `apply` unless you have a hosted zone you control (cert validation needs DNS).

## Self-review checklist before declaring "done"

```bash
cd modules/static_site
terraform init
terraform validate
terraform fmt -check -recursive
terraform test                        # should be green with mocks
cd ../../envs/dev
terraform init
terraform plan                        # no errors; plan looks reasonable
```

If you get stuck for > 20 minutes on a concept, re-open the relevant Day 1–5 README — there's a high chance the answer is there.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Functional requirements
- Non-functional requirements (what the exam grader would look for)
- Rubric (self-score out of 20)
- Where to start

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
