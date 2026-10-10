# Scenario 5 — Policy-Gated Change (HCP + Sentinel) (22 min)

## Requires

HCP Terraform + `TFE_TOKEN`. The organization must have the Team plan or higher to use Sentinel (the free tier allows *one* policy attached).

## The brief

Attach a Sentinel policy that **blocks any `aws_instance` whose `instance_type` starts with `m5.`**. Enforcement: `soft-mandatory`.

1. Declaratively create a policy set + policy via the `tfe` provider.
2. Attach the policy set to a workspace.
3. Submit a config with `m5.large` — speculative plan must fail on the policy.
4. Change to `t3.medium` — plan must pass.

## Starting point

```
scenario5-policy-gated/
├── README.md
```

Build from scratch, end state should include:
- `bootstrap/` — tfe provider config
- `bootstrap/policies/limit-instance-size.sentinel` — the policy
- `consumer/` — a workspace config that attempts to create an aws_instance

## Success criteria

- PR with `m5.large` fails the policy check (Sentinel error visible in the PR comment).
- PR with `t3.medium` passes the policy check.

## When done

Compare to `../../answers/solutions/scenario5/`.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Requires

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
