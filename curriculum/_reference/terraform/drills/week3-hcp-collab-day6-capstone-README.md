# Week 3 · Day 6 — Capstone: End-to-End HCP Setup

**Goal:** Stand up a production-shaped HCP Terraform environment from scratch — VCS-driven, OIDC-authed, policy-gated, registry-consumed.

## The brief

Build a two-workspace stack in HCP:

- `network-dev` → provisions VPC + subnets via a module from your **private registry**.
- `app-dev` → consumes `network-dev` outputs via `terraform_remote_state`, provisions EC2 + EIP.

All workspaces:
- VCS-driven, connected to a GitHub repo.
- Use **dynamic credentials (OIDC)** to AWS — no static keys anywhere.
- Gated by a **soft-mandatory Sentinel policy** that blocks `m5.*` instance types.
- Share a **variable set** at the project level with `AWS_DEFAULT_REGION` and default tags.
- Apply to `app-dev` is **triggered automatically** when `network-dev` applies (run trigger).

## Setup checklist

- [ ] HCP organization created.
- [ ] Project `tfpro-capstone` created.
- [ ] Variable set `aws-defaults` attached to the project.
- [ ] OIDC IAM provider + role created in AWS (reuse Day 3's bootstrap).
- [ ] Private module `terraform-aws-minivpc` published to the registry.
- [ ] GitHub repo with `network-dev/` and `app-dev/` subdirectories.
- [ ] Both workspaces created in HCP, each pointing at the right subdirectory.
- [ ] Run trigger: `app-dev` reruns on `network-dev` apply.
- [ ] State sharing from `network-dev` → `app-dev` enabled.
- [ ] Sentinel policy set attached with `soft-mandatory`.
- [ ] First PR opened in GitHub triggers a **speculative plan** with the policy check visible.

## Rubric (self-score out of 30)

| Area | Pts |
|---|---|
| Both workspaces VCS-driven + running cleanly | 5 |
| OIDC verified — no `AWS_ACCESS_KEY_ID` anywhere | 5 |
| Variable set shared across workspaces | 3 |
| Private registry module consumed by `network-dev` | 4 |
| `terraform_remote_state` wire-up between workspaces | 4 |
| Run trigger chains `network-dev` → `app-dev` | 3 |
| Sentinel policy attached, verified blocking | 4 |
| Speculative plan on PR visible | 2 |

## The "prove it" test

Final check — perform this and it MUST work:

1. Open a PR that adds an `m5.large` to `app-dev`. Observe the speculative plan fail on the Sentinel policy.
2. Fix it to `t3.medium`. Merge. Watch `app-dev` apply succeed.
3. Change `network-dev`'s CIDR. Watch `network-dev` apply → `app-dev` run triggers automatically.
4. Rotate: destroy both workspaces in the correct order (`app-dev` first, then `network-dev`). Verify everything is gone from AWS.

If all four steps work without you touching the UI mid-flight, you have mastered Domain 6.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Setup checklist
- Rubric (self-score out of 30)
- The "prove it" test

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
