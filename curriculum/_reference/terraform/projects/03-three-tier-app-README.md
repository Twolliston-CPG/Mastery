# Project 3: Three-Tier Web Application

Deploy a production-ready three-tier architecture with ALB, Auto Scaling, and RDS.

## Architecture

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Architecture — diagram](../../../../_figures/curriculum-_reference-terraform-projects-03-three-tier-app-README-0-73dbfefe.png)

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
  subgraph VPC["VPC &nbsp;·&nbsp; 10.0.0.0/16"]
    direction TB
    subgraph PUB["Public subnets"]
      direction LR
      NAT1["NAT gateway<br/><i>AZ-1</i>"]
      ALB["Application Load Balancer<br/><i>the only thing with a public address</i>"]
      NAT2["NAT gateway<br/><i>AZ-2</i>"]
    end
    subgraph APP["Private subnets &nbsp;·&nbsp; application tier"]
      direction LR
      E1["EC2 — Auto Scaling group<br/><i>AZ-1</i>"]
      E2["EC2 — Auto Scaling group<br/><i>AZ-2</i>"]
    end
    subgraph DATA["Private subnets &nbsp;·&nbsp; data tier"]
      direction LR
      PRI[("RDS PostgreSQL primary<br/><i>AZ-1</i>")]
      STB[("Standby<br/><i>AZ-2 — synchronous</i>")]
      PRI <-->|"Multi-AZ replication"| STB
    end
    ALB ==> E1
    ALB ==> E2
    E1 ==> PRI
    E2 ==> PRI
    E1 -.->|"outbound only"| NAT1
    E2 -.->|"outbound only"| NAT2
  end
  class ALB crit
  class NAT1,NAT2 mut
  class E1,E2 n
  class PRI crit
  class STB data
  linkStyle 1,2,3,4 stroke:#2f6fb8,stroke-width:2px

%% Two NAT gateways, one per AZ, is not redundancy theatre: a NAT gateway lives
%% in one subnet in one AZ. Share a single one across AZs and you have saved
%% ~$32/month and made an AZ failure take down outbound traffic for both tiers.
```

</details>

## Features

- VPC with public/private subnets across 2 AZs
- Application Load Balancer with HTTPS
- Auto Scaling Group with launch template
- RDS PostgreSQL with Multi-AZ
- Security groups with least privilege
- Secrets Manager for database credentials
- CloudWatch alarms and dashboards
- S3 bucket for logs

## Modules Used

- `modules/vpc` - Network infrastructure
- `modules/alb` - Load balancer
- `modules/asg` - Auto scaling group
- `modules/rds` - Database
- `modules/security` - Security groups

## Difficulty: Advanced
## Estimated Time: 6-8 hours

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Modules Used
- Difficulty: Advanced
- Estimated Time: 6-8 hours

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
