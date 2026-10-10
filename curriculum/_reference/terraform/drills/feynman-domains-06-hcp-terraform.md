# Domain 6 — HCP Terraform (the Teacher's Voice)

---

## 1. Organizations / projects / workspaces

- **Organization** — billing, SSO, membership boundary.
- **Project** — grouping of workspaces with shared RBAC & variable sets.
- **Workspace** — one Terraform config + one state + run history + its own vars.

**Analogy:** Org = company. Project = team. Workspace = a single repo/env.

**Gotcha:** Variable sets attach to orgs, projects, or specific workspaces — precedence matters (see #4).

**Lab:** `week3/day1-hcp-fundamentals`

---

## 2. Three run modes + speculative plans

| Mode | Triggered by | Can apply? |
|---|---|---|
| CLI-driven | `terraform apply` locally | Yes |
| VCS-driven | git push / PR to tracked branch | Yes (on merge) |
| API-driven | POST `/runs` | Configurable |

**Speculative plan** — fires on PR, shows what *would* change, cannot apply. It's a preview.

**Analogy:** Speculative plan is the "review changes" screen before checkout — shows your cart, no payment.

**Gotcha:** Speculative plans consume run-count. On free tiers they can throttle real runs if the team PRs heavily.

**Self-test:** PR is open and shows a plan; merge happens. What fires next?

**Lab:** `week3/day2-run-workflows`

---

## 3. Variable sets + precedence

**From lowest to highest:**
1. Variable set default
2. Workspace variable
3. `.auto.tfvars` file in the repo
4. CLI `-var` / `-var-file`

**Analogy:** Layered water — later pours displace earlier ones for the same key.

**Gotcha:** Variable sets can be marked **"priority"**, which flips them to the *top*, overriding workspace vars. Org admins use this to force values (region, tags) teams can't override.

**Self-test:** A workspace sets `environment = "prod"`. A priority variable set on the org sets `environment = "stg"`. What's the value at run time?

**Lab:** `week3/day3-varsets-oidc`

---

## 4. OIDC dynamic AWS creds

Instead of long-lived AWS keys in HCP:

```
TFC_AWS_PROVIDER_AUTH=true
TFC_AWS_RUN_ROLE_ARN=arn:aws:iam::111:role/hcp-prod
# optional phase-specific:
TFC_AWS_PLAN_ROLE_ARN=...
TFC_AWS_APPLY_ROLE_ARN=...
```

HCP exchanges a signed JWT (OIDC) for STS credentials at run time. The provider block then needs nothing extra — auth is injected.

**Analogy:** Your workspace's JWT is a student ID; AWS STS is the library letting you check out a book because it trusts the school's issuer.

**Gotcha:** AWS side needs an IAM Identity Provider (OIDC) for `app.terraform.io` and a role trust policy matching your org/workspace/project. Plan-phase and apply-phase can use different roles — least privilege for plan.

**Self-test:** Plan works, apply fails with "not authorized to perform iam:CreateRole." Which role ARN env var is likely wrong?

---

## 5. Private registry + no-code modules

- **Private registry** — HCP-hosted, same `source = "app.terraform.io/org/name/provider"` shape as public.
- **No-code module** — a registry module users can provision via the HCP UI without writing any Terraform. Click → new workspace spun up from the module.

**Gotcha:** No-code modules require all variables to have defaults (or be set via variable sets); users don't have a place to write `.tfvars`.

**Self-test:** An ops team wants devs to spin up ephemeral RDS instances without writing HCL. Which HCP feature?

**Lab:** `week3/day4-private-registry`

---

## 6. Sentinel + OPA — policy as code

**Sentinel levels:**
- `advisory` — warn, always passes.
- `soft-mandatory` — blocks, org admins can override.
- `hard-mandatory` — blocks, nobody overrides.

**When policies run:** after plan, after cost estimation, **before apply approval**.

```python
# sentinel example
import "tfplan/v2" as tfplan

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is "aws_instance" implies rc.change.after.instance_type in ["t3.micro", "t3.small"]
  }
}
```

**OPA** is the non-HashiCorp alternative; same lifecycle slot.

**Analogy:** Three levels of gate — sign warning, locked gate with a key for managers, locked gate no key.

**Gotcha:** Policies are evaluated against the plan output, not your HCL. Computed attributes appear as unknowns — write rules against `change.after_unknown` carefully.

**Self-test:** You want "no one, not even admins, can launch a GPU instance." Which level?

**Lab:** `week3/day5-sentinel-opa`

---

## 7. Run tasks + agents

**Run task** — a webhook called during plan or pre-apply. HCP POSTs the plan URL to your endpoint; you respond pass/fail. Common uses: Checkov, tfsec, cost anomaly detection.

**Agent** — a long-running worker you deploy on your network. HCP queues runs to the agent pool when workspaces are configured with `execution_mode = "agent"`. Needed when HCP can't reach your resources directly (private VPC, on-prem).

**Self-test:** Your VPC has no public endpoints. AWS provider calls fail with timeouts from HCP. Which feature?

---

## 8. State sharing + run triggers

- **State sharing** — allowlist which workspaces can read this one's outputs via `terraform_remote_state`.
- **Run triggers** — workspace B auto-plans when workspace A applies. Configured on the *downstream* workspace (B), pointing at sources (A).

**Analogy:** State sharing = publishing your phone number to a list of friends. Run triggers = a doorbell that rings next door when yours does.

**Self-test:** Prod-network applies → prod-app should replan. Where do you configure the trigger, and what's the source?

**Lab:** `week3/day6-capstone`

---

## Flashcards

Domain 6 in `/FLASHCARDS.md` — 10 cards.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Organizations / projects / workspaces
- Three run modes + speculative plans
- Variable sets + precedence
- OIDC dynamic AWS creds

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
