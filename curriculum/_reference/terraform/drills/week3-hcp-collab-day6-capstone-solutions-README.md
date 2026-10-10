# Capstone Solution — End-to-End HCP Terraform Setup

**Look at this AFTER you've attempted the assignment.**

## Layout

```
hcp-bootstrap/         # Provisions the HCP org, project, workspaces, var sets,
                       #   policy sets, run triggers, state sharing — all via
                       #   the `tfe` provider (Terraform-manages-HCP pattern).
  policies/            #   Sentinel + Rego policies that get attached.
network-dev/           # The HCL that `network-dev` workspace runs (VCS-driven).
app-dev/               # The HCL that `app-dev` workspace runs (VCS-driven).
                       #   Consumes network-dev outputs via terraform_remote_state.
RUNBOOK.md             # Step-by-step bring-up instructions.
```

## Why this shape

The exam-favorite pattern: **one root module uses the `tfe` provider to configure HCP Terraform itself**. No UI clicking. Everything in version control, reproducible, reviewable.

The workspaces created by `hcp-bootstrap` are wired to consume `network-dev/` and `app-dev/` folders in a Git repo (replace the repo URL in `hcp-bootstrap/variables.tf` with yours).

## Why this requires prerequisites

1. **HCP Terraform account** — free tier is enough.
2. **An HCP user API token** exported as `TFE_TOKEN` (Profile → Tokens → Create).
3. **A GitHub repo** holding `network-dev/` and `app-dev/` folders, plus an OAuth token registered in HCP (Settings → VCS Providers → GitHub App).
4. **AWS account** with the OIDC IAM provider + role from Week 3 Day 3's `oidc-bootstrap/` already applied; export the role ARN.

See `RUNBOOK.md` for the exact commands.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Layout
- Why this shape
- Why this requires prerequisites

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
