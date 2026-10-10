# Capstone Project: GitOps Platform Architecture

## Overview

This capstone project builds a production-ready multi-team GitOps platform using Argo CD.

## Architecture Diagram

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Architecture Diagram — diagram](../../../../_figures/curriculum-_reference-cicd-gitops-argocd-capstone-docs-architecture-0-b476a6da.png)

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
  subgraph PLAT["GitOps platform &nbsp;—&nbsp; management cluster"]
    direction TB
    subgraph ARGO["Argo CD"]
      direction LR
      API["API server<br/><i>3 replicas</i>"]
      REPO["Repo server<br/><i>2 replicas</i>"]
      CTRL["Application controller<br/><i>sharded, 3 replicas</i>"]
      REDIS["Redis HA"]
      CTRL --- REDIS
    end
    subgraph PROJ["Projects and RBAC"]
      direction LR
      PF["team-frontend<br/><i>frontend-* · Deployments · Services</i>"]
      PB["team-backend<br/><i>backend-* · StatefulSets · PVCs</i>"]
      PD["team-data<br/><i>data-* · Jobs and CronJobs · sync windows</i>"]
    end
    subgraph APPS["ApplicationSets"]
      direction TB
      A1["Team ApplicationSet — Git directory generator<br/><i>auto-discovers apps in team directories ·<br/>one Application per dev/staging/prod overlay</i>"]
      A2["PR preview ApplicationSet — pull request generator<br/><i>a preview environment per labelled PR ·<br/>destroyed when the PR closes</i>"]
    end
    subgraph OBS["Observability"]
      direction LR
      PR["Prometheus"]
      GR["Grafana"]
      NO["Notifications<br/><i>Slack · PagerDuty</i>"]
    end
    ARGO ==> PROJ ==> APPS
    APPS -.-> OBS
  end
  subgraph NS["Target namespaces"]
    direction LR
    NF["frontend-dev / stg / <b>prod</b>"]
    NB["backend-dev / stg / <b>prod</b>"]
    ND["data-dev / stg / <b>prod</b>"]
  end
  PREV["Preview environments<br/><code>preview-pr-123 · preview-pr-456 · preview-pr-789</code>"]
  PLAT ==>|"deploys to"| NS
  A2 -.-> PREV
  class API,REPO n
  class CTRL crit
  class REDIS data
  class PF,PB,PD n
  class A1 crit
  class A2 crit
  class PR,GR n
  class NO mut
  class NF,NB,ND data
  class PREV mut
  linkStyle 1,2,5 stroke:#2f6fb8,stroke-width:2px

%% The PR-preview generator is the one with an operational cost nobody budgets
%% for. Auto-cleanup on close is not a nicety -- without it, a month of open
%% pull requests is a month of running namespaces nobody is looking at.
```

</details>

## Components

### 1. Argo CD HA Installation
- 3 API server replicas for zero-downtime
- 2 repo server replicas for manifest generation
- 3 application controller replicas with sharding
- Redis HA with Sentinel

### 2. Projects (Multi-Tenancy)
- **team-frontend**: Web applications, UI services
- **team-backend**: APIs, databases, services
- **team-data**: Analytics, pipelines (with sync windows)

### 3. ApplicationSets
- Git Directory Generator for automatic app discovery
- Pull Request Generator for preview environments
- Progressive sync for controlled rollouts

### 4. Observability
- Prometheus metrics collection
- Custom alerting rules
- Slack/webhook notifications

### 5. Security
- RBAC policies per team
- Repository credential templates
- Project-level restrictions

## Directory Structure

**`capstone/`**

- `platform/`
  - `argocd/` — HA Argo CD installation
  - `monitoring/` — Prometheus, Grafana
  - `bootstrap/` — Cluster bootstrap app
- `projects/` — AppProject definitions
- `applicationsets/` — ApplicationSet definitions
- `apps/`
  - `frontend/`
    - `base/`
    - overlays/{dev,staging,prod}/
  - `backend/`
    - `base/`
    - overlays/{dev,staging,prod}/
  - `data/`
    - `base/`
    - overlays/{dev,staging,prod}/
- `docs/`
  - `architecture.md`
  - `onboarding.md`
  - `runbook.md`


## Success Criteria

1. **HA Verification**: Kill an argocd-server pod, verify zero downtime
2. **Isolation**: Team A cannot deploy to Team B's namespace
3. **Auto-sync**: Push change, watch automatic deployment
4. **Alerting**: Cause sync failure, receive notification
5. **Progressive Sync**: Changes deploy dev → staging → prod

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Components
- Argo CD HA Installation
- Projects (Multi-Tenancy)
- ApplicationSets

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The pipeline deploys the application."* |
| ✓ | *"CI writes a new image tag into a config repository and stops. A controller running *inside* the cluster polls that repo, diffs the rendered manifests against live state, and applies the difference — so nothing outside the cluster ever holds credentials to it."* |

**Trace it:** `git push` → the new version serving traffic, with nothing else typed. Name where the handoff between CI and CD happens, and what that handoff physically is.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the four [OpenGitOps principles](https://opengitops.dev/#principles) — then say which one a `kubectl apply` inside CI violates.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#cicd-gitops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
