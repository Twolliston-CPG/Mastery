# Disaster Recovery (DR) on AWS

## Why This Matters for the Exam

Disaster Recovery is one of the most heavily tested topics on the SAA-C03. You will see 4-6 questions requiring you to select the correct DR strategy based on RPO/RTO requirements and budget constraints. Memorize the four strategies, their RPO/RTO ranges, and the cost trade-offs.

---

## Key Definitions

### RPO -- Recovery Point Objective

**"How much data can you afford to lose?"**

RPO measures the maximum acceptable amount of data loss, expressed as time. If your RPO is 1 hour, you can tolerate losing up to 1 hour of data.

```
          RPO
  <------------------>
  Last Backup         Disaster         Now
      |                  |               |
  Data since last    Data in this    Recovery
  backup is SAFE     window is LOST  starts here
```

- RPO = 0: No data loss acceptable (synchronous replication required).
- RPO = 1 hour: You need backups or replication at least every hour.
- RPO = 24 hours: Daily backups are sufficient.

### RTO -- Recovery Time Objective

**"How long can your application be down?"**

RTO measures the maximum acceptable downtime from the moment of failure to the moment the application is fully operational again.

```
                          RTO
                 <-------------------->
  Disaster       Recovery Starts       Application
  Occurs         (restore, failover)   Fully Online
     |                  |                    |
```

- RTO = 0: No downtime acceptable (active/active required).
- RTO = 15 minutes: Warm standby or multi-site.
- RTO = 4 hours: Pilot light is sufficient.
- RTO = 24 hours: Backup and restore is sufficient.

---

## The Four DR Strategies

### Strategy Comparison Table

| Attribute | Backup & Restore | Pilot Light | Warm Standby | Multi-Site Active/Active |
|---|---|---|---|---|
| **RPO** | Hours | 10s of minutes | Minutes | Near-zero / seconds |
| **RTO** | Hours (up to 24h) | 10s of minutes | Minutes | Near-zero / seconds |
| **Cost** | $ (lowest) | $$ | $$$ | $$$$ (highest) |
| **Complexity** | Low | Medium | Medium-High | High |
| **Data replication** | Periodic backups | Continuous (core data) | Continuous (full) | Continuous (full, bidirectional) |
| **Infra in DR region** | None (or minimal storage) | Core services only (stopped/minimal) | Scaled-down full environment | Full-scale duplicate |
| **Failover method** | Restore from backups | Start stopped resources, promote replicas | Scale up existing resources | Route 53 routes traffic automatically |
| **Failover time** | Hours | 10-30 minutes | 1-10 minutes | Seconds (automatic) |
| **Best for** | Non-critical workloads | Business-critical with moderate RTO | Production systems needing fast recovery | Mission-critical, zero-downtime |

---

### 1. Backup & Restore

**How it works:** Take regular backups of data and infrastructure configurations. Store backups in another region. When disaster strikes, restore from backups in the DR region.

**Architecture:**

```
PRIMARY REGION (us-east-1)                    DR REGION (us-west-2)
+---------------------------+                 +---------------------------+
|  VPC                      |                 |                           |
|  +-------+  +----------+ |   Backups       |  S3 Bucket (backups)      |
|  |  EC2  |  | RDS (DB) | | ------------->  |  AMIs (copied)            |
|  +-------+  +----------+ |   (periodic)    |  RDS Snapshots (copied)   |
|  +-------+               |                 |  EBS Snapshots (copied)   |
|  |  S3   |               |                 |                           |
|  +-------+               |                 |  (No running infra)       |
+---------------------------+                 +---------------------------+
```

**What runs in the DR region during normal operation:** Nothing (or just S3 for backup storage). No EC2 instances, no databases, no load balancers.

**Recovery process:**
1. Restore RDS from cross-region snapshot.
2. Launch EC2 instances from copied AMIs.
3. Deploy application and configure.
4. Update DNS to point to DR region.

**AWS services used:**
- S3 cross-region replication or S3 backup storage
- RDS automated backups + cross-region snapshot copy
- EBS snapshots copied cross-region
- AMI copy cross-region
- AWS Backup (centralized backup management)
- CloudFormation / Terraform (infrastructure-as-code for fast rebuild)

**Cost:** Only pay for backup storage (S3, snapshot storage). No running compute in DR region.

**Exam tip:** If the question mentions "lowest cost DR" or "non-critical workloads with relaxed RTO," Backup & Restore is the answer.

---

### 2. Pilot Light

**How it works:** Keep the core (critical) components of the system always running in the DR region, but in a minimal/stopped state. The "pilot light" is like a gas furnace pilot light -- a small flame that can quickly ignite the full system.

**Architecture:**

```
PRIMARY REGION (us-east-1)                    DR REGION (us-west-2)
+---------------------------+                 +---------------------------+
|  VPC                      |                 |  VPC                      |
|  +-------+  +----------+ |  Continuous     |            +----------+   |
|  |  ALB  |  | RDS      | |  replication    |            | RDS Read |   |
|  +-------+  | (Primary)| | ------------->  |            | Replica  |   |
|  +-------+  +----------+ |                 |            +----------+   |
|  |  EC2  |               |                 |                           |
|  |  (ASG)|  +----------+ |                 |  AMIs ready               |
|  +-------+  |   S3     | |                 |  ASG config ready         |
|             +----------+ |                 |  ALB config ready         |
+---------------------------+                 |  (EC2 NOT running)        |
        ^                                     +---------------------------+
        |
   Route 53 (Active)
```

**What runs in the DR region during normal operation:**
- RDS read replica (continuously synced).
- AMIs and launch templates are pre-configured.
- VPC, subnets, security groups are pre-created.
- EC2 instances are NOT running (or in stopped state).
- ALB is NOT running.

**Recovery process:**
1. Promote RDS read replica to standalone primary.
2. Launch EC2 instances from AMIs (or start stopped instances).
3. Create/start ALB and register targets.
4. Scale ASG to production capacity.
5. Update Route 53 to point to DR region (failover record).

**AWS services used:**
- RDS read replica (cross-region, continuously synced)
- AMI (pre-built, ready to launch)
- Auto Scaling Group (pre-configured, desired capacity = 0)
- Route 53 failover routing
- CloudFormation / Terraform

**Cost:** Pay for RDS read replica (running continuously) and snapshot/AMI storage. No compute cost for EC2 until failover.

**Exam tip:** "Core infrastructure always running, scale up during disaster" = Pilot Light. The keyword is "core" or "critical data replicated."

---

### 3. Warm Standby

**How it works:** Run a scaled-down but fully functional copy of the production environment in the DR region. The DR environment can handle a reduced level of traffic. During a disaster, scale it up to production capacity.

**Architecture:**

```
PRIMARY REGION (us-east-1)                    DR REGION (us-west-2)
+---------------------------+                 +---------------------------+
|  VPC                      |                 |  VPC                      |
|  +-------+  +----------+ |  Continuous     |  +-------+  +----------+  |
|  |  ALB  |  | RDS      | |  replication    |  |  ALB  |  | RDS Read |  |
|  +-------+  | (Primary)| | ------------->  |  +-------+  | Replica  |  |
|  +-------+  +----------+ |                 |  +-------+  +----------+  |
|  |  EC2  |               |                 |  |  EC2  |                 |
|  | (ASG  |               |                 |  | (ASG  |                 |
|  | 4 inst)|              |                 |  | 1 inst)|                |
|  +-------+               |                 |  +-------+                 |
+---------------------------+                 +---------------------------+
        ^                                            ^
        |            Route 53 Failover               |
        +--------------------------------------------+
              (Primary)                  (Secondary)
```

**What runs in the DR region during normal operation:**
- Full environment but at **minimum scale**.
- ALB is running.
- ASG is running with minimum instances (e.g., 1 instead of 4).
- RDS read replica is running.
- Application is deployed and functional (can serve some traffic).

**Recovery process:**
1. Promote RDS read replica to standalone primary.
2. Scale ASG to production capacity.
3. Route 53 failover routing automatically redirects traffic.

**AWS services used:**
- RDS read replica (cross-region)
- ALB (running in DR region)
- ASG (running at minimum capacity)
- Route 53 failover routing with health checks
- CloudWatch alarms to trigger scaling

**Cost:** Higher than pilot light -- paying for running ALB, minimum EC2 instances, and RDS read replica continuously.

**Exam tip:** "Scaled-down but fully functional copy" = Warm Standby. The key difference from pilot light is that the DR environment IS running and CAN serve traffic (just at reduced capacity).

---

### 4. Multi-Site Active/Active

**How it works:** Run full production environments in two (or more) regions simultaneously. Both regions actively serve traffic. Route 53 distributes traffic across regions. If one region fails, the other absorbs all traffic.

**Architecture:**

```
PRIMARY REGION (us-east-1)                    SECONDARY REGION (us-west-2)
+---------------------------+                 +---------------------------+
|  VPC                      |                 |  VPC                      |
|  +-------+  +----------+ |  Bidirectional  |  +-------+  +----------+  |
|  |  ALB  |  | Aurora    | |  replication    |  |  ALB  |  | Aurora    | |
|  +-------+  | Global DB | | <============>  |  +-------+  | Global DB | |
|  +-------+  | (Writer)  | |                 |  +-------+  | (Reader)  | |
|  |  EC2  |  +----------+ |                 |  |  EC2  |  +----------+  |
|  | (ASG  |               |                 |  | (ASG  |                 |
|  | 4 inst)|              |                 |  | 4 inst)|                |
|  +-------+               |                 |  +-------+                 |
+---------------------------+                 +---------------------------+
        ^                                            ^
        |       Route 53 Latency/Weighted            |
        +--------------------------------------------+
        (50% traffic)                    (50% traffic)
```

**What runs in the DR region during normal operation:**
- Full production-scale environment.
- Full compute capacity.
- Aurora Global Database (reader in secondary, can be promoted to writer in < 1 minute).
- Both regions actively serving traffic.

**Recovery process:**
1. Route 53 health check detects primary region failure.
2. Route 53 automatically routes all traffic to the healthy region.
3. Promote Aurora Global Database secondary to writer (if using Aurora).
4. Scale up the surviving region if needed (ASG handles this).

**AWS services used:**
- Aurora Global Database (< 1 second cross-region replication)
- DynamoDB Global Tables (active-active, multi-region)
- Route 53 (latency-based, weighted, or failover routing)
- CloudFront (edge caching reduces origin load)
- S3 cross-region replication

**Cost:** Highest -- paying for full infrastructure in both regions at all times.

**Exam tip:** "Near-zero RPO and RTO," "mission-critical," or "no downtime acceptable" = Multi-Site Active/Active.

---

## Mapping AWS Services to DR Strategies

| AWS Service | Backup & Restore | Pilot Light | Warm Standby | Active/Active |
|---|---|---|---|---|
| **Route 53** | Update manually | Failover routing | Failover routing | Latency/Weighted routing |
| **EC2 / ASG** | Launch from AMI | AMI ready, ASG desired=0 | ASG running (min scale) | ASG running (full scale) |
| **RDS** | Restore from snapshot | Read replica (cross-region) | Read replica (cross-region) | Aurora Global DB |
| **Aurora** | Restore from snapshot | Aurora replica (cross-region) | Aurora replica | Aurora Global DB |
| **DynamoDB** | On-demand backup, PITR | Global Tables (overkill) | Global Tables | Global Tables |
| **S3** | Cross-region replication | Cross-region replication | Cross-region replication | Cross-region replication |
| **EBS** | Snapshot copy cross-region | Snapshot copy | Snapshot copy | Continuous replication |
| **CloudFormation** | Store templates in S3 | Pre-deploy core infra | Full stack deployed | Full stack deployed |

---

## Cost Comparison (Approximate Monthly for a Medium Workload)

| Strategy | Monthly DR Cost (in addition to primary) | Relative Cost |
|---|---|---|
| Backup & Restore | $50-200 (storage only) | 1x |
| Pilot Light | $200-800 (DB replica + storage) | 3-4x |
| Warm Standby | $800-3,000 (reduced infra running) | 8-15x |
| Multi-Site Active/Active | $3,000-10,000+ (full duplicate) | 30-50x |

---

## DR Strategy Decision Flowchart

```
Start: What are the RPO/RTO requirements?
  |
  +--> RPO: Hours, RTO: Hours (24h acceptable)?
  |      |
  |      +-- Yes --> BACKUP & RESTORE ($)
  |      +-- No  --> Continue
  |
  +--> RPO: 10s of min, RTO: 10s of min?
  |      |
  |      +-- Yes --> PILOT LIGHT ($$)
  |      +-- No  --> Continue
  |
  +--> RPO: Minutes, RTO: Minutes?
  |      |
  |      +-- Yes --> WARM STANDBY ($$$)
  |      +-- No  --> Continue
  |
  +--> RPO: Near-zero, RTO: Near-zero?
         |
         +-- Yes --> MULTI-SITE ACTIVE/ACTIVE ($$$$)
```

**Secondary decision factor: Budget.**
- If budget is constrained and RTO is flexible, choose the cheapest strategy that meets RPO.
- If the question says "cost-effective" or "minimize cost," choose the least expensive strategy that still meets the stated RPO/RTO.

---

## Exam Scenarios

| Scenario | Answer |
|---|---|
| "Company needs DR for non-critical internal tools. Budget is limited. 24-hour RTO is acceptable." | Backup & Restore |
| "E-commerce site needs to recover within 30 minutes. Willing to pay for DB replication." | Pilot Light |
| "Financial trading platform needs recovery within 5 minutes." | Warm Standby |
| "Global SaaS platform cannot tolerate any downtime. Users are worldwide." | Multi-Site Active/Active |
| "Which is the MOST cost-effective DR strategy that meets a 1-hour RTO?" | Pilot Light |
| "Company wants to minimize RPO for their Aurora database across regions." | Aurora Global Database (< 1s replication lag) |

---

## Key Takeaways

1. **Know the four strategies cold:** Backup & Restore < Pilot Light < Warm Standby < Multi-Site Active/Active (in order of cost, complexity, and speed).
2. **RPO = data loss tolerance, RTO = downtime tolerance.** Every DR question revolves around these two numbers.
3. **The exam always wants the MOST COST-EFFECTIVE strategy** that still meets the RPO/RTO requirements. Never over-engineer.
4. **Aurora Global Database is the gold standard** for multi-region database DR (< 1 second replication, < 1 minute failover).
5. **Route 53 failover routing** is the DNS mechanism that enables all DR strategies except backup & restore (which typically requires manual DNS updates).
6. **Pilot light vs warm standby:** The key difference is whether the DR environment can serve traffic NOW. Pilot light = no (must start resources). Warm standby = yes (already serving at reduced capacity).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Key Definitions
- The Four DR Strategies
- Mapping AWS Services to DR Strategies
- Cost Comparison (Approximate Monthly for a Medium Workload)

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
