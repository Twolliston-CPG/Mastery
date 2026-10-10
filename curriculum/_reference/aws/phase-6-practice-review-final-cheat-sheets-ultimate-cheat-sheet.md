# Ultimate AWS SAA-C03 Cheat Sheet

**Read this the night before the exam. Everything critical in one document.**

---

## COMPUTE

### EC2
- Instance families: M (general), C (compute), R (memory), T (burstable), P/G (GPU), I (storage I/O)
- Placement groups: Cluster (low latency), Spread (max 7/AZ, different hardware), Partition (Kafka/Hadoop)
- Instance store: ephemeral, highest IOPS, data lost on stop/terminate
- User data: runs at launch (bootstrap scripts)
- Instance metadata: http://169.254.169.254/latest/meta-data/

### EC2 Pricing
- On-Demand: pay per second, no commitment
- Reserved: 1 or 3 yr, up to 72% off. Standard (locked) vs Convertible (flexible)
- Savings Plans: $/hr commitment. Compute (most flexible) vs EC2 Instance (more savings)
- Spot: up to 90% off, can be interrupted with 2-min notice
- Dedicated Hosts: physical server, BYOL. Dedicated Instances: dedicated hardware

### Lambda
- Max timeout: 15 minutes
- Max memory: 10,240 MB (10 GB)
- Max /tmp storage: 10 GB
- Max deployment package: 250 MB unzipped
- Default concurrency: 1,000 per region
- In VPC: needs NAT Gateway for internet, VPC endpoints for AWS services
- RDS connection issues: use RDS Proxy

### ECS/Fargate
- ECS on EC2: you manage instances. ECS on Fargate: serverless containers.
- Fargate: no instance management, pay per vCPU + memory
- Fargate Spot: up to 70% savings for fault-tolerant tasks
- Task roles: IAM role per task (like instance profile for EC2)

---

## STORAGE

### S3
- Object storage, max object size 5 TB, max PUT 5 GB (use multipart for > 100 MB)
- 11 nines durability (99.999999999%) for all classes
- 3,500 PUT / 5,500 GET per second per prefix
- Versioning: protects against accidental delete, stores all versions
- Object Lock: Compliance (nobody can delete, even root) vs Governance (special permissions can override)
- Encryption: SSE-S3, SSE-KMS (audit trail), SSE-C (customer key), client-side
- Replication: CRR (cross-region) / SRR (same-region), requires versioning, only new objects replicated
- Transfer Acceleration: faster uploads via edge locations
- S3 Select: SQL on S3 objects to retrieve subsets of data
- Block Public Access: account-level override to prevent public buckets

### S3 Storage Classes (cheapest to most expensive per GB stored)
1. Glacier Deep Archive ($0.00099/GB) — 12+ hour retrieval
2. Glacier Flexible Retrieval ($0.0036/GB) — minutes to hours
3. Glacier Instant Retrieval ($0.004/GB) — milliseconds
4. One Zone-IA ($0.01/GB) — single AZ risk
5. Standard-IA ($0.0125/GB) — infrequent, multi-AZ
6. Intelligent-Tiering ($0.023/GB frequent tier) — auto-tiering
7. Standard ($0.023/GB) — frequent access

### EBS
- gp3: 3,000 IOPS baseline, up to 16,000 IOPS, 125-1,000 MB/s. Best general purpose.
- gp2: 3 IOPS/GB, up to 16,000. Burst credit model.
- io2/io2 Block Express: up to 64,000/256,000 IOPS. For databases.
- st1: throughput optimized HDD, up to 500 MB/s. Big data.
- sc1: cold HDD, cheapest. Infrequent access.
- Multi-Attach: io1/io2 only, same AZ, up to 16 instances
- Snapshots: incremental, stored in S3, can copy cross-region
- CANNOT encrypt existing unencrypted volume in-place

### EFS
- NFS protocol, Linux only
- Multi-AZ by default (Standard class)
- Auto-scales storage
- Lifecycle policy to EFS-IA (up to 92% cheaper)
- Encryption at rest: must be enabled at creation

### FSx
- FSx for Windows: SMB, Active Directory, Windows
- FSx for Lustre: HPC, ML, linked to S3
- FSx for NetApp ONTAP: multi-protocol (NFS, SMB, iSCSI)

---

## DATABASES

### RDS
- Managed relational: MySQL, PostgreSQL, MariaDB, Oracle, SQL Server
- Multi-AZ: synchronous standby, automatic failover (1-2 min)
- Read Replicas: up to 5, async, cross-region supported
- Automated backups: retention 1-35 days, PITR support
- Cannot encrypt existing unencrypted instance — must snapshot + copy encrypted + restore
- Storage auto-scaling: set max storage threshold

### Aurora
- MySQL and PostgreSQL compatible (NOT Oracle, NOT SQL Server)
- 6 copies across 3 AZs, auto-scales to 128 TB
- Up to 15 read replicas, failover ~30 seconds
- Writer endpoint, reader endpoint, custom endpoints
- Global Database: <1 second cross-region replication
- Serverless v2: auto-scales ACUs

### DynamoDB
- Key-value/document, single-digit ms latency
- On-demand or provisioned capacity modes
- Auto-scaling for provisioned mode
- Global Tables: multi-region, multi-active
- DAX: in-memory cache, microsecond reads
- Streams: change data capture, trigger Lambda
- PITR: restore to any point in last 35 days
- TTL: auto-delete expired items (no WCU cost)
- Max item size: 400 KB

### ElastiCache
- Redis: persistence, replication, sorted sets, pub/sub, Multi-AZ
- Memcached: simple, multi-threaded, no persistence, no replication
- Use cases: session store, caching, leaderboards (Redis sorted sets)

### Redshift
- Data warehouse, OLAP, petabyte-scale, columnar storage
- NOT for OLTP (use RDS/Aurora for that)
- Redshift Spectrum: query S3 data directly
- Redshift Serverless: auto-scales, pay per query

---

## NETWORKING

### VPC Essentials
- CIDR: /16 (65,536 IPs) to /28 (16 IPs)
- Subnets: public (route to IGW) vs private (no route to IGW)
- Internet Gateway: enables internet access for VPC
- NAT Gateway: enables private subnet instances to reach internet (outbound only)
- NAT Gateway: deploy one per AZ for HA. Costs $0.045/hr + $0.045/GB
- VPC Peering: non-transitive, no CIDR overlap
- Transit Gateway: hub-and-spoke, supports inter-region peering
- VPC Flow Logs: capture IP traffic info (not packet content)

### VPC Endpoints
- Gateway Endpoint: S3, DynamoDB. FREE. Route table entry.
- Interface Endpoint (PrivateLink): most other services. ENI in subnet. Costs per hour + GB.

### Route 53
- Simple, Weighted, Latency, Failover, Geolocation, Geoproximity, Multi-value
- Health checks: HTTP, HTTPS, TCP. Can check endpoint, CloudWatch alarm, or calculated
- Alias records: point to AWS resources (ALB, CloudFront, S3 website). Free queries.

### CloudFront
- CDN, 400+ edge locations
- Origins: S3, ALB, EC2, custom HTTP
- OAC: restrict S3 access to CloudFront only
- Lambda@Edge: customize content per viewer
- Cache behaviors: different settings per URL path
- Signed URLs/Cookies: restrict content access

### Global Accelerator
- 2 static Anycast IPs
- TCP/UDP (not just HTTP)
- Routes to nearest healthy endpoint
- No caching

---

## SECURITY

### IAM
- Users, Groups, Roles, Policies
- Roles: temporary credentials, best practice for EC2/Lambda
- Policy evaluation: explicit Deny > explicit Allow > default Deny
- SCP: restrict permissions at Organization level (does NOT apply to management account)
- Permission Boundaries: max permissions for an identity

### KMS
- AWS Owned (free), AWS Managed (free, auto-rotate), Customer Managed ($1/month, configurable rotation)
- CMK auto-rotation: every year (cannot change period)
- Cross-account: must update key policy

### Encryption Quick Reference
- S3: SSE-S3, SSE-KMS, SSE-C, client-side
- EBS: AES-256, KMS-backed. Enable at creation or encrypt snapshot copy.
- RDS: KMS. Enable at creation. Cannot enable on existing.
- DynamoDB: AWS owned (default), KMS managed, customer CMK
- EFS: KMS. Must enable at creation.
- In-transit: SSL/TLS, force_ssl for RDS

### Security Services
- **WAF**: Layer 7, SQL injection, XSS, rate limiting. Works with ALB, CloudFront, API Gateway.
- **Shield Standard**: Free, automatic DDoS Layer 3/4. **Shield Advanced**: $3K/month, DRT, cost protection.
- **GuardDuty**: Threat detection (ML). Detects compromised instances, unusual API calls.
- **Inspector**: Vulnerability scanning for EC2, containers.
- **Macie**: PII/sensitive data discovery in S3.
- **Config**: Resource compliance. Managed rules. Auto-remediation with SSM.
- **CloudTrail**: API call logging. Multi-region trail. S3 Object Lock for tamper-proof.
- **Cognito**: User Pools (authentication) + Identity Pools (temporary AWS credentials).
- **Secrets Manager**: Secret rotation (RDS built-in). $0.40/secret/month.
- **Parameter Store**: Config values. Free (standard). No auto-rotation.
- **ACM**: Free SSL/TLS certificates. Auto-renewal (DNS validation CNAME must exist). ALB, CloudFront, API GW.

---

## MESSAGING & INTEGRATION

### SQS
- Standard: unlimited throughput, at-least-once, best-effort ordering
- FIFO: 3,000 msg/sec (high-throughput), exactly-once, strict ordering
- DLQ: captures failed messages
- Visibility Timeout: default 30s, max 12 hours
- Retention: default 4 days, max 14 days
- Long Polling: reduce empty receives (WaitTimeSeconds > 0)

### SNS
- Pub/sub, push-based
- Subscribers: SQS, Lambda, HTTP, email, SMS
- Fan-out: SNS → multiple SQS queues

### EventBridge
- Event bus, content-based routing
- 90+ AWS service sources
- Archive and replay events
- Schema registry

### Step Functions
- Orchestrate workflows (state machines)
- Standard: up to 1 year, at-least-once. Express: up to 5 min, at-most-once.
- Retry with exponential backoff for transient failures

---

## MIGRATION & TRANSFER

| Scenario | Service |
|---|---|
| Database migration | AWS DMS (+ SCT for schema conversion) |
| Online file transfer | AWS DataSync |
| 10-80 TB offline | Snowball Edge |
| 10 PB offline | Snowmobile |
| SFTP to S3 | AWS Transfer Family |
| Hybrid file share (NFS/SMB) | AWS Storage Gateway |
| Server migration | AWS Application Migration Service (MGN) |
| Strategy assessment | AWS Migration Hub |

---

## MONITORING & MANAGEMENT

### CloudWatch
- Metrics: CPU, network, disk (NOT memory — needs agent)
- Alarms: trigger SNS, Auto Scaling, EC2 actions
- Logs: store, search, analyze application logs
- Agent: required for memory, disk utilization, custom metrics
- Dashboard: visualize metrics

### CloudTrail
- API call logging (who did what, when, from where)
- Management events (default): create/delete/modify resources
- Data events (optional): S3 object-level, Lambda invocations
- Multi-region trail: captures all regions

### AWS Organizations
- Consolidated billing: volume discounts, single payment
- SCPs: restrict permissions across member accounts
- OUs: organizational units for grouping accounts
- SCPs do NOT apply to management account

---

## KEY NUMBERS TO REMEMBER

| Item | Limit |
|---|---|
| S3 max object size | 5 TB |
| S3 max PUT | 5 GB (multipart for > 100 MB) |
| Lambda max timeout | 15 minutes |
| Lambda max memory | 10,240 MB |
| SQS max message size | 256 KB |
| SQS max retention | 14 days |
| DynamoDB max item size | 400 KB |
| EBS gp3 max IOPS | 16,000 |
| EBS io2 Block Express max IOPS | 256,000 |
| RDS read replicas | 5 (MySQL/PostgreSQL) |
| Aurora read replicas | 15 |
| VPC max CIDR | /16 (65,536 IPs) |
| SGs per ENI | 5 |
| NLB static IPs | 1 per AZ |
| Global Accelerator IPs | 2 (Anycast) |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- COMPUTE
- STORAGE
- DATABASES
- NETWORKING

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
