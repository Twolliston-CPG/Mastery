# Week 3 · Day 5 — Policy as Code (Sentinel + OPA)

**Exam domain:** 6 — "Analyze policy as code and governance features".

## Learning goals

1. **Where policy-as-code fits** — runs execute Plan → Policy Check → Apply.
2. **Enforcement levels**: `advisory`, `soft-mandatory` (overridable by admins), `hard-mandatory` (stops everything).
3. **Sentinel** — HashiCorp's DSL, integrates deeply with Terraform's plan JSON.
4. **OPA/Rego** — the open alternative HCP also supports.
5. **Policy sets** — versioned collections of policies, attached to projects or orgs.
6. **Run Tasks** — webhook into *any* external scanner (Checkov, Snyk, tfsec) that can pass/fail a run.

## Run phases with policies

```
Plan  →  Cost Estimate  →  Policy Check  →  (approval)  →  Apply
                           ↑
                Sentinel & OPA evaluate here
```

## Enforcement levels

| Level | On failure | Who can override |
|---|---|---|
| `advisory` | Warning, run proceeds | n/a |
| `soft-mandatory` | Run stops, but can be overridden | Workspace admins |
| `hard-mandatory` | Run stops, **nobody** overrides | n/a |

## Example Sentinel — block big instances

```sentinel
import "tfplan/v2" as tfplan

# all aws_instance resources being created or updated
instances = filter tfplan.resource_changes as _, rc {
    rc.type is "aws_instance" and
    rc.mode is "managed" and
    (rc.change.actions contains "create" or rc.change.actions contains "update")
}

disallowed = ["m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge"]

# all instances must NOT use disallowed types
main = rule {
    all instances as _, inst {
        inst.change.after.instance_type not in disallowed
    }
}
```

## Example OPA (Rego) — deny public S3

```rego
package terraform.policies.public_s3

deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "aws_s3_bucket_public_access_block"
    rc.change.after.block_public_acls == false
    msg := sprintf("Bucket %q has block_public_acls=false", [rc.address])
}
```

## Run Tasks

- A Run Task is a webhook URL called by HCP during plan.
- The webhook responds with pass/fail + a message URL.
- Used to integrate Checkov, tfsec, third-party compliance scanners.
- Created in Settings → Integrations → Run Tasks → fill URL + HMAC key.

## Exercises

1. Create a policy set in your HCP org. Upload `policies/limit-instance-size.sentinel` (see folder) with `soft-mandatory` enforcement.
2. In a workspace, author a `aws_instance` with `m5.large` — confirm plan is blocked.
3. Change to `t3.medium` — plan passes.
4. Repeat with the OPA example, uploaded as an alternative policy set.
5. (Optional) Configure a Run Task pointing at a public Checkov webhook and observe the pre-apply scan.

## Self-check

1. Three Sentinel policies attached (1 advisory, 1 soft-mandatory, 1 hard-mandatory) — which one's failure stops the run and which can be overridden by whom?
2. Where in a run does policy evaluation happen — before or after cost estimation?
3. Sentinel policy accidentally references `tfplan/v1` — still works? What changed between v1 and v2?
4. What's the single biggest advantage of Run Tasks over Sentinel/OPA?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Run phases with policies
- Enforcement levels
- Example Sentinel — block big instances
- Example OPA (Rego) — deny public S3

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
