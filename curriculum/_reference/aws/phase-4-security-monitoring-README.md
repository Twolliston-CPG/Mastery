# Phase 4: Security & Monitoring (Weeks 7-8)

## Why This Phase Matters

**Security, Identity, and Compliance is the heaviest domain on the SAA-C03 exam at 30%.** If you master this phase, you have nearly a third of the exam locked down. Every other domain also touches security concepts (encrypting databases, securing VPCs, protecting S3 buckets), so the knowledge here multiplies across the entire test.

---

## Phase Overview

This phase covers two intertwined pillars of AWS architecture:

1. **Security & Identity** — Encryption, secrets management, network security, threat detection, compliance, and identity federation.
2. **Monitoring & Operations** — CloudWatch, CloudTrail, VPC Flow Logs, Systems Manager, and Infrastructure as Code with CloudFormation.

You will learn how to protect data at rest and in transit, detect threats, enforce compliance, monitor everything, and automate infrastructure deployments — all critical skills for both the exam and real-world AWS work.

---

## Learning Objectives

By the end of Phase 4, you will be able to:

- [ ] Explain KMS key types and implement envelope encryption
- [ ] Choose between Secrets Manager and SSM Parameter Store for a given scenario
- [ ] Configure WAF rules, understand Shield Standard vs Advanced, and use Firewall Manager
- [ ] Enable and interpret findings from GuardDuty, Inspector, Macie, Config, and Security Hub
- [ ] Design authentication/authorization flows with Cognito and IAM Identity Center
- [ ] Create CloudWatch metrics, alarms, dashboards, and log analysis queries
- [ ] Configure CloudTrail for multi-region logging and analyze VPC Flow Logs
- [ ] Use Systems Manager for patch management, session access, and automation
- [ ] Write and deploy CloudFormation templates with key intrinsic functions
- [ ] Identify which Trusted Advisor checks are free vs require paid support plans

---

## Estimated Time

| Component | Estimated Hours |
|-----------|----------------|
| Notes (10 topics) | 15-20 hours |
| Labs (7 hands-on) | 12-16 hours |
| Projects (2 comprehensive) | 10-14 hours |
| Practice Questions (25) | 3-4 hours |
| Cheat Sheet Review | 2-3 hours |
| **Total** | **42-57 hours** |

Spread across 2 weeks: approximately 3-4 hours per day.

---

## Prerequisites

- **Phase 1 (Foundations)** — IAM, VPC, S3 basics, CLI/SDK setup
- **Phase 2 (Compute & Storage)** — EC2, EBS, S3 advanced, Lambda basics
- **Phase 3 (Databases & Integration)** — RDS, DynamoDB, SQS/SNS/EventBridge
- **AWS CLI and Boto3** configured with a working AWS account
- **Terraform** installed (v1.0+) for select labs
- **Python 3.9+** with `boto3` library installed

---

## Services Covered

### Security & Identity
| Service | What It Does | Exam Weight |
|---------|-------------|-------------|
| **KMS** | Key management, encryption/decryption | Very High |
| **CloudHSM** | Hardware security modules (FIPS 140-2 Level 3) | Medium |
| **Secrets Manager** | Secret storage with automatic rotation | High |
| **SSM Parameter Store** | Configuration and secret storage | High |
| **ACM** | Free SSL/TLS certificates | Medium |
| **WAF** | Web application firewall (Layer 7) | High |
| **Shield** | DDoS protection | Medium |
| **Firewall Manager** | Central firewall rule management | Low-Medium |
| **Network Firewall** | VPC-level network firewall | Low-Medium |
| **GuardDuty** | Threat detection with ML | High |
| **Inspector** | Vulnerability scanning | Medium |
| **Macie** | S3 PII/sensitive data discovery | Medium |
| **Config** | Resource compliance tracking | High |
| **Security Hub** | Centralized security findings | Medium |
| **Cognito** | User authentication and federation | High |
| **IAM Identity Center** | Single sign-on (SSO) | Medium |

### Monitoring & Operations
| Service | What It Does | Exam Weight |
|---------|-------------|-------------|
| **CloudWatch** | Metrics, alarms, logs, dashboards | Very High |
| **CloudTrail** | API activity logging | Very High |
| **VPC Flow Logs** | Network traffic logging | High |
| **X-Ray** | Distributed tracing | Medium |
| **Systems Manager** | Operations management (Session Manager, Patch Manager, etc.) | High |
| **CloudFormation** | Infrastructure as Code | Very High |
| **Trusted Advisor** | Best practice recommendations | Medium |
| **Health Dashboard** | AWS service and account health | Low |

---

## File Structure

**`phase-4-security-monitoring/`**

- `README.md` — This file
- `notes/`
  - `01-kms-encryption.md` — KMS, CloudHSM, envelope encryption
  - `02-secrets-certificates.md` — Secrets Manager, Parameter Store, ACM
  - `03-network-security.md` — WAF, Shield, Firewall Manager, Network Firewall
  - `04-threat-detection-compliance.md` — GuardDuty, Inspector, Macie, Config, Security Hub
  - `05-identity-federation.md` — Cognito, IAM Identity Center, STS
  - `06-cloudwatch.md` — Metrics, Alarms, Logs, Agent, Dashboards
  - `07-cloudtrail-logging.md` — CloudTrail, VPC Flow Logs, X-Ray
  - `08-systems-manager.md` — Session Manager, Patch Manager, Run Command, etc.
  - `09-cloudformation-iac.md` — Templates, Stacks, StackSets, intrinsic functions
  - `10-trusted-advisor-health.md` — Trusted Advisor categories, Health Dashboard
- `labs/`
  - `lab-01-kms-encryption.md` — Create KMS key, encrypt S3/EBS
  - `lab-02-secrets-management.md` — Secrets Manager + Parameter Store
  - `lab-03-waf-shield.md` — WAF Web ACL with rate-based rules
  - `lab-04-guardduty-config.md` — GuardDuty + AWS Config rules
  - lab-05-cloudwatch-monitoring.md # Custom metrics, alarms, dashboards
  - `lab-06-cloudtrail-flowlogs.md` — CloudTrail + VPC Flow Logs
  - lab-07-cloudformation-deploy.md # Deploy stack with change sets
- `projects/`
  - `project-01-security-monitoring-pipeline.md` — Full security pipeline
  - `project-02-compliant-infrastructure.md` — Compliant infra stack
- `practice-questions/`
  - `questions.md` — 25 SAA-style scenario questions
- `cheat-sheets/`
  - `security-services-cheat-sheet.md` — All security services at a glance
  - `monitoring-logging-cheat-sheet.md` — Monitoring/logging quick reference


---

## Study Strategy for This Phase

1. **Read the notes first** — Each topic builds on the previous. Start with KMS (everything depends on encryption), then move through secrets, network security, detection, identity, and finally monitoring/operations.

2. **Do the labs immediately after each note** — Do not wait until you finish all notes. The hands-on reinforcement is critical.

3. **Tackle projects after all labs** — The two projects synthesize multiple services together.

4. **Use cheat sheets for daily review** — Print them or keep them open during practice questions.

5. **Practice questions last** — Do these under timed conditions (about 2 minutes per question) to simulate exam pressure.

---

## Cost Warnings

Most labs use free tier or cost pennies. Watch out for:

- **WAF Web ACLs** — $5/month per ACL + $1/month per rule. Delete immediately after lab.
- **GuardDuty** — 30-day free trial, then per-event pricing. Disable after lab if budget-tight.
- **NAT Gateways** — If any lab creates one, delete promptly ($0.045/hour).
- **ALB** — ~$0.0225/hour. Delete after WAF lab.
- **CloudTrail data events** — Can generate costs if you log S3 data events on busy buckets. Management events are free for one trail.
- **Config rules** — Free tier includes first 25 rule evaluations per region per month.

**Estimated total cost for all labs/projects: $5-15 if you clean up promptly.**

---

## Next Phase

After completing Phase 4, proceed to **Phase 5: Advanced Architectures (Weeks 9-10)** which covers multi-account strategies, disaster recovery, migration, cost optimization, and Well-Architected Framework review.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Why This Phase Matters
- Study Strategy for This Phase
- Cost Warnings
- Next Phase

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
