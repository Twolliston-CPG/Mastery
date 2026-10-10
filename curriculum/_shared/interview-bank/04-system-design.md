# Interview Bank: System Design

> At junior level you will not be asked to design a distributed database. You **will** be asked to
> design a pipeline, a landing zone, or a platform — and they are measuring **structure**, not
> brilliance.

## The method (use it every time)

```
1. CLARIFY   (3 min)  Scale? Users? Constraints? Compliance? What does "done" mean?
                      NEVER start drawing before this. Jumping straight to a diagram is the
                      most common failure in a design round.
2. REQUIREMENTS (2)   Functional (what it does) + non-functional (availability, latency,
                      security, cost). Write them where they can see.
3. HIGH LEVEL   (10)  Boxes and arrows. Happy path first, end to end.
4. DEEP DIVE    (15)  Let them pick, or pick the riskiest part yourself.
5. FAILURE      (5)   "What happens when X dies?" Ask it about your own design before they do.
6. TRADE-OFFS   (5)   What you chose, what you gave up, what you'd revisit at 10x scale.
```

**Narrate constantly.** Silence reads as being stuck. "I'm going to start with the request path and
come back to the data layer" is worth saying out loud.

---

## Design 1 — A CI/CD platform for 50 engineers

### Clarify first
How many services and repos? Monorepo or polyrepo? What languages? Deploy targets — Kubernetes,
serverless, VMs? Current deploy frequency and what they want. Compliance requirements — does someone
need to approve production? Existing tooling to keep?

**Assume for the answer:** 40 services, polyrepo, Python and Go, deploying to EKS, want to go from
weekly to daily, SOC 2 so production changes need an approval trail.

### Requirements
| Functional | Non-functional |
|---|---|
| Build, test, scan, deploy | PR feedback < 10 min (or people stop reading it) |
| Multi-environment promotion | Deploy < 15 min |
| Rollback | No long-lived cloud credentials |
| Audit trail for production | Audit trail for SOC 2 |

### High level
<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![High level — diagram](../../../_figures/curriculum-_shared-interview-bank-04-system-design-0-5f94f94b.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e

  PR["Pull request"]:::n

  subgraph PAR["PR stage · runs in PARALLEL · keeps feedback under 10 min"]
    direction LR
    T1["lint + unit tests"]:::n
    T2["SAST · Semgrep"]:::n
    T3["dependency scan · Trivy"]:::n
    T4["secret scan · gitleaks"]:::n
  end

  BUILD["build → scan → SBOM → cosign sign → push to ECR<br/><small>tagged by git SHA, never :latest</small>"]:::n
  MAIN(["merge to main"]):::crit
  GITOPS["GitOps repo<br/><small>bump the image digest in the staging overlay</small>"]:::data

  STG["ArgoCD syncs <b>staging</b>"]:::n
  SMOKE{"smoke tests"}:::n
  PROMO["automated promotion PR → prod overlay"]:::n
  APPROVE(["human approval<br/><small>the SOC 2 change-management gate</small>"]):::crit
  PROD["ArgoCD syncs <b>production</b><br/><small>progressive rollout watched against SLOs</small>"]:::crit

  PR --> T1 & T2 & T3 & T4
  T1 --> BUILD
  BUILD --> MAIN --> GITOPS --> STG --> SMOKE --> PROMO --> APPROVE --> PROD

  linkStyle 4,5,6,7,8,9,10,11 stroke:#2f6fb8,stroke-width:2px
```

</details>

### The decisions to defend```

### The decisions to defend
| Decision | Why | What you gave up |
|---|---|---|
| **Reusable workflows, not 40 copies** | One change updates every service's pipeline | Central team becomes a bottleneck for pipeline changes |
| **GitOps (pull) not push** | Git is the audit trail SOC 2 wants; cluster credentials never leave the cluster | Extra indirection; a second repo to reason about |
| **Tag by git SHA, never `latest`** | Immutable, traceable, rollback is a digest change | Slightly more verbose manifests |
| **OIDC for cloud auth** | No static keys to leak or rotate | Trust policies need care (see BF-37) |
| **Parallel checks in the PR stage** | Sub-10-minute feedback is the difference between a pipeline people use and one they route around | More concurrent runner minutes |

### Failure questions to raise yourself
- *Registry is down?* Deploys stop; running workloads are unaffected. Mitigate with pull-through cache.
- *ArgoCD is down?* Nothing new deploys, everything running keeps running — this is a real advantage
  of pull-based delivery over a push pipeline that's mid-deploy when it dies.
- *A bad image reaches production?* `kubectl rollout undo`, or revert the GitOps commit. Rollback
  should be one action, and you should have practiced it.
- *Someone needs an emergency deploy at 2am?* Break-glass path that skips approval but is **loud** —
  it pages and files a ticket automatically.

### Scale it
At 500 engineers: self-hosted runners for cost and speed, build caching, a monorepo-aware build
graph so you only build what changed, and merge queues to stop main breaking.

---

## Design 2 — A multi-account AWS landing zone

### Clarify
How many teams and environments? Compliance regime? Existing accounts to absorb? Network
connectivity to on-prem? Central or federated identity?

### High level
<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![High level — diagram](../../../_figures/curriculum-_shared-interview-bank-04-system-design-1-65510b72.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e

  MGMT["<b>Management account</b><br/><small>AWS Organizations · SCPs · consolidated billing</small>"]:::crit

  subgraph SEC["Security OU"]
    direction TB
    LOG["log-archive<br/><small>write-only · an attacker with prod admin<br/>still cannot delete the evidence</small>"]:::data
    TOOL["security-tooling<br/><small>GuardDuty · Security Hub · Config</small>"]:::n
  end

  subgraph INF["Infrastructure OU"]
    SHARED["shared-services<br/><small>Transit Gateway · shared ECR · CI runners · IPAM</small>"]:::n
  end

  subgraph WL["Workloads OU"]
    direction LR
    PRD["prod<br/><small>per team</small>"]:::n
    STG2["staging"]:::n
    DEV["dev"]:::n
  end

  subgraph SBX["Sandbox OU"]
    SAND["per-engineer<br/><small>SCP-capped spend · auto-nuke at 30 days</small>"]:::mut
  end

  MGMT -->|"SCPs deny, never grant"| SEC
  MGMT --> INF
  MGMT --> WL
  MGMT --> SBX
  WL -.->|"all logs, one direction"| LOG
  WL -.->|"TGW · non-overlapping CIDRs from IPAM"| SHARED

  linkStyle 0,1,2,3 stroke:#2f6fb8,stroke-width:2px
```

</details>

### The decisions to defend```

### The decisions to defend
| Decision | Why |
|---|---|
| **Account per environment per team** | The account is the real blast radius boundary in AWS. IAM is not. |
| **SCPs deny, never grant** | Guardrails that even an account admin can't override — deny leaving the org, deny disabling CloudTrail, deny unapproved regions |
| **Centralized logging to a locked log-archive account** | An attacker with prod admin still can't delete the evidence |
| **Transit Gateway over full-mesh peering** | Peering is non-transitive; at n accounts you need n² connections |
| **Identity Center (SSO) with permission sets** | No IAM users anywhere, no access keys, short-lived credentials by construction |
| **Non-overlapping CIDRs allocated centrally from an IPAM** | Overlapping CIDRs make peering and TGW impossible later — and re-CIDRing a live VPC is brutal |

**The CIDR point is the one that shows experience.** Everyone gets it wrong once and only once.

### Failure questions
- *Root credentials compromised in a workload account?* SCPs still constrain it; the security account
  detects it; the log archive is in a different account they can't reach.
- *Someone deletes the shared-services VPC?* `prevent_destroy`, plus the fact that infrastructure
  changes go through a pipeline with approval.

---

## Design 3 — A Kubernetes platform for 20 teams

### Clarify
Are teams trusted or is this hostile multi-tenancy? Compliance? Stateful workloads? Do teams have
Kubernetes expertise, or is the point to hide Kubernetes from them?

**The answer to that last one determines the whole design** — a platform for K8s-fluent teams and a
platform for application developers who shouldn't need to learn it are different products.

### High level
<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![High level — diagram](../../../_figures/curriculum-_shared-interview-bank-04-system-design-2-5f5630de.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e

  subgraph PATH["The paved road · a service.yaml generates all of it"]
    direction LR
    SVC["service.yaml"]:::crit
    GEN["namespace · RBAC · ArgoCD app<br/>pipeline · dashboard · SLO · runbook"]:::n
    SVC --> GEN
  end

  subgraph NONPROD["non-prod cluster"]
    direction TB
    NST["namespace per team<br/><small>ResourceQuota · LimitRange · default-deny NetworkPolicy</small>"]:::n
  end

  subgraph PRODC["prod cluster · separate blast radius and change control"]
    direction TB
    PST["namespace per team<br/><small>same guardrails, stricter policy</small>"]:::n
  end

  subgraph PLAT["Platform services · run once, consumed by all 20 teams"]
    direction LR
    P1["ingress-nginx · cert-manager"]:::mut
    P2["ArgoCD · Kyverno"]:::mut
    P3["kube-prometheus-stack · Loki"]:::mut
    P4["external-secrets · Falco"]:::mut
  end

  KARP["Karpenter<br/><small>spot in non-prod · on-demand baseline in prod</small>"]:::n

  GEN --> NST
  GEN --> PST
  NST -.-> PLAT
  PST -.-> PLAT
  NST -.-> KARP
  PST -.-> KARP

  linkStyle 0,1,2 stroke:#2f6fb8,stroke-width:2px
```

</details>

### The decisions to defend```

### The decisions to defend
| Decision | Why | Trade-off |
|---|---|---|
| **Namespace-per-team, not cluster-per-team** | Cluster sprawl is an operational tax paid forever; 20 clusters is 20 upgrade cycles | Weaker isolation; a noisy neighbor can still hurt via the node |
| **Separate prod cluster** | Different change control, different blast radius | Two of everything |
| **Quotas mandatory from day one** | Retrofitting quotas onto teams already running is politically impossible | Teams complain early — which is better than an outage later |
| **Observability generated, not opt-in** | A service with no dashboard is a liability | Platform team owns more surface |
| **Golden path, not a mandate** | Adoption you earn survives; adoption you mandate gets routed around | Must genuinely be the easiest path or nobody uses it |

### The question they'll actually ask
*"How do you stop one team taking down another?"*
> ResourceQuota caps aggregate consumption per namespace, LimitRange sets per-pod defaults so nobody
> ships an unbounded pod, NetworkPolicy default-deny means they can't even reach each other,
> PodDisruptionBudgets stop drains cascading, and priority classes make sure platform components
> survive eviction pressure. What none of that prevents is a node-level noisy neighbor — for genuinely
> hostile tenancy you need separate node pools or separate clusters, and that's a cost decision.

---

## Two rules for every design round

**Say the trade-off out loud.** "I'm choosing X, which costs more but gives us Y — if budget were the
binding constraint I'd go the other way." Interviewers are listening for whether you know there *is*
a trade-off. A design presented as having no downsides reads as inexperience.

**Ask the failure question before they do.** "What happens if the registry is unavailable?" asked by
you is worth far more than the same question asked by them.
