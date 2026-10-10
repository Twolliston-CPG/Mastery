# Phase 1: Foundations (Weeks 1-2)

## Overview

Phase 1 lays the groundwork for every service and architectural pattern you will encounter on the AWS Solutions Architect Associate (SAA-C03) exam. You will build a mental model of the AWS cloud, understand how identity and networking underpin every workload, and gain hands-on experience deploying infrastructure with the AWS CLI, Python/Boto3, and Terraform.

By the end of these two weeks you should be able to sketch a secure, multi-tier VPC architecture on a whiteboard, explain IAM policy evaluation to a colleague, and confidently answer exam questions on networking, DNS, and load balancing.

---

## Estimated Time

| Activity | Hours |
|---|---|
| Reading and note-taking | 10-12 |
| Hands-on labs | 8-10 |
| Capstone project | 4-6 |
| Practice questions and review | 3-4 |
| **Total** | **25-32** |

Suggested pace: ~2-3 hours per day over 14 days.

---

## Prerequisites

- **AWS Account** -- Free Tier eligible account created and root user secured with MFA.
- **AWS CLI v2** installed and configured with a named profile (`aws configure --profile saa-study`).
- **Python 3.10+** with `boto3` installed (`pip install boto3`).
- **Terraform >= 1.5** installed (used in Lab 02 and the capstone project).
- **Basic command-line comfort** -- navigating directories, running scripts, reading JSON output.
- **No prior AWS experience required** -- this phase starts from zero.

---

## Learning Objectives

By completing Phase 1 you will be able to:

1. Describe the AWS Global Infrastructure (Regions, Availability Zones, Edge Locations) and explain why it matters for availability and latency.
2. Summarize all six pillars of the AWS Well-Architected Framework and identify which pillar a given design decision falls under.
3. Articulate the Shared Responsibility Model and distinguish what AWS manages versus what the customer manages.
4. Create and manage IAM users, groups, roles, and policies -- and explain how policy evaluation logic works.
5. Design a multi-tier VPC with public and private subnets across multiple AZs, including route tables, Internet Gateway, and NAT Gateway.
6. Compare and contrast Security Groups and Network ACLs and choose the right tool for a given scenario.
7. Configure Route 53 hosted zones, record types, and routing policies.
8. Select the correct Elastic Load Balancer type (ALB, NLB, GLB) for a given use case and configure health checks and target groups.
9. Use the AWS CLI, Boto3, and Terraform to provision and manage foundational AWS resources.

---

## What You Will Build

### Labs
| Lab | Description | Estimated Cost |
|---|---|---|
| Lab 01 -- IAM Policies | Create users, groups, roles, and custom JSON policies | Free |
| Lab 02 -- Build a VPC | Multi-tier VPC with public/private subnets, IGW, NAT GW | ~$1-3 (NAT GW hourly) |
| Lab 03 -- Route 53 + ELB | Hosted zone, health checks, ALB with target groups | ~$2-5 (ALB + hosted zone) |

### Capstone Project
| Project | Description | Estimated Cost |
|---|---|---|
| Multi-Tier VPC Architecture | Production-ready VPC with bastion host, ALB, private EC2 instances, NAT GW, VPC Flow Logs | ~$3-7 (tear down promptly) |

**Total Phase 1 estimated spend: $6-15** (well within the $20-50 total budget across all phases).

> **Cost tip:** Always tear down resources immediately after each lab. Use `terraform destroy` or the cleanup scripts provided. Set a billing alarm at $10.

---

## Content Map

### Notes (read in order)
1. `notes/01-cloud-fundamentals.md` -- AWS Global Infrastructure, Well-Architected Framework, Shared Responsibility Model
2. `notes/02-iam-deep-dive.md` -- Users, Groups, Roles, Policies, STS, Organizations, SCPs
3. `notes/03-vpc-networking.md` -- VPC design, subnets, routing, gateways, security layers, peering, endpoints
4. `notes/04-route53-dns.md` -- DNS concepts, record types, routing policies, failover
5. `notes/05-elastic-load-balancing.md` -- ALB, NLB, GLB, cross-zone LB, sticky sessions

### Labs (do after reading the corresponding notes)
1. `labs/lab-01-iam-policies.md` -- after notes 01-02
2. `labs/lab-02-build-a-vpc.md` -- after note 03
3. `labs/lab-03-route53-elb.md` -- after notes 04-05

### Capstone Project (do after all labs)
1. `projects/project-01-multi-tier-vpc-architecture.md`

### Review
- `practice-questions/questions.md` -- 20 exam-style questions
- `cheat-sheets/iam-cheat-sheet.md`
- `cheat-sheets/vpc-networking-cheat-sheet.md`
- `cheat-sheets/route53-elb-cheat-sheet.md`

---

## Suggested Weekly Schedule

### Week 1 -- Identity and Networking Foundations
| Day | Activity |
|---|---|
| Day 1 | Read notes 01 (Cloud Fundamentals) |
| Day 2 | Read notes 02 (IAM Deep Dive) |
| Day 3 | Complete Lab 01 (IAM Policies) |
| Day 4 | Read notes 03 (VPC Networking) |
| Day 5 | Complete Lab 02 (Build a VPC) -- **tear down NAT GW when done** |
| Day 6 | Review cheat sheets for IAM and VPC; do practice questions 1-10 |
| Day 7 | Rest or catch up |

### Week 2 -- DNS, Load Balancing, and Capstone
| Day | Activity |
|---|---|
| Day 8 | Read notes 04 (Route 53 / DNS) |
| Day 9 | Read notes 05 (Elastic Load Balancing) |
| Day 10 | Complete Lab 03 (Route 53 + ELB) -- **tear down when done** |
| Day 11-12 | Capstone Project -- **tear down all resources when done** |
| Day 13 | Review all cheat sheets; do practice questions 11-20 |
| Day 14 | Review missed questions; revisit weak areas; prep for Phase 2 |

---

## Tips for Success

- **Hands-on first:** Reading is important, but muscle memory from the CLI and Boto3 is what makes concepts stick.
- **Tear down everything:** Set a phone alarm for 2 hours after starting any lab. If you are done, destroy resources. If not, evaluate whether you need more time or should pause and resume tomorrow.
- **Use the Free Tier:** IAM is always free. VPC components (subnets, route tables, SGs, NACLs) are free. You only pay for NAT Gateways, ALBs, hosted zones, and EC2 instances.
- **Take notes in your own words:** The skeleton notes provided here are a starting framework. Add your own observations, "aha" moments, and exam tips as you go.
- **Explain it out loud:** If you can explain VPC routing or IAM policy evaluation to an imaginary colleague, you know it well enough for the exam.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Content Map
- Suggested Weekly Schedule
- Capstone Project
- Notes (read in order)

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The security group allows the traffic."* |
| ✓ | *"A security group is a stateful allow-list attached to an ENI. Traffic matching an inbound rule is permitted and the reply is permitted automatically, because the connection is tracked — which is why you never write an outbound rule for a reply."* |

**Trace it:** A request from the internet to an instance in a private subnet. Name every hop, every route-table lookup, and every rule evaluated, in order.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — 15 minutes from the AWS Builders' Library, and it changes how you write every client you touch afterwards.
Full list per domain: [`SOURCES.md`](../SOURCES.md#aws)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
