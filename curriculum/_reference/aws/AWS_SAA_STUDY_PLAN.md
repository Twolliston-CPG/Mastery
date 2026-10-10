# AWS Solutions Architect Associate (SAA-C03) Study Plan

## Exam Overview

| Detail              | Info                                          |
|---------------------|-----------------------------------------------|
| **Exam Code**       | SAA-C03                                       |
| **Duration**        | 130 minutes                                   |
| **Questions**       | 65 (multiple choice & multiple response)      |
| **Passing Score**   | 720 / 1000                                    |
| **Cost**            | $150 USD                                      |
| **Validity**        | 3 years                                       |
| **Recommended Exp** | 1+ year hands-on with AWS                     |

---

## Exam Domain Breakdown

| Domain | Weight | Topic |
|--------|--------|-------|
| 1 | **30%** | Design Secure Architectures |
| 2 | **26%** | Design Resilient Architectures |
| 3 | **24%** | Design High-Performing Architectures |
| 4 | **20%** | Design Cost-Optimized Architectures |

---

## Phase 1: Foundation (Weeks 1-2)

**Goal:** Build a solid understanding of core AWS concepts and global infrastructure.

### Week 1 — Cloud Fundamentals & IAM

- [ ] AWS Global Infrastructure (Regions, AZs, Edge Locations, Local Zones)
- [ ] AWS Well-Architected Framework (all 6 pillars)
  - Operational Excellence
  - Security
  - Reliability
  - Performance Efficiency
  - Cost Optimization
  - Sustainability
- [ ] AWS Shared Responsibility Model
- [ ] IAM Deep Dive
  - Users, Groups, Roles, Policies
  - Policy evaluation logic (explicit deny > explicit allow > implicit deny)
  - Identity-based vs Resource-based policies
  - IAM Conditions, Permission Boundaries
  - STS and AssumeRole
  - Cross-account access patterns
  - IAM Access Analyzer
- [ ] AWS Organizations & SCPs
- [ ] AWS Control Tower

### Week 2 — Networking Fundamentals

- [ ] VPC Core Concepts
  - CIDR blocks, Subnets (public vs private)
  - Route Tables, Internet Gateway, NAT Gateway vs NAT Instance
  - Security Groups (stateful) vs NACLs (stateless)
- [ ] VPC Peering, Transit Gateway, PrivateLink
- [ ] VPC Endpoints (Gateway vs Interface)
- [ ] VPN (Site-to-Site, Client VPN)
- [ ] AWS Direct Connect (dedicated vs hosted, LAG)
- [ ] Route 53
  - Record types (A, AAAA, CNAME, Alias)
  - Routing policies (Simple, Weighted, Latency, Failover, Geolocation, Geoproximity, Multi-value)
  - Health checks and DNS failover
- [ ] Elastic Load Balancing
  - ALB (Layer 7) — path/host-based routing, gRPC, WebSockets
  - NLB (Layer 4) — static IP, ultra-low latency, TLS termination
  - GLB (Layer 3) — third-party appliances
  - Cross-zone load balancing, sticky sessions, connection draining

**Hands-on Lab:** Build a multi-tier VPC with public/private subnets, NAT Gateway, and an ALB routing to EC2 instances in private subnets.

---

## Phase 2: Compute & Storage (Weeks 3-4)

**Goal:** Master the core compute and storage services that dominate the exam.

### Week 3 — Compute

- [ ] EC2 Deep Dive
  - Instance types and families (General, Compute, Memory, Storage, Accelerated)
  - Purchase options: On-Demand, Reserved (Standard/Convertible/Scheduled), Spot, Dedicated Hosts/Instances, Savings Plans, Capacity Reservations
  - Placement Groups (Cluster, Spread, Partition)
  - EC2 Instance Store vs EBS
  - User Data & Instance Metadata (169.254.169.254)
  - ENI, ENA, EFA
- [ ] Auto Scaling
  - Launch Templates vs Launch Configurations
  - Scaling policies: Target Tracking, Step, Simple, Scheduled, Predictive
  - Cooldown periods, lifecycle hooks, warm pools
  - Instance refresh, mixed instance policies
- [ ] EBS (Elastic Block Store)
  - Volume types: gp2/gp3, io1/io2 (Block Express), st1, sc1
  - Snapshots (incremental, cross-region copy)
  - Encryption (at-rest with KMS, encrypted snapshots)
  - Multi-Attach (io1/io2 only)
  - RAID 0 vs RAID 1
- [ ] ECS, EKS, Fargate
  - ECS launch types: EC2 vs Fargate
  - Task Definitions, Services, Task Roles
  - Service discovery, load balancer integration
- [ ] AWS Lambda
  - Execution model, concurrency (reserved vs provisioned)
  - Triggers, event sources, destinations
  - Layers, versions, aliases
  - Lambda@Edge vs CloudFront Functions
  - Limits (15 min timeout, 10 GB memory, /tmp 10 GB)
- [ ] Elastic Beanstalk
  - Deployment policies (All at once, Rolling, Rolling with batch, Immutable, Blue/Green)
  - .ebextensions, platform hooks

### Week 4 — Storage

- [ ] S3 Deep Dive
  - Storage Classes: Standard, IA, One Zone-IA, Intelligent-Tiering, Glacier Instant/Flexible/Deep Archive
  - S3 Lifecycle Rules (transition + expiration)
  - S3 Versioning, MFA Delete
  - S3 Replication (CRR vs SRR), Replication Time Control
  - S3 Encryption: SSE-S3, SSE-KMS, SSE-C, Client-side
  - S3 Object Lock (Governance vs Compliance mode, Legal Hold)
  - S3 Access Points, Multi-Region Access Points
  - S3 Presigned URLs, S3 Select, S3 Event Notifications
  - S3 Transfer Acceleration
  - Bucket policies, ACLs, Block Public Access
  - S3 Storage Lens
- [ ] EFS (Elastic File System)
  - Performance modes: General Purpose vs Max I/O
  - Throughput modes: Bursting vs Provisioned vs Elastic
  - Storage classes: Standard, IA (with lifecycle policies)
  - Cross-AZ, cross-region replication
- [ ] FSx
  - FSx for Windows File Server (SMB, Active Directory integration, DFS)
  - FSx for Lustre (HPC, S3 integration, scratch vs persistent)
  - FSx for NetApp ONTAP, FSx for OpenZFS
- [ ] AWS Storage Gateway
  - S3 File Gateway, FSx File Gateway
  - Volume Gateway (Stored vs Cached)
  - Tape Gateway
- [ ] AWS Snow Family
  - Snowcone (8TB / 14TB), Snowball Edge (Storage/Compute Optimized), Snowmobile (100PB)
  - Use cases and data migration thresholds
- [ ] AWS DataSync vs Transfer Family

**Hands-on Lab:** Create an S3 bucket with lifecycle rules, versioning, replication, and different encryption methods. Set up an EFS mount across two EC2 instances.

---

## Phase 3: Databases & Application Integration (Weeks 5-6)

**Goal:** Understand when to use which database and how to decouple architectures.

### Week 5 — Databases

- [ ] RDS (Relational Database Service)
  - Supported engines: MySQL, PostgreSQL, MariaDB, Oracle, SQL Server
  - Multi-AZ (standby, synchronous replication, automatic failover)
  - Read Replicas (async replication, cross-region, up to 15)
  - RDS Proxy (connection pooling, IAM auth, failover)
  - Automated backups, manual snapshots, point-in-time recovery
  - Encryption at rest (KMS) and in transit (SSL/TLS)
  - RDS Custom (Oracle, SQL Server — OS-level access)
- [ ] Aurora
  - MySQL and PostgreSQL compatible
  - 6 copies of data across 3 AZs, self-healing storage
  - Aurora Replicas (up to 15, auto-failover)
  - Aurora Global Database (cross-region, < 1 second replication)
  - Aurora Serverless v2 (auto-scaling ACUs)
  - Aurora Cloning, Backtrack
- [ ] DynamoDB
  - Primary keys: Partition Key, Partition + Sort Key
  - Capacity modes: Provisioned (with Auto Scaling) vs On-Demand
  - LSI vs GSI (when to use each)
  - DynamoDB Streams, TTL
  - DynamoDB Accelerator (DAX) — microsecond reads
  - Global Tables (multi-region, active-active)
  - DynamoDB Transactions
  - Backup: On-demand, PITR
- [ ] ElastiCache
  - Redis vs Memcached (when to use which)
  - Caching strategies: Lazy Loading, Write-Through, TTL
  - Redis: Cluster mode, replication, Multi-AZ, backup/restore
- [ ] Other Databases
  - Redshift (data warehouse, columnar, Spectrum, Serverless)
  - Neptune (graph database)
  - DocumentDB (MongoDB compatible)
  - Keyspaces (Cassandra compatible)
  - QLDB (immutable ledger)
  - Timestream (time series)

### Week 6 — Application Integration & Decoupling

- [ ] SQS (Simple Queue Service)
  - Standard vs FIFO queues
  - Visibility timeout, dead-letter queues, delay queues
  - Long polling vs short polling
  - Message retention (1 min — 14 days, default 4 days)
  - SQS + ASG scaling pattern
- [ ] SNS (Simple Notification Service)
  - Topics, subscriptions, fan-out pattern
  - SNS + SQS fan-out architecture
  - Message filtering, FIFO topics
- [ ] Amazon EventBridge
  - Event buses (default, custom, partner)
  - Rules, targets, event patterns
  - Schema registry, archive and replay
- [ ] Kinesis
  - Kinesis Data Streams (real-time, shards, retention 1-365 days)
  - Kinesis Data Firehose (near real-time, delivery to S3/Redshift/OpenSearch)
  - Kinesis Data Analytics (SQL/Flink on streaming data)
  - Kinesis vs SQS (streaming vs messaging)
- [ ] Step Functions (workflow orchestration, Standard vs Express)
- [ ] API Gateway
  - REST API vs HTTP API vs WebSocket API
  - Stages, deployment, canary
  - Throttling, caching, usage plans, API keys
  - Integration types: Lambda proxy, HTTP, AWS service, Mock
  - Authorizers: IAM, Cognito, Lambda
- [ ] AppSync (managed GraphQL)
- [ ] Amazon MQ (ActiveMQ, RabbitMQ — lift-and-shift messaging)

**Hands-on Lab:** Build an event-driven architecture: API Gateway -> Lambda -> SQS -> Lambda -> DynamoDB, with SNS notifications and a DLQ.

---

## Phase 4: Security & Monitoring (Weeks 7-8)

**Goal:** Master the security services and monitoring/logging that the exam heavily tests.

### Week 7 — Security

- [ ] KMS (Key Management Service)
  - CMK types: AWS managed, Customer managed, AWS owned
  - Symmetric vs Asymmetric keys
  - Key rotation (automatic vs manual)
  - Key policies, grants
  - Envelope encryption
  - KMS multi-region keys
- [ ] CloudHSM (dedicated hardware, FIPS 140-2 Level 3)
- [ ] AWS Secrets Manager vs Systems Manager Parameter Store
  - Automatic rotation (Secrets Manager)
  - Parameter tiers: Standard vs Advanced
- [ ] ACM (AWS Certificate Manager) — free public SSL/TLS certs
- [ ] AWS WAF, Shield (Standard vs Advanced), Firewall Manager
- [ ] Amazon GuardDuty (threat detection, ML-based)
- [ ] Amazon Inspector (vulnerability scanning for EC2, ECR, Lambda)
- [ ] Amazon Macie (S3 sensitive data discovery, PII)
- [ ] AWS Config (compliance auditing, rules, remediation)
- [ ] AWS Security Hub (centralized security findings)
- [ ] Amazon Cognito
  - User Pools (authentication, sign-up/sign-in)
  - Identity Pools (authorization, temporary AWS credentials)
  - Federation (SAML 2.0, OIDC, social identity providers)
- [ ] AWS SSO / IAM Identity Center
- [ ] AWS Network Firewall, AWS Verified Access

### Week 8 — Monitoring, Logging & Management

- [ ] CloudWatch
  - Metrics (standard vs custom, resolution: 1 min vs 1 sec)
  - Alarms (OK, ALARM, INSUFFICIENT_DATA)
  - Logs (Log Groups, Log Streams, Metric Filters, Insights)
  - CloudWatch Agent (memory, disk metrics)
  - Dashboards, Composite Alarms, Anomaly Detection
  - Contributor Insights, ServiceLens
- [ ] CloudTrail
  - Management events vs Data events vs Insights events
  - Multi-region trail, organization trail
  - Log file integrity validation
  - Integration with S3, CloudWatch Logs, EventBridge
- [ ] AWS X-Ray (distributed tracing)
- [ ] VPC Flow Logs (ENI, Subnet, VPC level)
- [ ] AWS Systems Manager
  - Session Manager (SSH without port 22)
  - Patch Manager, Run Command
  - Parameter Store, Automation
  - Inventory, State Manager
- [ ] AWS CloudFormation
  - Templates (JSON/YAML), Stacks, StackSets
  - Intrinsic functions (Ref, Fn::GetAtt, Fn::Join, Fn::Sub, Conditions)
  - Change Sets, Drift Detection, Stack Policies
  - DeletionPolicy (Retain, Snapshot, Delete)
  - cfn-init, cfn-signal, CreationPolicy, WaitCondition
- [ ] AWS Trusted Advisor (5 categories: cost, performance, security, fault tolerance, service limits)
- [ ] AWS Health Dashboard (Personal vs Service)

**Hands-on Lab:** Set up CloudTrail logging to S3, create CloudWatch alarms for EC2 CPU, configure VPC Flow Logs, and use AWS Config to detect non-compliant resources.

---

## Phase 5: Advanced Architectures (Weeks 9-10)

**Goal:** Learn to design complex, real-world architectures using multiple services together.

### Week 9 — Migration & Disaster Recovery

- [ ] Migration Strategies (7 R's)
  - Retire, Retain, Rehost (lift-and-shift), Relocate, Repurchase, Replatform, Refactor
- [ ] AWS Migration Hub, Application Discovery Service
- [ ] AWS DMS (Database Migration Service)
  - Homogeneous vs Heterogeneous migrations
  - SCT (Schema Conversion Tool)
  - Continuous replication (CDC)
- [ ] AWS Application Migration Service (MGN)
- [ ] Disaster Recovery Strategies (know the trade-offs!)
  - **Backup & Restore** — RPO/RTO: hours | lowest cost
  - **Pilot Light** — RPO/RTO: 10s of minutes | core services running
  - **Warm Standby** — RPO/RTO: minutes | scaled-down full system
  - **Multi-Site Active/Active** — RPO/RTO: near-zero | highest cost
- [ ] RTO vs RPO definitions and how each service maps to them

### Week 10 — Hybrid, Edge & Specialty Architectures

- [ ] CloudFront
  - Origins (S3, ALB, EC2, custom HTTP)
  - Origin Access Control (OAC) vs Origin Access Identity (OAI)
  - Cache behaviors, TTL, invalidation
  - Signed URLs vs Signed Cookies
  - Geo restriction, Field-level encryption
  - CloudFront Functions vs Lambda@Edge
- [ ] AWS Global Accelerator (Anycast IP, TCP/UDP, endpoint groups)
  - Global Accelerator vs CloudFront (when to use which)
- [ ] AWS Outposts (AWS infra on-premises)
- [ ] AWS Wavelength (5G edge)
- [ ] AWS Local Zones
- [ ] Hybrid connectivity patterns
  - VPN + Direct Connect as backup
  - Transit Gateway with multiple VPCs
  - Direct Connect Gateway
- [ ] Serverless architecture patterns
  - API Gateway + Lambda + DynamoDB
  - S3 + Lambda + Step Functions
  - EventBridge-driven architectures
  - SQS-based decoupling patterns
- [ ] Container architecture patterns
  - ECS/EKS with Fargate vs EC2
  - Service mesh, service discovery
  - ECR (Elastic Container Registry)
- [ ] Data Analytics Pipeline
  - Kinesis -> S3 -> Athena -> QuickSight
  - Glue (ETL, Data Catalog, Crawlers)
  - Lake Formation
  - EMR (managed Hadoop/Spark)
  - OpenSearch Service

**Hands-on Lab:** Design and deploy a multi-region active-passive architecture with Route 53 failover, Aurora Global Database, and S3 cross-region replication.

---

## Phase 6: Practice & Review (Weeks 11-12)

**Goal:** Test yourself relentlessly and fill knowledge gaps.

### Week 11 — Practice Exams

- [ ] Complete practice exam 1 — review every wrong answer
- [ ] Complete practice exam 2 — identify weak domains
- [ ] Complete practice exam 3 — target score > 80%
- [ ] Review all flagged/uncertain questions
- [ ] Create flashcards for services you confuse

### Week 12 — Final Review & Exam

- [ ] Review all hands-on labs and key architectures
- [ ] Re-read AWS FAQs for top services (S3, EC2, VPC, RDS, Lambda, SQS)
- [ ] Review the AWS Well-Architected Framework whitepaper
- [ ] Quick-review cheat sheet (below)
- [ ] **Take the exam!**

---

## Key Decision Frameworks (Exam Gold)

### Which Database?

| Requirement | Service |
|-------------|---------|
| Relational, managed | RDS |
| Relational, high availability, auto-scaling | Aurora |
| Key-value, millisecond latency | DynamoDB |
| Key-value, microsecond latency | DynamoDB + DAX |
| In-memory cache | ElastiCache |
| Data warehouse, analytics | Redshift |
| Graph relationships | Neptune |
| Document (MongoDB compat) | DocumentDB |
| Immutable ledger | QLDB |
| Time-series | Timestream |
| Full-text search | OpenSearch |

### Which Storage?

| Requirement | Service |
|-------------|---------|
| Object storage | S3 |
| Block storage (single EC2) | EBS |
| Shared file system (Linux) | EFS |
| Shared file system (Windows) | FSx for Windows |
| High-performance computing | FSx for Lustre |
| On-premises hybrid | Storage Gateway |
| Massive data transfer | Snow Family |

### Which Compute?

| Requirement | Service |
|-------------|---------|
| Full OS control | EC2 |
| Containers, managed | ECS/EKS on Fargate |
| Containers, self-managed | ECS/EKS on EC2 |
| Event-driven, short-lived | Lambda |
| Simple web app deployment | Elastic Beanstalk |
| Batch processing | AWS Batch |

### SQS vs SNS vs EventBridge vs Kinesis

| Feature | SQS | SNS | EventBridge | Kinesis |
|---------|-----|-----|-------------|---------|
| Pattern | Queue | Pub/Sub | Event Bus | Stream |
| Consumers | Pull | Push | Push | Pull |
| Ordering | FIFO only | FIFO only | No | Per-shard |
| Replay | No | No | Archive/Replay | Yes (retention) |
| Use case | Decouple, buffer | Fan-out | Event-driven | Real-time analytics |

### Encryption Quick Reference

| Service | At Rest | In Transit |
|---------|---------|------------|
| S3 | SSE-S3, SSE-KMS, SSE-C | HTTPS |
| EBS | KMS (default or CMK) | Encrypted between EC2-EBS |
| RDS | KMS at creation time | SSL/TLS |
| DynamoDB | KMS (AWS owned/managed/CMK) | HTTPS |
| EFS | KMS | TLS mount helper |
| Redshift | KMS or CloudHSM | SSL |

---

## Exam Day Tips

1. **Eliminate wrong answers first** — usually 2 answers are clearly wrong
2. **Watch for keywords:**
   - "Cost-effective" → think Spot, S3 IA, Reserved, right-sizing
   - "Minimal operational overhead" → think managed/serverless services
   - "Least privilege" → most restrictive IAM policy that still works
   - "Decouple" → SQS, SNS, EventBridge
   - "Real-time" → Kinesis Data Streams
   - "Near real-time" → Kinesis Data Firehose
   - "Milliseconds" → DynamoDB
   - "Microseconds" → DAX, ElastiCache
   - "Durability" → S3 (11 9's)
   - "Temporary credentials" → STS, IAM Roles
3. **Flag and move on** — don't spend > 2 minutes on any question
4. **Read the LAST sentence first** — it usually contains the actual question
5. **Multi-AZ ≠ Multi-Region** — understand the distinction
6. **Managed > Self-managed** — AWS almost always prefers managed solutions

---

## Recommended Resources

### Courses
- **Adrian Cantrill** — [learn.cantrill.io](https://learn.cantrill.io) (top-tier, production-level depth)
- **Stephane Maarek** — Udemy SAA course (excellent for exam focus)
- **AWS Skill Builder** — Official AWS training (free tier available)

### Practice Exams
- **Tutorials Dojo** (Jon Bonso) — closest to real exam difficulty
- **AWS Official Practice Exam** — available on AWS Skill Builder
- **Stephane Maarek Practice Exams** — Udemy

### Documentation
- AWS FAQs (S3, EC2, VPC, Lambda, RDS, SQS, DynamoDB)
- AWS Well-Architected Framework Whitepaper
- AWS Architecture Center

### Hands-On
- **AWS Free Tier** — 12 months of free access to core services
- **AWS Workshops** — [workshops.aws](https://workshops.aws)

---

## Progress Tracker

| Week | Phase | Focus | Status |
|------|-------|-------|--------|
| 1 | Foundation | Cloud Fundamentals & IAM | [ ] |
| 2 | Foundation | Networking | [ ] |
| 3 | Compute & Storage | Compute | [ ] |
| 4 | Compute & Storage | Storage | [ ] |
| 5 | Databases & Integration | Databases | [ ] |
| 6 | Databases & Integration | App Integration | [ ] |
| 7 | Security & Monitoring | Security | [ ] |
| 8 | Security & Monitoring | Monitoring & Mgmt | [ ] |
| 9 | Advanced | Migration & DR | [ ] |
| 10 | Advanced | Hybrid, Edge & Patterns | [ ] |
| 11 | Practice | Practice Exams | [ ] |
| 12 | Final Review | Review & Exam Day | [ ] |

---

*Target: 720/1000 to pass. Aim for 800+ to be comfortable. Good luck!*

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Exam Overview
- Exam Domain Breakdown
- Foundation (Weeks 1-2)
- Compute & Storage (Weeks 3-4)

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
