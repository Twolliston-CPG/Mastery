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
