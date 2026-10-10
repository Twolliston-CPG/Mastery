# Monitoring & Logging — Cheat Sheet

## CloudWatch — Quick Reference

### Metrics

| Metric Type | Resolution | Cost | Examples |
|-------------|-----------|------|---------|
| Standard (basic) | 5 min | Free | EC2 CPU, Network, Status Checks |
| Standard (detailed) | 1 min | Extra charge | EC2 detailed monitoring |
| Custom | 1 sec - 1 min | $0.30/metric/month | App metrics, business KPIs |

**NOT available by default (requires CloudWatch Agent):**
- Memory utilization
- Disk space usage
- Swap usage
- Number of processes

### Metric Retention

| Resolution | Retained For |
|------------|-------------|
| 1-second (high-res) | 3 hours |
| 1-minute | 15 days |
| 5-minute | 63 days |
| 1-hour | 455 days (15 months) |

### Alarms

| State | Meaning |
|-------|---------|
| `OK` | Within threshold |
| `ALARM` | Threshold breached |
| `INSUFFICIENT_DATA` | Not enough data |

**Alarm Actions:**
- SNS notification (email, Lambda, SQS)
- Auto Scaling action (scale in/out)
- EC2 action (stop, terminate, reboot, recover)

**Composite Alarms:** Combine multiple alarms with AND/OR logic.

### Logs

| Component | Description |
|-----------|-------------|
| Log Group | Container (e.g., `/aws/lambda/my-func`) |
| Log Stream | Events from one source |
| Metric Filter | Extract metrics from log text |
| Subscription Filter | Real-time stream to Lambda/Kinesis/Firehose |
| Insights | SQL-like query language for logs |
| Export to S3 | Batch export (NOT real-time, up to 12h) |

**Real-time log delivery to S3:** Subscription Filter -> Kinesis Data Firehose -> S3

### Logs Insights — Common Queries

```
# Find errors in last hour
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 25

# Count by status code
stats count(*) by status_code
| sort count(*) desc

# Average Lambda duration
fields @duration
| stats avg(@duration), max(@duration), min(@duration)

# Top 10 IP addresses in flow logs
fields srcAddr
| stats count(*) as cnt by srcAddr
| sort cnt desc
| limit 10
```

### CloudWatch Agent

- Installs on EC2 or on-premises servers
- Collects memory, disk, swap, process metrics
- Sends log files to CloudWatch Logs
- JSON configuration file
- Store config in SSM Parameter Store
- IAM policy: `CloudWatchAgentServerPolicy`

---

## CloudTrail — Quick Reference

### Event Types

| Type | What | Cost | Examples |
|------|------|------|---------|
| **Management** | Control plane API calls | Free (1st trail) | CreateBucket, RunInstances, CreateUser |
| **Data** | Data plane operations | $0.10/100K events | GetObject, PutObject, Invoke (Lambda) |
| **Insights** | Unusual API patterns | $0.35/100K analyzed | Spike in TerminateInstances |

### Trail Configuration Checklist

| Setting | Recommended |
|---------|-------------|
| Multi-region | Yes (captures all regions) |
| Log file integrity | Yes (SHA-256 digest files) |
| S3 delivery | Yes (long-term storage) |
| CloudWatch Logs | Yes (real-time alerting) |
| SSE-KMS encryption | Yes (encrypt log files) |
| Organization trail | Yes (if using Organizations) |

### Key Fields in CloudTrail Events

| Field | What It Tells You |
|-------|------------------|
| `eventName` | The API action (e.g., `DeleteBucket`) |
| `userIdentity` | Who did it (IAM user, role, root) |
| `sourceIPAddress` | Where the call came from |
| `eventTime` | When it happened |
| `errorCode` | If the call failed, why |
| `requestParameters` | What parameters were passed |

### CloudTrail + EventBridge Pattern

```json
{
  "source": ["aws.s3"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventName": ["DeleteBucket", "PutBucketPolicy"]
  }
}
```

---

## VPC Flow Logs — Quick Reference

### Flow Log Record Fields

```
version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status
```

| Field | Key Info |
|-------|---------|
| `srcaddr` | Source IP |
| `dstaddr` | Destination IP |
| `srcport` | Source port |
| `dstport` | Destination port |
| `protocol` | 6=TCP, 17=UDP, 1=ICMP |
| `action` | **ACCEPT** or **REJECT** |
| `log-status` | OK, NODATA, SKIPDATA |

### Capture Levels

| Level | Scope |
|-------|-------|
| VPC | All traffic in the VPC |
| Subnet | Traffic in a specific subnet |
| ENI | Traffic on a specific network interface |

### Destinations

| Destination | Best For |
|-------------|----------|
| CloudWatch Logs | Real-time analysis, Insights queries |
| S3 | Long-term storage, Athena queries |
| Kinesis Data Firehose | Third-party tools |

### NOT Captured by Flow Logs
- Traffic to 169.254.169.254 (metadata)
- DHCP traffic
- VPC DNS server traffic
- VPC router reserved IP traffic
- Windows license activation

### Troubleshooting with Flow Logs

| Symptom | Check |
|---------|-------|
| SG allows but connection fails | NACL blocking (REJECT in flow logs) |
| All traffic rejected | SG or NACL misconfiguration |
| Intermittent connectivity | Flow logs for REJECT patterns |

---

## Systems Manager — Capabilities Quick Reference

| Capability | One-Line Summary | Exam Trigger Phrase |
|------------|-----------------|---------------------|
| **Session Manager** | Shell access without SSH/port 22 | "No bastion," "no SSH keys," "audit shell access" |
| **Run Command** | Execute commands on multiple instances | "Run script on 100 instances" |
| **Patch Manager** | Automated OS/software patching | "Patch on schedule," "maintenance window" |
| **Parameter Store** | Store config and secrets (free) | "Store config values," "SecureString" |
| **Automation** | Multi-step operational workflows | "Auto-remediate," "SSM runbook" |
| **Inventory** | Collect installed software/config data | "What software is installed?" |
| **State Manager** | Enforce desired configuration state | "Ensure agent is always running" |
| **Maintenance Windows** | Schedule operational tasks | "Patch every Sunday at 2 AM" |

### Session Manager vs SSH

| Feature | Session Manager | SSH |
|---------|----------------|-----|
| Port 22 required | **No** | Yes |
| SSH keys | **No** (IAM auth) | Yes |
| Bastion host | **Not needed** | Often needed |
| Session logging | **Built-in** | Manual setup |
| Private subnet (no internet) | VPC endpoints | NAT + bastion |

### SSM Prerequisites
1. SSM Agent installed (pre-installed on Amazon Linux 2/2023)
2. IAM role with `AmazonSSMManagedInstanceCore`
3. Network access to SSM endpoints (internet or VPC endpoints)

---

## CloudFormation — Key Functions Quick Reference

### Intrinsic Functions

| Function | What It Does | Example |
|----------|-------------|---------|
| `!Ref` | Reference parameter or resource | `!Ref MyBucket` -> bucket name |
| `!GetAtt` | Get resource attribute | `!GetAtt MyBucket.Arn` -> ARN |
| `!Sub` | String substitution | `!Sub "${AWS::StackName}-vpc"` |
| `!Join` | Join strings with delimiter | `!Join ["-", ["a", "b"]]` -> `"a-b"` |
| `!Select` | Pick item from list | `!Select [0, !GetAZs ""]` -> first AZ |
| `!FindInMap` | Lookup in Mappings | `!FindInMap [AMIs, !Ref Region, HVM]` |
| `!If` | Conditional value | `!If [IsProd, "m5.xl", "t3.micro"]` |
| `!ImportValue` | Cross-stack reference | `!ImportValue "VPCStack-VpcId"` |

### Pseudo Parameters

| Parameter | Returns |
|-----------|---------|
| `AWS::AccountId` | Account ID |
| `AWS::Region` | Current region |
| `AWS::StackName` | Stack name |
| `AWS::NoValue` | Remove a property |

### DeletionPolicy

| Policy | What Happens on Stack Delete |
|--------|------------------------------|
| `Delete` | Resource deleted (default) |
| `Retain` | Resource kept, removed from stack |
| `Snapshot` | Snapshot taken, then deleted (EBS, RDS, Redshift) |

### Template Sections

| Section | Required? | Purpose |
|---------|----------|---------|
| `AWSTemplateFormatVersion` | No | Always `"2010-09-09"` |
| `Description` | No | What this template does |
| `Parameters` | No | User inputs at deploy time |
| `Mappings` | No | Static lookup tables |
| `Conditions` | No | Conditional resource creation |
| `Transform` | No | Macros (e.g., SAM) |
| **`Resources`** | **Yes** | **The actual infrastructure** |
| `Outputs` | No | Return values, cross-stack exports |

### Key Features

| Feature | Purpose |
|---------|---------|
| Change Set | Preview changes before applying |
| Drift Detection | Find out-of-band changes |
| Stack Policy | Prevent accidental resource updates |
| StackSets | Deploy across accounts/regions |
| CreationPolicy + cfn-signal | Wait for instance bootstrap completion |
| cfn-init | Declarative instance configuration |

---

## Trusted Advisor — Free Checks (All Accounts)

| # | Check | Category |
|---|-------|----------|
| 1 | S3 bucket permissions (public access) | Security |
| 2 | Security groups — unrestricted ports | Security |
| 3 | IAM use (are IAM users created?) | Security |
| 4 | MFA on root account | Security |
| 5 | EBS public snapshots | Security |
| 6 | RDS public snapshots | Security |
| 7 | Service limits (basic) | Service Limits |

**Everything else (cost optimization, performance, fault tolerance, advanced security) requires Business or Enterprise Support.**

---

## Health Dashboard

| Dashboard | Scope | Shows |
|-----------|-------|-------|
| **Service Health** | Global/public | Current status of all AWS services |
| **Personal Health (Account)** | Your account | Events affecting YOUR resources |

Personal Health Dashboard events + EventBridge = automate responses to maintenance events.

---

## Quick Decision Matrix

| I Need To... | Use... |
|--------------|--------|
| Monitor EC2 CPU | CloudWatch standard metrics |
| Monitor EC2 memory | CloudWatch Agent |
| Alert on metric threshold | CloudWatch Alarm |
| Alert on combined conditions | Composite Alarm |
| Search application logs | CloudWatch Logs Insights |
| Stream logs to S3 real-time | Subscription Filter -> Firehose -> S3 |
| Know who deleted a resource | CloudTrail |
| Know who accessed an S3 object | CloudTrail data events |
| Troubleshoot network connectivity | VPC Flow Logs |
| Access EC2 without SSH | Session Manager |
| Automate patching | Patch Manager + Maintenance Window |
| Deploy infrastructure as code | CloudFormation |
| Preview infrastructure changes | Change Set |
| Detect manual config changes | Drift Detection |
| Check best practices (free) | Trusted Advisor (7 free checks) |
| Get notified of EC2 retirement | Personal Health Dashboard + EventBridge |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- CloudWatch — Quick Reference
- CloudTrail — Quick Reference
- VPC Flow Logs — Quick Reference
- Systems Manager — Capabilities Quick Reference

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
