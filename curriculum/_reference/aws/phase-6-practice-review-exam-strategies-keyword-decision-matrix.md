# Keyword Decision Matrix — Exam Keywords to AWS Services

When you see specific keywords in an SAA-C03 question, they are signaling which service or approach is the correct answer. This matrix maps those signals to the right answers.

---

## Performance Keywords

| Keyword / Phrase | Correct Service / Answer |
|---|---|
| "millisecond latency" | DynamoDB |
| "microsecond latency" | DAX (DynamoDB) or ElastiCache |
| "sub-millisecond latency" | ElastiCache (Redis/Memcached) |
| "single-digit millisecond" | DynamoDB |
| "real-time" | Kinesis Data Streams |
| "near-real-time" | Kinesis Data Firehose (60-sec buffer minimum) |
| "real-time dashboard" | Kinesis Data Analytics |
| "low latency globally" | CloudFront (HTTP) or Global Accelerator (TCP/UDP) |
| "high IOPS" | io2 / io2 Block Express EBS |
| "high throughput" | st1 EBS (HDD) or gp3 (SSD) |
| "highest network performance" | Cluster placement group + enhanced networking |
| "maximize read throughput" | Read Replicas or ElastiCache |
| "petabyte-scale analytics" | Redshift |
| "full-text search" | OpenSearch Service |

---

## Cost Keywords

| Keyword / Phrase | Correct Service / Answer |
|---|---|
| "cost-effective" / "minimize cost" | Spot, RI, Savings Plans, lifecycle policies, right-sizing |
| "least expensive" | Usually the simplest managed service or right storage class |
| "reduce data transfer costs" | CloudFront, VPC endpoints, same-AZ communication |
| "reduce NAT Gateway costs" | VPC Gateway Endpoints for S3/DynamoDB |
| "pay per use" / "pay per request" | Serverless (Lambda, DynamoDB on-demand, Fargate) |
| "no upfront cost" | On-Demand, Savings Plans (No Upfront), Lambda |
| "3-year commitment" | Reserved Instances (All Upfront for max savings) |
| "fault-tolerant batch job" | Spot Instances |
| "unpredictable traffic" | Serverless (Lambda + API GW + DynamoDB on-demand) |
| "archive" / "long-term retention" | S3 Glacier Deep Archive |
| "unknown access patterns" | S3 Intelligent-Tiering |
| "infrequently accessed" | S3 Standard-IA or S3 One Zone-IA |
| "reduce idle costs" | Schedule instances, Fargate (scales to zero), serverless |

---

## Resilience / Availability Keywords

| Keyword / Phrase | Correct Service / Answer |
|---|---|
| "high availability" | Multi-AZ deployment |
| "survive AZ failure" | Multi-AZ + Auto Scaling across AZs |
| "automatic failover" | RDS Multi-AZ, Aurora, ElastiCache Multi-AZ |
| "disaster recovery" | Cross-region replication, backup/restore, pilot light, warm standby |
| "RTO hours, lowest cost" | Backup and Restore |
| "RTO minutes, RPO minutes" | Pilot Light or Warm Standby |
| "RTO near zero, RPO near zero" | Multi-Site Active-Active |
| "no single point of failure" | Multi-AZ, Auto Scaling, ALB |
| "decouple" / "loosely coupled" | SQS between tiers |
| "absorb traffic spikes" | SQS queue (buffer) + Auto Scaling |
| "messages processed exactly once" | SQS FIFO |
| "messages in order" | SQS FIFO or Kinesis (per shard) |
| "no message loss" | SQS (persistent) with DLQ for failures |
| "fan-out" / "multiple subscribers" | SNS topic → multiple SQS queues |
| "event-driven" | EventBridge, SNS, Lambda triggers |
| "replicate globally" | DynamoDB Global Tables, Aurora Global DB, S3 CRR |
| "cross-region" | CRR, cross-region read replicas, Global DB |

---

## Security Keywords

| Keyword / Phrase | Correct Service / Answer |
|---|---|
| "least privilege" | Minimal IAM permissions, IAM roles, most restrictive policy |
| "temporary credentials" | IAM Roles + STS (AssumeRole) |
| "cross-account access" | IAM Role (cross-account) or Resource-based policy |
| "keep existing permissions during cross-account" | Resource-based policy (NOT role assumption) |
| "encrypt at rest" | KMS (SSE-KMS, EBS encryption, RDS encryption) |
| "encrypt in transit" | SSL/TLS, HTTPS, force_ssl on RDS |
| "manage encryption keys" | KMS Customer Managed Key (CMK) |
| "rotate credentials automatically" | AWS Secrets Manager |
| "store configuration" | Systems Manager Parameter Store |
| "block IP address" | NACL (deny rule) — NOT security groups |
| "SQL injection" / "XSS" | AWS WAF |
| "DDoS protection" | Shield Standard (free) or Shield Advanced (paid) |
| "detect threats" | GuardDuty |
| "find PII in S3" | Amazon Macie |
| "vulnerability assessment" | Amazon Inspector |
| "compliance monitoring" | AWS Config |
| "audit API calls" | CloudTrail |
| "tamper-proof logs" | CloudTrail + S3 Object Lock (Compliance mode) |
| "prevent public S3 buckets" | S3 Block Public Access |
| "private access to AWS services" | VPC Endpoints (Gateway for S3/DynamoDB, Interface for others) |
| "no internet access needed" | VPC Endpoints |
| "SSO" / "single sign-on" | IAM Identity Center |
| "user authentication" / "sign-up/sign-in" | Cognito User Pools |
| "federated access" / "social login" | Cognito User Pools (Google, SocialGraph) |
| "temporary AWS credentials for app users" | Cognito Identity Pools |
| "SSL certificate for ALB" | ACM (free, auto-renewing) |
| "prevent object deletion" | S3 Object Lock (Compliance mode) |
| "restrict CloudFront content" | Signed URLs / Signed Cookies |
| "restrict S3 access to CloudFront" | Origin Access Control (OAC) |
| "HIPAA" / "PCI DSS" | Encryption + CloudTrail + compliant services |
| "GDPR" / "data residency" | SCPs to restrict regions, ensure data stays in EU |

---

## Architecture Keywords

| Keyword / Phrase | Correct Service / Answer |
|---|---|
| "minimal operational overhead" | Managed services, serverless |
| "fully managed" | RDS, Aurora, DynamoDB, Fargate, Lambda, managed streaming |
| "no servers to manage" | Serverless: Lambda, Fargate, DynamoDB, Aurora Serverless |
| "containerized application" | ECS (Fargate or EC2) or EKS |
| "microservices" | ALB (path-based routing), ECS, API Gateway |
| "monolith to microservices" | Decouple with SQS/SNS, use ALB path routing |
| "batch processing" | AWS Batch, EMR, EC2 Spot |
| "ETL" / "data transformation" | AWS Glue |
| "orchestrate workflow" | Step Functions |
| "SFTP to S3" | AWS Transfer Family |
| "hybrid storage" / "on-premises file access" | Storage Gateway |
| "NFS file share" | EFS (Linux) |
| "SMB file share" / "Windows" | FSx for Windows File Server |
| "HPC" / "machine learning training" | P-family instances, cluster placement group |
| "data lake" | S3 + Athena + Glue |
| "data warehouse" | Redshift |
| "migrate database" | DMS (+ SCT for heterogeneous) |
| "migrate servers" | Application Migration Service (MGN) |
| "assess migration readiness" | Migration Hub |
| "large data transfer (100 TB+)" | Snowball Edge |
| "massive data transfer (10 PB+)" | Snowmobile |

---

## Networking Keywords

| Keyword / Phrase | Correct Service / Answer |
|---|---|
| "static IP for application" | NLB or Global Accelerator |
| "path-based routing" | ALB |
| "UDP support" | NLB or Global Accelerator |
| "WebSocket" | ALB |
| "private connection to on-premises" | Direct Connect |
| "quick setup VPN" | Site-to-Site VPN (hours, not weeks) |
| "consistent low latency to on-premises" | Direct Connect (long-term) |
| "connect multiple VPCs" | Transit Gateway |
| "VPC-to-VPC non-transitive" | VPC Peering |
| "DNS routing" | Route 53 |
| "route to nearest healthy endpoint" | Route 53 latency-based with health checks |
| "blue-green DNS" | Route 53 weighted routing |
| "third-party network appliance" | Gateway Load Balancer |

---

## Database Decision Keywords

| If Question Says... | Choose... |
|---|---|
| "relational" + "managed" | RDS or Aurora |
| "relational" + "auto-scaling storage" | Aurora |
| "relational" + "15 read replicas" | Aurora |
| "relational" + "global" | Aurora Global Database |
| "relational" + "serverless" | Aurora Serverless v2 |
| "relational" + "Oracle" or "SQL Server" | RDS (Aurora does NOT support Oracle/SQL Server) |
| "key-value" | DynamoDB |
| "document database" | DynamoDB or DocumentDB |
| "graph database" | Neptune |
| "time-series" | Timestream |
| "ledger" / "immutable" | QLDB |
| "in-memory" / "caching" | ElastiCache |
| "DynamoDB + cache" | DAX |
| "data warehouse" / "OLAP" | Redshift |
| "search" / "full-text" | OpenSearch |

---

## Compute Decision Keywords

| If Question Says... | Choose... |
|---|---|
| "event-driven, short-lived" | Lambda |
| "processing < 15 minutes" | Lambda |
| "processing > 15 minutes" | ECS Fargate or EC2 |
| "containerized" | ECS (Fargate or EC2) |
| "Kubernetes" | EKS |
| "variable traffic, scale to zero" | Fargate or Lambda |
| "GPU workload" | P/G-family EC2 instances |
| "BYOL" | Dedicated Hosts |
| "batch job, interruptible" | Spot Instances |
| "steady 24/7 production" | Reserved Instances or Savings Plans |

---

## Storage Decision Keywords

| If Question Says... | Choose... |
|---|---|
| "object storage" | S3 |
| "block storage for EC2" | EBS |
| "shared file system, Linux" | EFS |
| "shared file system, Windows" | FSx for Windows |
| "high-performance file system, HPC" | FSx for Lustre |
| "temporary, highest IOPS" | Instance Store |
| "archive, 12-hour retrieval OK" | Glacier Deep Archive |
| "archive, minutes retrieval" | Glacier Instant Retrieval |
| "hybrid on-prem file access" | Storage Gateway |
| "backup to cloud" | AWS Backup |

---

## How to Use This Matrix During the Exam

1. Read the question and identify 1-2 keywords
2. Map the keywords to the correct service using this matrix
3. Find the answer option that matches
4. Verify the answer does not violate any constraints in the question
5. If two answers match your keywords, use elimination to pick the best one
6. Select and move on

This matrix is a mental model, not a lookup table. The more practice questions you do, the more automatic these associations become.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Performance Keywords
- Cost Keywords
- Resilience / Availability Keywords
- Security Keywords

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
