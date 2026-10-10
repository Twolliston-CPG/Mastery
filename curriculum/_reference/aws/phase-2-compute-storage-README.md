# Phase 2: Compute & Storage (Weeks 3-4)

## Phase Overview

Phase 2 covers the core compute and storage services that form the backbone of most AWS architectures. You will learn to launch and manage EC2 instances, configure Auto Scaling for high availability, build serverless applications with Lambda, and master the full spectrum of AWS storage options from S3 to EFS to specialized services like Storage Gateway and Snow Family.

By the end of this phase, you will be able to design resilient, cost-optimized compute and storage architectures — a skill set that accounts for roughly 30-35% of SAA-C03 exam questions.

---

## Prerequisites

- **Phase 1 Complete**: You should have a working AWS account, understand IAM fundamentals, know how to use the AWS CLI and Boto3, and be comfortable with VPC/networking basics.
- **Tools Installed**: AWS CLI v2, Python 3.9+, Boto3, Terraform >= 1.5, an SSH client.
- **Budget**: A valid payment method on your AWS account. Most labs use Free Tier or cost under $1, but some compute labs may cost $2-5 if not torn down promptly.

---

## Learning Objectives

By completing Phase 2, you will be able to:

1. Launch and configure EC2 instances with appropriate instance types, storage, and networking.
2. Design Auto Scaling strategies using launch templates and multiple scaling policies.
3. Select the right EBS volume type based on IOPS, throughput, and cost requirements.
4. Deploy containerized workloads on ECS (EC2 and Fargate) and understand EKS basics.
5. Build event-driven serverless architectures with Lambda, API Gateway, and S3 triggers.
6. Choose the correct S3 storage class and configure lifecycle rules, versioning, replication, and encryption.
7. Differentiate between EFS, FSx variants, and EBS for shared/persistent storage use cases.
8. Recommend the right data migration service (Storage Gateway, Snow Family, DataSync, Transfer Family).
9. Answer SAA-C03 scenario questions involving compute and storage tradeoffs.

---

## Estimated Time

| Activity | Hours |
|---|---|
| Notes (reading & review) | 12-15 |
| Hands-on Labs (5 labs) | 8-10 |
| Projects (2 projects) | 6-8 |
| Practice Questions & Review | 3-4 |
| **Total** | **29-37 hours over 2 weeks** |

Suggested pace: ~2.5-3 hours per day across 14 days.

---

## Services Covered

### Compute
- Amazon EC2 (instance types, purchase options, placement groups, user data, metadata)
- EC2 Auto Scaling (launch templates, scaling policies, lifecycle hooks, warm pools)
- AWS Lambda (execution model, concurrency, layers, versions/aliases, Lambda@Edge)
- Amazon ECS & EKS (Fargate, task definitions, services, ECR)
- AWS Elastic Beanstalk (deployment policies, .ebextensions)

### Storage
- Amazon EBS (volume types, snapshots, encryption, Multi-Attach, RAID)
- Amazon S3 (storage classes, lifecycle rules, versioning, replication, encryption, Object Lock, Access Points)
- Amazon EFS (performance modes, throughput modes, storage classes)
- Amazon FSx (Windows File Server, Lustre, ONTAP, OpenZFS)
- AWS Storage Gateway (File, Volume, Tape)
- AWS Snow Family (Snowcone, Snowball Edge, Snowmobile)
- AWS DataSync & Transfer Family

---

## What You Will Build

### Labs
1. **EC2 Launch & Configure** — Launch an instance with user data, attach EBS, create snapshots (CLI + Boto3).
2. **Auto Scaling Group** — Create a launch template and ASG with target tracking scaling (CLI + Boto3).
3. **Lambda + API Gateway** — Build a serverless REST endpoint with Lambda and API Gateway (Python + CLI).
4. **S3 Operations** — Configure versioning, lifecycle rules, replication, encryption, presigned URLs, and event notifications (Boto3 + CLI).
5. **EFS Shared Storage** — Create an EFS file system and mount it across two EC2 instances (CLI + Boto3).

### Projects
1. **Auto-Scaling Web Application** — Deploy a web app on EC2 behind an ALB with an Auto Scaling Group using Terraform.
2. **Serverless File Processor** — S3 upload triggers Lambda to process a file, store metadata in DynamoDB, and send an SNS notification. Full Python/Boto3 implementation.

---

## Directory Structure

**`phase-2-compute-storage/`**

- `README.md` — This file
- `notes/`
  - `01-ec2-deep-dive.md`
  - `02-auto-scaling.md`
  - `03-ebs-volumes.md`
  - `04-containers-ecs-eks.md`
  - `05-lambda-serverless.md`
  - `06-elastic-beanstalk.md`
  - `07-s3-deep-dive.md`
  - `08-efs-fsx.md`
  - `09-storage-gateway-snow.md`
- `labs/`
  - `lab-01-ec2-launch-configure.md`
  - `lab-02-auto-scaling-group.md`
  - `lab-03-lambda-api-gateway.md`
  - `lab-04-s3-operations.md`
  - `lab-05-efs-shared-storage.md`
- `projects/`
  - `project-01-auto-scaling-web-app.md`
  - `project-02-serverless-file-processor.md`
- `practice-questions/`
  - `questions.md`
- `cheat-sheets/`
  - `ec2-compute-cheat-sheet.md`
  - `storage-cheat-sheet.md`
  - `lambda-serverless-cheat-sheet.md`


---

## Cost Awareness

Most activities in this phase fall within the AWS Free Tier. Each lab includes a cost estimate and a teardown section. Follow these rules:

- **Always terminate EC2 instances** after labs. A single t3.micro running 24/7 costs ~$7.50/month.
- **Delete EBS volumes and snapshots** when done. Unattached gp3 volumes cost $0.08/GB/month.
- **Lambda and S3** are essentially free at lab scale (1M free Lambda requests/month, 5GB S3 free).
- **EFS** charges $0.30/GB/month for Standard; delete file systems after the lab.
- **Use `terraform destroy`** for project teardown to guarantee all resources are removed.

Estimated total cost for Phase 2 if resources are cleaned up promptly: **$2-5**.

---

## How to Use This Phase

1. **Read the notes** in order (01 through 09). They build on each other.
2. **Complete each lab** after reading the related notes. Do not skip the teardown steps.
3. **Build the projects** after finishing all labs. Projects integrate multiple services.
4. **Review cheat sheets** before the practice questions.
5. **Answer all 25 practice questions** under timed conditions (1.5 minutes per question).
6. **Revisit weak areas** identified by the practice questions before moving to Phase 3.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Cost Awareness
- Compute
- Storage
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
