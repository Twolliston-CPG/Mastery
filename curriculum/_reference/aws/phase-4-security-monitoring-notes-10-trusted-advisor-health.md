# 10 — Trusted Advisor & Health Dashboard

## Overview

AWS Trusted Advisor inspects your AWS environment and provides recommendations across five categories. AWS Health Dashboard provides visibility into service events and account-specific issues. Both are commonly tested on the exam, especially which Trusted Advisor checks are free vs require paid support plans.

---

## Trusted Advisor — Five Categories

### 1. Cost Optimization

| Check | What It Finds | Support Plan Required |
|-------|--------------|----------------------|
| **Low Utilization Amazon EC2 Instances** | Instances with avg CPU < 10% for 14 days | Business / Enterprise |
| **Idle Load Balancers** | ALBs/NLBs with no registered targets or no traffic | Business / Enterprise |
| **Unassociated Elastic IP Addresses** | EIPs not attached to running instances | Business / Enterprise |
| **Underutilized Amazon EBS Volumes** | Volumes with low read/write activity | Business / Enterprise |
| **Amazon RDS Idle DB Instances** | RDS instances with no connections for 7 days | Business / Enterprise |
| **Savings Plans / Reserved Instance Optimization** | Recommendations to buy RI or Savings Plans | Business / Enterprise |

### 2. Performance

| Check | What It Finds | Support Plan Required |
|-------|--------------|----------------------|
| **High Utilization Amazon EC2 Instances** | Instances consistently at high CPU | Business / Enterprise |
| **Large Number of Rules in an EC2 Security Group** | SGs with many rules (performance impact) | Business / Enterprise |
| **CloudFront Content Delivery Optimization** | Content that could benefit from caching | Business / Enterprise |
| **Amazon EBS Provisioned IOPS Volume Attachment Configuration** | Volumes not attached to EBS-optimized instances | Business / Enterprise |

### 3. Security

| Check | What It Finds | Support Plan Required |
|-------|--------------|----------------------|
| **S3 Bucket Permissions** | Buckets with open access (public read/write) | **FREE** |
| **Security Groups — Specific Ports Unrestricted** | SGs allowing unrestricted access (0.0.0.0/0) to risky ports | **FREE** |
| **IAM Use** | Whether IAM users have been created (not just using root) | **FREE** |
| **MFA on Root Account** | Whether MFA is enabled on root account | **FREE** |
| **EBS Public Snapshots** | EBS snapshots that are publicly shared | **FREE** |
| **RDS Public Snapshots** | RDS snapshots that are publicly shared | **FREE** |
| **IAM Access Key Rotation** | Keys not rotated in 90 days | Business / Enterprise |
| **Exposed Access Keys** | Access keys exposed in public code repositories | Business / Enterprise |
| **CloudTrail Logging** | Whether CloudTrail is enabled | Business / Enterprise |

### 4. Fault Tolerance

| Check | What It Finds | Support Plan Required |
|-------|--------------|----------------------|
| **Amazon RDS Multi-AZ** | RDS instances not configured for Multi-AZ | Business / Enterprise |
| **Amazon RDS Backups** | RDS instances with backups disabled | Business / Enterprise |
| **Auto Scaling Group Health Check** | ASGs not using ELB health checks | Business / Enterprise |
| **Amazon S3 Bucket Versioning** | Buckets without versioning enabled | Business / Enterprise |
| **ELB Cross-Zone Load Balancing** | ELBs without cross-zone balancing | Business / Enterprise |
| **Amazon Route 53 Failover Resource Record Sets** | Missing failover configurations | Business / Enterprise |
| **VPN Tunnel Redundancy** | VPN connections with only one active tunnel | Business / Enterprise |

### 5. Service Limits (Quotas)

| Check | What It Finds | Support Plan Required |
|-------|--------------|----------------------|
| **Service Limits** | Resources approaching service limits (e.g., VPCs, EIPs, EC2 instances) | **FREE** (basic checks) |
| **Detailed Service Limits** | More granular limit checks across all services | Business / Enterprise |

---

## Free vs Paid Checks — Summary

### Free Checks (Available to ALL Accounts)

| Category | Free Checks |
|----------|-------------|
| **Security** | S3 bucket permissions, SG unrestricted ports, IAM use, MFA on root, EBS public snapshots, RDS public snapshots |
| **Service Limits** | Basic service limit checks |

**Total: 7 free checks** (6 security + service limits)

### Paid Checks (Require Business or Enterprise Support)

| Category | Availability |
|----------|-------------|
| **Cost Optimization** | ALL checks require Business/Enterprise |
| **Performance** | ALL checks require Business/Enterprise |
| **Security** | Advanced checks require Business/Enterprise |
| **Fault Tolerance** | ALL checks require Business/Enterprise |
| **Service Limits** | Detailed checks require Business/Enterprise |

### Exam Memory Aid
- **Free = 6 security basics + service limits**
- Everything else = Business or Enterprise Support plan

---

## Trusted Advisor + Automation

### EventBridge Integration
```
Trusted Advisor check status changes
    │
    v
EventBridge rule matches (e.g., status = "WARN" or "ERROR")
    │
    v
Trigger: Lambda function, SNS notification, SSM Automation
    │
    v
Auto-remediate: delete idle ELB, release unassociated EIP, etc.
```

### API / CLI Access
- Full API access requires Business or Enterprise Support
- Programmatic refresh of checks (max once every 5 minutes per check)
- Use `support` API (must be called from `us-east-1`)

---

## AWS Health Dashboard

### Two Components

| Component | What It Shows | Scope |
|-----------|--------------|-------|
| **Service Health Dashboard** | Current status of all AWS services across all regions | Global / public |
| **Personal Health Dashboard (PHD)** | Events and notifications specific to YOUR account | Account-specific |

### Personal Health Dashboard (Account Health)

| Feature | Description |
|---------|-------------|
| **Open Issues** | Currently active events affecting your resources |
| **Scheduled Changes** | Upcoming planned maintenance (e.g., EC2 host retirement) |
| **Event Log** | Historical record of past events |
| **EventBridge Integration** | Trigger automation based on health events |
| **Organizational View** | Aggregate health events across all accounts in AWS Organizations |

### Common Health Events

| Event Type | Example |
|------------|---------|
| **Operational issue** | "EC2 API throttling in us-east-1" |
| **Scheduled maintenance** | "Your EC2 instance i-abc123 is scheduled for host retirement on 2024-03-15" |
| **Account notification** | "Your RDS instance requires a minor version upgrade" |

### Health Dashboard + EventBridge

```
EC2 instance scheduled for retirement
    │
    v
Personal Health Dashboard event
    │
    v
EventBridge rule matches event
    │
    v
Lambda function: stop instance, create AMI, launch new instance
```

```python
# EventBridge rule pattern for EC2 retirement
{
    "source": ["aws.health"],
    "detail-type": ["AWS Health Event"],
    "detail": {
        "service": ["EC2"],
        "eventTypeCategory": ["scheduledChange"]
    }
}
```

---

## Trusted Advisor vs Config vs Security Hub

| Feature | Trusted Advisor | Config | Security Hub |
|---------|----------------|--------|-------------|
| **Focus** | Best practice recommendations (cost, performance, security, fault tolerance, limits) | Resource compliance with specific rules | Centralized security findings |
| **Checks** | Fixed set of checks | 300+ managed rules + custom rules | Security standards (CIS, PCI-DSS) |
| **Scope** | Account-level recommendations | Resource-level compliance | Findings aggregation from multiple services |
| **Remediation** | Manual or EventBridge->Lambda | Built-in auto-remediation with SSM | EventBridge->Lambda |
| **Cost awareness** | Yes (cost optimization category) | No | No |
| **Free tier** | 7 basic checks | 25 rule evaluations/month | 30-day trial |

---

## Common Exam Scenarios

| Scenario | Answer |
|----------|--------|
| "Which free check identifies publicly accessible S3 buckets?" | Trusted Advisor (free security check) |
| "Identify underutilized EC2 instances to save money" | Trusted Advisor (cost optimization — requires Business support) |
| "Company has Basic support, what checks are available?" | 6 security checks + service limits only |
| "Get notified when EC2 instance is scheduled for retirement" | Personal Health Dashboard + EventBridge |
| "View status of all AWS services globally" | Service Health Dashboard |
| "Check if approaching VPC limit" | Trusted Advisor (service limits — free) |
| "Automatically remediate when approaching service limits" | Trusted Advisor + EventBridge + Lambda |
| "View health events across all accounts in organization" | Personal Health Dashboard organizational view |
| "Check if MFA is enabled on root account" | Trusted Advisor (free security check) |
| "Find RDS instances not using Multi-AZ" | Trusted Advisor (fault tolerance — requires Business support) |

---

## Next Steps

- You have completed all 10 notes for Phase 4. Proceed to the labs.
- Start with **Lab 01: KMS Encryption** and work through all 7 labs in order.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Trusted Advisor — Five Categories
- Free vs Paid Checks — Summary
- Trusted Advisor + Automation
- AWS Health Dashboard

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
