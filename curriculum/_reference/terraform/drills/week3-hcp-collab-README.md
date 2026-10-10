# Week 3 — Collaboration & HCP Terraform (Domains 3 & 6)

**Goal:** End-to-end fluency in HCP Terraform — workspaces, run workflows, variable sets, dynamic credentials, private registry, and policy as code. Domain 6 is the single biggest differentiator between the Associate and the Pro.

## Prerequisite

**Create an HCP Terraform account** at https://app.terraform.io/signup — free tier is enough for every exercise in this week. Also install the CLI login:

```bash
terraform login       # opens browser, issues a token saved to ~/.terraform.d/credentials.tfrc.json
```

## Daily schedule

| Day | Topic | Folder |
|---|---|---|
| 1 | HCP fundamentals — org, projects, workspaces, `cloud {}` block | `day1-hcp-fundamentals/` |
| 2 | The three run workflows — CLI-driven, VCS-driven, API-driven | `day2-run-workflows/` |
| 3 | Variable sets + dynamic provider credentials (OIDC to AWS) | `day3-varsets-oidc/` |
| 4 | Private module registry + no-code modules | `day4-private-registry/` |
| 5 | Policy as code — Sentinel + OPA, run tasks | `day5-sentinel-opa/` |
| 6 | Capstone — full HCP setup, VCS-driven, OIDC, Sentinel | `day6-capstone/` |

## End-of-week gate

- [ ] Configure a workspace with the `cloud {}` block and run `terraform apply` from CLI against HCP.
- [ ] Convert the same workspace to VCS-driven via GitHub and watch a plan trigger on push.
- [ ] Share a set of variables across 3+ workspaces with a Variable Set.
- [ ] Provision AWS resources from HCP with **no long-lived AWS keys** (dynamic credentials via OIDC).
- [ ] Publish a module to the private registry and consume it from another workspace.
- [ ] Write a Sentinel policy that blocks `aws_instance` types larger than `t3.medium`.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Prerequisite
- Daily schedule
- End-of-week gate

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
