# Scenario 4 — Cross-Workspace Data (HCP) (22 min)

## Requires

HCP Terraform account + `TFE_TOKEN` env var. If you don't have these, complete Week 3 Day 1 setup first.

## The brief

Create two HCP workspaces:

- **`net-mock`** outputs `vpc_id` and `subnet_ids`.
- **`app-mock`** consumes those outputs via `terraform_remote_state` and attaches a run trigger so it auto-reruns when `net-mock` applies.

## Requirements

- Both workspaces created declaratively via the `tfe` provider (not the UI).
- State sharing enabled `net-mock → app-mock`.
- Run trigger: `app-mock` reruns on `net-mock` apply.
- Proof: changing the VPC CIDR in `net-mock` causes a plan to appear in `app-mock`.

## Starting point

```
scenario4-cross-workspace/
├── README.md          # you're here
# everything else — YOU build it
```

## Success criteria

- `terraform apply` in `bootstrap/` creates both workspaces cleanly.
- A commit that changes `net-mock`'s VPC CIDR triggers an `app-mock` run without human intervention.

## When done

Compare to `../../answers/solutions/scenario4/`.

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
