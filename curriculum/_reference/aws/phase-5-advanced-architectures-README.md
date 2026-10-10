# Phase 5: Advanced Architectures (Weeks 9-10)

## Overview

Phase 5 is the capstone learning phase where you tie together everything from Phases 1 through 4 into real-world, multi-service architectures. You will learn how organizations migrate to AWS, design for disaster recovery, distribute content globally, build serverless and container-based systems, and construct data analytics pipelines. This phase directly maps to the SAA-C03 exam's emphasis on designing resilient, high-performing, and cost-optimized architectures.

By the end of these two weeks you should be able to design a multi-region active-passive architecture from scratch, select the correct DR strategy based on RPO/RTO requirements, explain when to use CloudFront versus Global Accelerator, and architect complete serverless or container-based platforms on a whiteboard.

---

## Estimated Time

| Activity | Hours |
|---|---|
| Reading and note-taking | 12-15 |
| Hands-on labs | 10-14 |
| Projects | 10-14 |
| Practice questions and review | 4-6 |
| **Total** | **36-49** |

Suggested pace: ~3 hours per day over 14 days.

---

## Prerequisites

Before starting Phase 5, you should have completed:

- **Phase 1 -- Foundations:** IAM, VPC, Route 53, ELB. You will rely heavily on VPC design, Route 53 routing policies (especially failover), and load balancers.
- **Phase 2 -- Compute & Storage:** EC2, ASG, EBS, S3, EFS, Lambda, ECS/EKS. You will use all of these in multi-service architectures.
- **Phase 3 -- Databases & Integration:** RDS, Aurora, DynamoDB, SQS, SNS, EventBridge, Kinesis, API Gateway, Step Functions. These are the backbone of the patterns in this phase.
- **Phase 4 -- Security & Monitoring:** KMS, CloudWatch, CloudTrail, AWS Config, Cognito. Security and monitoring are woven into every architecture.

### Tools Required

- **AWS Account** with Free Tier eligibility (some labs will incur small costs).
- **AWS CLI v2** configured with a named profile.
- **Python 3.10+** with `boto3` installed.
- **Terraform >= 1.5** installed.
- **Billing alarm** set at $10 (some labs in this phase involve multi-region resources).

---

## Learning Objectives

By completing Phase 5 you will be able to:

1. Explain the 7 R's of cloud migration and select the correct strategy for a given scenario.
2. Describe the four DR strategies (Backup & Restore, Pilot Light, Warm Standby, Multi-Site Active/Active) and choose the right one based on RPO, RTO, and budget constraints.
3. Configure CloudFront distributions with S3 and ALB origins, OAC, cache behaviors, and signed URLs.
4. Compare CloudFront and Global Accelerator and select the correct service for a given scenario.
5. Design hybrid connectivity architectures using VPN, Direct Connect, Transit Gateway, and Direct Connect Gateway.
6. Architect serverless applications using API Gateway, Lambda, DynamoDB, S3, Step Functions, SQS, SNS, and EventBridge.
7. Choose between serverless, containers, and EC2 for a given workload.
8. Design data analytics pipelines using Kinesis, S3, Glue, Athena, and QuickSight.
9. Implement multi-region architectures with Aurora Global Database, S3 cross-region replication, and Route 53 failover.

---

## Services Covered

| Category | Services |
|---|---|
| Migration | Migration Hub, Application Discovery Service, DMS, SCT, MGN |
| Content Delivery | CloudFront, Global Accelerator |
| Hybrid & Edge | Direct Connect, Transit Gateway, VPN, Outposts, Wavelength, Local Zones |
| Serverless | API Gateway, Lambda, Step Functions, EventBridge, DynamoDB, Cognito |
| Containers | ECS, EKS, Fargate, ECR |
| Analytics | Kinesis, Glue, Athena, QuickSight, Lake Formation, EMR, OpenSearch |
| DR & Resilience | Route 53, Aurora Global DB, S3 CRR, ASG, AMI, RDS snapshots |

---

## What You Will Build

### Labs

| Lab | Description | Estimated Cost |
|---|---|---|
| Lab 01 -- CloudFront + S3 | Static website with CloudFront distribution, OAC, cache behavior | Free-$0.50 |
| Lab 02 -- Pilot Light DR | Multi-region DR simulation with RDS, EC2, Route 53 failover | $5-10 (few hours) |
| Lab 03 -- Serverless Full Stack | S3 + API Gateway + Lambda + DynamoDB + Cognito | Free (Free Tier) |
| Lab 04 -- Data Analytics | Kinesis Firehose -> S3 -> Glue Crawler -> Athena | $1-3 |
| Lab 05 -- Multi-Region S3 Replication | Cross-region replication with versioned objects | Free-$0.50 |

### Projects

| Project | Description | Estimated Cost |
|---|---|---|
| Project 01 -- Multi-Region Active-Passive | VPC + ALB + ASG + Aurora Global DB + Route 53 failover + CloudFront | $10-20 (tear down promptly) |
| Project 02 -- Serverless Event-Driven Platform | CloudFront + API Gateway + Lambda + DynamoDB + Cognito + SQS + SNS + Step Functions + EventBridge | $1-5 (mostly Free Tier) |
| Project 03 -- Data Lake Analytics | S3 zones + Kinesis Firehose + Glue + Athena + QuickSight | $3-8 |

**Total Phase 5 estimated spend: $20-47** (tear down all resources immediately after each lab/project).

> **Cost tip:** Multi-region resources (Aurora Global DB, RDS read replicas, NAT Gateways in secondary regions) accumulate cost quickly. Set a 3-hour timer when starting Project 01. Use `terraform destroy` to tear down everything.

---

## Content Map

### Notes (read in order)

1. `notes/01-migration-strategies.md` -- 7 R's, Migration Hub, DMS, Application Migration Service
2. `notes/02-disaster-recovery.md` -- DR strategies, RPO/RTO, cost trade-offs, AWS service mapping
3. `notes/03-cloudfront-cdn.md` -- Origins, OAC, cache behaviors, Signed URLs, CloudFront Functions vs Lambda@Edge
4. `notes/04-global-accelerator.md` -- Anycast IP, endpoint groups, Global Accelerator vs CloudFront
5. `notes/05-hybrid-connectivity.md` -- VPN + Direct Connect, Transit Gateway, Outposts, Wavelength, Local Zones
6. `notes/06-serverless-patterns.md` -- API Gateway + Lambda + DynamoDB, event-driven patterns, decision guide
7. `notes/07-container-patterns.md` -- ECS/EKS, Fargate vs EC2, service mesh, service discovery
8. `notes/08-data-analytics-pipeline.md` -- Kinesis, Glue, Athena, QuickSight, Lake Formation, EMR, OpenSearch

### Labs (do after reading the corresponding notes)

1. `labs/lab-01-cloudfront-s3.md` -- after notes 01-03
2. `labs/lab-02-dr-pilot-light.md` -- after note 02
3. `labs/lab-03-serverless-full-stack.md` -- after note 06
4. `labs/lab-04-data-analytics.md` -- after note 08
5. `labs/lab-05-multi-region-s3-replication.md` -- after note 02

### Projects (do after all labs)

1. `projects/project-01-multi-region-active-passive.md`
2. `projects/project-02-serverless-event-driven-platform.md`
3. `projects/project-03-data-lake-analytics.md`

### Review

- `practice-questions/questions.md` -- 25 exam-style questions
- `cheat-sheets/migration-dr-cheat-sheet.md`
- `cheat-sheets/architecture-patterns-cheat-sheet.md`

---

## Suggested Weekly Schedule

### Week 9 -- Migration, DR, and Content Delivery

| Day | Activity |
|---|---|
| Day 1 | Read notes 01 (Migration Strategies) and 02 (Disaster Recovery) |
| Day 2 | Read notes 03 (CloudFront) and 04 (Global Accelerator) |
| Day 3 | Complete Lab 01 (CloudFront + S3) -- tear down when done |
| Day 4 | Complete Lab 02 (Pilot Light DR) -- **tear down immediately, costs accumulate** |
| Day 5 | Complete Lab 05 (Multi-Region S3 Replication) -- tear down when done |
| Day 6 | Review migration/DR cheat sheet; do practice questions 1-10 |
| Day 7 | Rest or catch up |

### Week 10 -- Patterns, Analytics, and Capstone Projects

| Day | Activity |
|---|---|
| Day 8 | Read notes 05 (Hybrid Connectivity) and 06 (Serverless Patterns) |
| Day 9 | Read notes 07 (Container Patterns) and 08 (Data Analytics) |
| Day 10 | Complete Lab 03 (Serverless Full Stack) and Lab 04 (Data Analytics) |
| Day 11 | Project 01 (Multi-Region Active-Passive) -- **tear down when done** |
| Day 12 | Project 02 (Serverless Event-Driven) or Project 03 (Data Lake) |
| Day 13 | Review architecture patterns cheat sheet; do practice questions 11-25 |
| Day 14 | Review missed questions; revisit weak areas; prep for Phase 6 (practice exams) |

---

## Tips for Success

- **Think architecturally:** Phase 5 is about combining services. For every lab, draw the architecture on paper before starting. Label which service handles what.
- **Know the trade-offs:** The exam loves "which approach" questions. For every pattern, know the cost, complexity, RPO/RTO, and operational overhead trade-offs.
- **Tear down multi-region resources immediately:** Aurora Global DB, RDS read replicas, and NAT Gateways in secondary regions cost money every hour. Set a timer.
- **Practice the decision frameworks:** CloudFront vs Global Accelerator, serverless vs containers vs EC2, Kinesis vs SQS -- the cheat sheets have these. Quiz yourself.
- **Trace the data flow:** For every architecture, trace a request from the client through every service to the data store and back. If you can narrate the entire flow, you understand it.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Content Map
- Suggested Weekly Schedule
- Tools Required
- Projects

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
