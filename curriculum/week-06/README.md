# Week 6 — VPC and S3

> **Thesis:** the VPC is where week 2's subnetting and week 3's routing/NAT/firewall labs become
> AWS. If you did those properly, this week is recognition, not learning. Draw every architecture
> **before** you build it.

| | |
|---|---|
| **Hours** | 35–45 |
| **Deliverable** | A hand-drawn-then-cleaned VPC architecture diagram (becomes the Project Alpha diagram) |
| **Break/Fix** | BF-27 |
| **Exit check** | Build a 2-AZ VPC by hand and explain every routing decision |

## The week in one figure

**Figure 6.1 — A two-AZ VPC, and what makes a subnet public.** The week-2 subnetting and the week-3 router, NAT, and firewall, now as AWS resources. Follow the blue line from the internet to the data tier and notice where it stops. Badges are numbered in the order to walk them; the blue path is the one to follow first.

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart LR
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e

  NET["internet"]:::mut
  subgraph VPC["① VPC 10.20.0.0/16 · two AZs · three tiers · 75 % of the range left free"]
    direction TB
    IG["② internet gateway<br/><small>one per VPC · no bandwidth limit</small>"]:::crit
    subgraph PUB["③ public /24 per AZ · rtb → 0.0.0.0/0 via igw"]
      direction LR
      NAT["④ NAT gateway<br/><small>one per AZ in prod · billed per hour + per GB</small>"]:::crit
      BAS["⑤ bastion<br/><small>ssh -J · ProxyJump · SG allows your IP only</small>"]:::n
    end
    subgraph APP["⑥ app /20 per AZ · rtb → 0.0.0.0/0 via nat"]
      direction LR
      A["instances<br/><small>private IPs only</small>"]:::crit
    end
    subgraph DAT["⑦ data /24 per AZ · rtb has NO default route"]
      direction LR
      D["RDS<br/><small>reachable from app SG only</small>"]:::data
    end
    EP["⑧ S3 gateway endpoint<br/><small>free · a route-table entry · replaces the NAT path for S3</small>"]:::crit
    FL["⑨ Flow Logs<br/><small>ACCEPT and REJECT · find the rejected connection</small>"]:::data
  end
  SG["⑩ SG vs NACL<br/><small>stateful, allow-only, on the ENI · stateless, ordered, on the subnet</small>"]:::warn
  S3["⑪ S3<br/><small>bucket policy denies unencrypted uploads · presigned URL · lifecycle to IA and Glacier</small>"]:::data
  NET ==> IG ==> NAT ==> A
  A ==> EP ==> S3
  A --> D
  NET -.-> BAS -.-> A
  SG -.-> A
  A -.-> FL
  linkStyle 0,1,2,3,4 stroke:#2f6fb8,stroke-width:2px
```

**What to say, badge by badge** · about three and a half minutes at a normal pace. Point at each badge as you say its line.

- **Open.** “This is the diagram you draw by hand this week and clean up for Project Alpha. Three tiers, two availability zones, and one question that decides everything: what route table is a subnet attached to.”
- **① VPC.** “A /16 gives you 65,536 addresses. The tiers here use about a quarter of them, deliberately, so there is room to add tiers later without renumbering. Renumbering a VPC is a migration.”
- **② internet gateway.** “One per VPC, horizontally scaled, no bandwidth to size. Attaching it does nothing by itself. A route has to point at it.”
- **③ public subnets.** “What makes a subnet public is not a checkbox. It is a route table with 0.0.0.0/0 pointing at the internet gateway, plus an instance with a public IP. Say that sentence in an interview and you are ahead of most candidates.”
- **④ NAT gateway.** “Private instances reach the internet through NAT in a public subnet, exactly like the week-3 namespace lab. One per AZ in production, because a NAT in AZ-a does nothing for AZ-b when AZ-a is down. It bills per hour and per gigabyte.”
- **⑤ bastion.** “The only SSH door, in the public tier, security group open to your IP alone. `ssh -J bastion private-host` with ProxyJump in your SSH config, so the private key never leaves your laptop.”
- **⑥ app subnets.** “A /20 per AZ, 4,096 addresses, because this tier will hold pods one day and pods eat IPs. Default route to the NAT. No public IPs.”
- **⑦ data subnets.** “No default route at all. Not to NAT, not to anything. The database cannot initiate a connection to the internet, which means a compromised database cannot phone home.”
- **⑧ S3 gateway endpoint.** “A route-table entry that sends S3 traffic over AWS's network instead of through the NAT. It is free. The exit criterion asks you to replace the NAT for S3 and compare the bill.”
- **⑨ Flow Logs.** “Every accepted and rejected connection, per ENI. The lab asks you to find one rejected connection. In an incident, this is how you prove a security group is the cause.”
- **⑩ SG versus NACL.** “A security group is stateful, allow-only, and attached to the interface: the reply is allowed automatically. A NACL is stateless, ordered, allow and deny, on the subnet: you must allow the ephemeral reply ports yourself. This is the week-3 `ct state` rule, sold twice.”
- **⑪ S3.** “A bucket policy that denies any upload without server-side encryption. A presigned URL that grants one object for fifteen minutes. A lifecycle rule to Infrequent Access at 30 days and Glacier at 90. Numbers an exam asks for.”
- **Close.** “Route table decides public. NAT per AZ. Data tier with no way out. Endpoints instead of NAT where you can. And the diagram goes into the Alpha repo this Sunday.”

---

## Day plan
| Day | Focus | Lab |
|---|---|---|
| Mon | VPC: CIDR, subnets, IGW, route tables | Lab 1 |
| Tue | NAT, bastion, SG vs NACL | Lab 2 |
| Wed | VPC endpoints, Flow Logs | Lab 3 |
| Thu | S3: storage classes, lifecycle, versioning, policies | Lab 4 |
| Fri | S3 encryption + presigned URLs + Break/Fix | Lab 5 |
| Sat | SAA course: networking + storage domains; 40 practice questions | — |
| Sun | Review, diagram, plan week 7 | — |

## Reading map
- `_reference/aws/phase-1-foundations-notes-03-vpc-networking.md`
- `_reference/aws/phase-2-compute-storage-notes-07-s3-deep-dive.md`
- `_reference/aws/phase-2-compute-storage-notes-08-efs-fsx.md`
- **Cheat sheets:** `phase-1-foundations-cheat-sheets-vpc-networking-cheat-sheet.md`,
  `phase-2-compute-storage-cheat-sheets-storage-cheat-sheet.md`
- **Labs:** `phase-1-foundations-labs-lab-02-build-a-vpc.md`,
  `phase-2-compute-storage-labs-lab-04-s3-operations.md`
- **Project:** `phase-1-foundations-projects-project-01-multi-tier-vpc-architecture.md`

## Labs
[labs/LABS.md](labs/LABS.md) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md)

| # | Lab | Time | Cost |
|---|---|---|---|
| 1 | Build a VPC by hand | 3h | $0 |
| 2 | NAT, bastion, SG vs NACL | 3h | ~$2 (NAT GW) |
| 3 | VPC endpoints and Flow Logs | 2h | ~$1 |
| 4 | S3 deep dive | 3h | <$1 |
| 5 | S3 security + Break/Fix | 2h | <$1 |

> **The NAT gateway is the expensive thing this week.** Roughly $0.045/hour plus data processing.
> Create it, do Lab 2, **delete it the same day**. Do not leave one running over the weekend —
> that's ~$8 for nothing. Lab 3 shows you how to avoid needing it at all.

## Drills
- `_shared/drills/aws-comparisons.md` — Networking and Storage sections, daily
- `_shared/drills/subnetting.md` — 10/day. **This week is where it pays off.**

## Exit criteria
- [ ] Build a 2-AZ VPC from nothing in under 30 minutes
- [ ] Explain what makes a subnet "public" without saying "you check a box"
- [ ] Explain SG vs NACL and map both to week 3's iptables lab
- [ ] Reach a private instance through a bastion with `ProxyJump`
- [ ] Replace a NAT gateway with an S3 gateway endpoint and compare cost
- [ ] Find a rejected connection in Flow Logs
- [ ] Write a bucket policy denying unencrypted uploads
- [ ] Diagram complete, committed to your Alpha repo
