# The repository's policy gate

> Policy as code on the repository's own Terraform, the way week 19 Lab 1 teaches it on Project
> Alpha. Six rules in Rego, evaluated by Conftest on raw HCL, so the gate needs no plan and no
> credentials. CI runs it in `iac-scan`; `make policy` runs the same thing at the same pinned
> version. There is no inline suppression for this gate, on purpose.

## What it checks

| Rule | Why the repository holds it |
|---|---|
| Every `aws_s3_bucket` has an `aws_s3_bucket_public_access_block` in the same file, all four flags true | State buckets hold secrets in plain text |
| Every `google_storage_bucket` has `public_access_prevention = "enforced"` and `uniform_bucket_level_access = true` | Same: IAM only, cannot be made public by mistake |
| No security-group rule, standalone or inline, opens tcp/22 to `0.0.0.0/0` or `::/0` | SSH reaches the lab only through an Instance Connect Endpoint; the rule references its security group |
| Every `aws_instance` and `aws_launch_template` sets `metadata_options.http_tokens = "required"` | IMDSv2: week 5 Lab 5's SSRF, closed by a token and a hop limit |
| No `google_compute_instance` has a `service_account` block | A lab VM gets no GCP identity, so nothing running on it can call a GCP API |
| Every `google_compute_firewall` ingress rule names a source, and none admits the world on tcp/22 | SSH reaches the GCP lab only through IAP's range |

Expressions are not judged. A `cidr_ipv4 = var.x` or a `from_port = each.value.port` is unknown,
not open, and the rule skips it: a false positive would train people to ignore the gate. What a
variable may hold is the README's job and the reviewer's.

## Run it

```bash
make policy                                  # the pinned conftest in .tools/bin, as CI runs it

# or by hand, with any conftest
conftest verify --policy infra/policy/terraform --namespace terraform
git ls-files -z -- 'infra/**/*.tf' 'curriculum/_setup/**/*.tf' 'curriculum/projects/alpha-cloud-foundation/**/*.tf' \
  | xargs -0 conftest test --parser hcl2 --policy infra/policy/terraform --namespace terraform
```

`conftest parse --parser hcl2 <file.tf>` prints what a rule sees: `input.resource.<type>.<name>`
is a list of blocks, nested blocks are lists, expressions are `"${...}"` strings.

## Add a rule

1. A `deny contains msg if { ... }` in `terraform.rego`. The message names the resource address
   and says the fix.
2. Two tests in `terraform_test.rego`: a fixture that passes and one that fails, in the parser's
   shape. `json.patch` on a shared fixture keeps them short.
3. A row in the table above.
4. `make policy` green on the current repository before the pull request. A rule the repository
   does not already satisfy is either wrong for this repository or a real finding; fix the
   Terraform in the same pull request, with its own reason.

## Exceptions

There is no skip. If a resource must break a rule, narrow the rule in the same pull request, with
the reason in the rule's comment, so the exception is reviewed as code and is visible to the next
reader. That is the difference between this gate and checkov or trivy, whose suppressions sit on
the resource; both forms are deliberate, and this one exists so the repository has at least one
gate that cannot be quieted in place.
