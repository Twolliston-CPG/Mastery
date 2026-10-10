# Elite Challenge 3: Complete GitOps Pipeline

## Objective

Implement a production-grade GitOps workflow for infrastructure management with complete automation.

## Architecture

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Architecture — diagram](../../../../_figures/curriculum-_reference-terraform-challenges-challenge-03-gitops-pipeline-0-b4a6f497.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart LR
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  REPO["GitHub repo<br/><i>the only place state is declared</i>"]
  GHA["GitHub Actions<br/><i>OIDC — no static keys</i>"]
  TFC["HCP Terraform<br/><i>remote runs, remote state</i>"]
  AWS["AWS infrastructure"]
  SCAN["Security scans<br/><i>tfsec · checkov · secret scan</i>"]
  POL["Policy checks<br/><i>Sentinel / OPA on the plan</i>"]
  DRIFT["Drift detection<br/><i>scheduled plan, alert on non-empty</i>"]
  REPO ==> GHA ==> TFC ==> AWS
  GHA --> SCAN
  TFC --> POL
  AWS --> DRIFT
  class REPO,GHA,TFC n
  class AWS crit
  class SCAN,POL data
  class DRIFT mut
  linkStyle 0,1,2 stroke:#2f6fb8,stroke-width:2px
```

</details>

**The development flow those stages sit on**

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Architecture — diagram](../../../../_figures/curriculum-_reference-terraform-challenges-challenge-03-gitops-pipeline-1-0a342967.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart LR
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  F["Feature branch"]
  PR["Pull request"]
  REV["Review"]
  MRG["Merge to main"]
  DEV["Deploy to dev<br/><i>automatic</i>"]
  PROM["Promote<br/><i>staging, then production</i>"]
  PLAN["<code>terraform plan</code><br/><i>posted as a PR comment —<br/>the review reviews the plan, not the code</i>"]
  APPLY["<code>terraform apply</code><br/><i>automatic on main</i>"]
  F ==> PR ==> REV ==> MRG ==> DEV ==> PROM
  PR --> PLAN
  MRG --> APPLY
  class F,PR,REV,MRG,DEV n
  class PROM crit
  class PLAN data
  class APPLY crit
  linkStyle 0,1,2,3,4 stroke:#2f6fb8,stroke-width:2px
```

</details>

The detail that makes this GitOps rather than "CI that runs Terraform": the plan is attached to the
pull request, so the artifact a human approves is the **set of changes AWS will actually receive** —
not a diff of HCL that someone has to simulate in their head.

## Requirements

### Repository Structure
**`infrastructure/`**

- `.github/`
  - `workflows/`
    - `terraform-plan.yml`
    - `terraform-apply.yml`
    - `drift-detection.yml`
    - `security-scan.yml`
- `environments/`
  - `dev/`
  - `staging/`
  - `prod/`
- `modules/`
- `policies/`
  - `sentinel/`
  - `opa/`
- `tests/`


### Pipeline Features

1. **PR Workflow**
   - Automatic format check
   - Validation
   - Security scanning (tfsec, checkov)
   - Cost estimation (Infracost)
   - Plan output as PR comment
   - Required approvals

2. **Apply Workflow**
   - Triggered on merge to main
   - Environment-specific apply
   - Approval gates for prod
   - Slack/Teams notifications
   - State backup

3. **Drift Detection**
   - Scheduled runs (every 6 hours)
   - Alert on drift
   - Auto-create PR for remediation
   - Dashboard reporting

4. **Security Integration**
   - SAST scanning
   - Secret detection
   - Compliance checks
   - SBOM generation

### Terraform Cloud Integration
- Workspaces per environment
- VCS-driven workflow
- Policy sets (Sentinel)
- Cost estimation
- Private registry

### Monitoring & Observability
- Pipeline metrics
- Deployment tracking
- Rollback capabilities
- Audit logging

## Deliverables

### GitHub Actions Workflows

```yaml
# Example: terraform-plan.yml
name: Terraform Plan
on:
  pull_request:
    branches: [main]
    paths: ['environments/**', 'modules/**']

jobs:
  plan:
    strategy:
      matrix:
        environment: [dev, staging, prod]
    # ... implementation
```

### Required Components
1. Complete CI/CD workflows
2. Security scanning integration
3. Cost estimation
4. Drift detection
5. Notification system
6. Documentation

## Acceptance Criteria

- [ ] All workflows automated
- [ ] Security scans passing
- [ ] Cost estimation on PRs
- [ ] Drift detection operational
- [ ] Notifications configured
- [ ] Multi-environment support
- [ ] Rollback capability
- [ ] Complete documentation

## Bonus Challenges

- Add DORA metrics tracking
- Implement feature flags for infra
- Add chaos engineering tests
- Implement progressive rollouts

## Estimated Time: 6-8 hours

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Estimated Time: 6-8 hours
- Repository Structure
- Pipeline Features
- Terraform Cloud Integration

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
