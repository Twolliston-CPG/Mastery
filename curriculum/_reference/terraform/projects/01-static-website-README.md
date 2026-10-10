# Project 1: Static Website on AWS

Deploy a production-ready static website with S3, CloudFront, and Route 53.

## Architecture

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Architecture — diagram](../../../../_figures/curriculum-_reference-terraform-projects-01-static-website-README-0-b032845f.png)

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
  R53["Route 53<br/><i>alias record → the distribution</i>"]
  CF["CloudFront<br/><i>TLS termination · caching at the edge<br/>Origin Access Control</i>"]
  S3[("S3 bucket<br/><i>origin — <b>not</b> public;<br/>reachable only through CloudFront</i>")]
  R53 ==> CF ==> S3
  class R53 n
  class CF crit
  class S3 data
  linkStyle 0,1 stroke:#2f6fb8,stroke-width:2px

%% The bucket stays private. Origin Access Control lets the distribution read it
%% while `aws s3 ls s3://bucket` from the internet gets AccessDenied -- which is
%% the difference between a static site and a public file server.
```

</details>

## Features

- S3 bucket with website hosting
- CloudFront distribution with HTTPS
- ACM certificate for custom domain
- Route 53 DNS records
- Origin Access Identity (OAI)
- Custom error pages

## Files

- `main.tf` - Core infrastructure
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `cloudfront.tf` - CDN configuration
- `dns.tf` - Route 53 records

## Usage

```bash
terraform init
terraform plan -var="domain_name=example.com"
terraform apply
```

## Difficulty: Beginner
## Estimated Time: 2-3 hours

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Difficulty: Beginner
- Estimated Time: 2-3 hours

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
