# Migration Strategies

## Why This Matters for the Exam

Migration is tested across multiple domains of the SAA-C03. You will see scenario questions like "A company wants to move their on-premises Oracle database to AWS with minimal changes -- which approach should they use?" Understanding the 7 R's, DMS, and MGN lets you quickly eliminate wrong answers.

---

## The 7 R's of Cloud Migration

AWS defines seven migration strategies, ordered from least effort/change to most effort/change:

### 1. Retire

**What:** Turn off applications that are no longer needed.

**When to use:**
- Application is redundant (replaced by another system).
- Low or zero usage after discovery assessment.
- Costs more to maintain than the value it provides.

**Example:** A legacy reporting tool that only 3 people used, now replaced by QuickSight dashboards.

**AWS Services:** Application Discovery Service (identifies usage patterns to justify retirement).

---

### 2. Retain (Revisit)

**What:** Keep the application where it is, for now. Plan to revisit later.

**When to use:**
- Application has unresolved compliance requirements preventing migration.
- Recently upgraded on-premises -- migration not cost-effective yet.
- Complex dependencies that need more planning.
- Not a priority in this migration wave.

**Example:** A mainframe COBOL application with deep integrations -- plan to refactor in a future phase.

**AWS Services:** Migration Hub (tracks which apps are retained and their future plans).

---

### 3. Rehost (Lift and Shift)

**What:** Move the application as-is to AWS without code changes. Essentially re-creating the same environment in the cloud.

**When to use:**
- Large-scale migrations with tight timelines.
- Applications that work fine but need to leave the data center.
- Organization wants quick wins to build cloud confidence.
- When optimizing later (after migration) is acceptable.

**Example:** Move a fleet of 200 Linux VMs from VMware to EC2 instances using AWS MGN.

**AWS Services:**
- **AWS Application Migration Service (MGN)** -- automated lift-and-shift for servers.
- **AWS Migration Hub** -- central tracking.
- **CloudEndure Migration** (legacy, now consolidated into MGN).

**Exam tip:** Rehost is the fastest migration strategy. If the question says "minimal changes" or "migrate quickly," think rehost.

---

### 4. Relocate

**What:** Move infrastructure to AWS without purchasing new hardware, modifying applications, or changing the existing operations model. Specific to VMware workloads moving to VMware Cloud on AWS.

**When to use:**
- Running VMware on-premises and want to keep the same VMware tooling.
- Data center lease expiring, need to move quickly.
- Want to maintain the same operational model.

**Example:** Migrate VMware vSphere workloads to VMware Cloud on AWS without converting VMs.

**AWS Services:** VMware Cloud on AWS.

**Exam tip:** Relocate is specifically about VMware-to-VMware Cloud on AWS. If the question does not mention VMware, this is not the answer.

---

### 5. Repurchase (Drop and Shop)

**What:** Replace the application with a different product, typically a SaaS offering.

**When to use:**
- Existing application is end-of-life or unsupported.
- A SaaS equivalent exists that is cheaper/better.
- Organization wants to eliminate operational burden of running the software.

**Example:** Replace on-premises Microsoft Exchange with Microsoft 365, or replace a self-managed CRM with Salesforce.

**AWS Services:** AWS Marketplace (find SaaS replacements).

**Exam tip:** Repurchase means buying a new SaaS product, not buying the same product again.

---

### 6. Replatform (Lift, Tinker, and Shift)

**What:** Move to AWS with a few targeted optimizations, but without changing the core architecture.

**When to use:**
- Want some cloud benefits without a full rewrite.
- Database can be moved to RDS instead of self-managed on EC2.
- Application can use ELB instead of a self-managed load balancer.
- Want managed services where they are easy drop-in replacements.

**Example:** Move a self-managed MySQL on Linux to Amazon RDS for MySQL. The application code stays the same -- just the connection string changes.

**AWS Services:**
- **AWS DMS** -- migrate databases with minimal downtime.
- **Elastic Beanstalk** -- deploy the same app code with managed infrastructure.
- **Amazon RDS** -- managed database replacing self-managed.

**Exam tip:** Replatform = same application, slightly different platform. If the question says "minimize code changes but take advantage of managed services," think replatform.

---

### 7. Refactor / Re-architect

**What:** Redesign the application from the ground up to be cloud-native, leveraging services like Lambda, DynamoDB, and SQS.

**When to use:**
- Application cannot meet current business requirements in its existing form.
- Want to leverage serverless, microservices, or event-driven architecture.
- Long-term cost savings and agility justify the upfront investment.
- Application needs to scale dramatically beyond current design.

**Example:** Break a monolithic Java EE application into microservices running on ECS/Fargate with an API Gateway frontend and DynamoDB backend.

**AWS Services:** Lambda, API Gateway, DynamoDB, SQS, SNS, ECS/EKS, Step Functions -- essentially the full AWS serverless and container toolkit.

**Exam tip:** Refactor is the most expensive and time-consuming strategy, but provides the most long-term benefit. If the question emphasizes "cloud-native," "microservices," or "maximize agility," think refactor.

---

## 7 R's Decision Flowchart (Text)

```
Start: Assess each application
  |
  +--> Is the application still needed?
  |      |
  |      +-- No  --> RETIRE
  |      +-- Yes --> Continue
  |
  +--> Can we migrate it now?
  |      |
  |      +-- No (compliance, complexity, timing) --> RETAIN
  |      +-- Yes --> Continue
  |
  +--> Is there a SaaS replacement that's better/cheaper?
  |      |
  |      +-- Yes --> REPURCHASE
  |      +-- No  --> Continue
  |
  +--> Does it run on VMware and we want to keep VMware tooling?
  |      |
  |      +-- Yes --> RELOCATE (VMware Cloud on AWS)
  |      +-- No  --> Continue
  |
  +--> Do we need to fundamentally redesign the application?
  |      |
  |      +-- Yes (cloud-native, microservices needed) --> REFACTOR
  |      +-- No  --> Continue
  |
  +--> Can we make small optimizations (e.g., move DB to RDS)?
  |      |
  |      +-- Yes --> REPLATFORM
  |      +-- No  --> REHOST (lift and shift as-is)
```

---

## AWS Migration Hub

**What it does:** Central dashboard to track the progress of migrations across multiple AWS tools and partner solutions.

**Key features:**
- Aggregates migration status from MGN, DMS, and other tools.
- Groups servers into applications for tracking.
- Does NOT perform migration itself -- it is a tracking/visibility tool.

**Exam tip:** If a question asks about "tracking migration progress" or "single place to view all migrations," the answer is Migration Hub.

---

## AWS Application Discovery Service

**What it does:** Collects information about on-premises servers to help plan a migration.

**Two modes:**

| Feature | Agentless Discovery | Agent-Based Discovery |
|---|---|---|
| How it works | OVA deployed in VMware vCenter | Agent installed on each server |
| Data collected | VM inventory, CPU, memory, disk, network | Same + running processes, network connections, system performance |
| Best for | Quick inventory of VMware environments | Detailed dependency mapping |
| Dependency mapping | No | Yes |

**Exam tip:** If the question asks about "understanding dependencies between servers before migration," the answer is Application Discovery Service with agent-based discovery.

---

## AWS Database Migration Service (DMS)

DMS migrates databases to AWS with minimal downtime. The source database remains fully operational during migration.

### How DMS Works

1. Create a **replication instance** (EC2 instance managed by DMS).
2. Define **source endpoint** (on-premises or cloud database).
3. Define **target endpoint** (AWS database).
4. Create a **migration task** (full load, CDC, or both).

### Homogeneous vs Heterogeneous Migrations

| Type | Example | SCT Required? | Complexity |
|---|---|---|---|
| **Homogeneous** | Oracle -> Oracle on RDS | No | Lower |
| **Homogeneous** | MySQL -> Aurora MySQL | No | Lower |
| **Heterogeneous** | Oracle -> Aurora PostgreSQL | **Yes** | Higher |
| **Heterogeneous** | SQL Server -> Aurora MySQL | **Yes** | Higher |

### Schema Conversion Tool (SCT)

- Required for **heterogeneous** migrations (different source and target engines).
- Converts database schema, views, stored procedures, and functions.
- Highlights items that cannot be automatically converted (requires manual intervention).
- Runs as a desktop application (not a cloud service).

**Exam tip:** If source and target are the same engine family, SCT is NOT needed. If they are different engines, SCT IS needed.

### Change Data Capture (CDC)

- Captures ongoing changes to the source database during and after the initial full load.
- Enables near-zero downtime migration.
- DMS reads the source database's transaction log to replicate changes.
- Can be used for **continuous replication** (not just one-time migration).

### DMS Migration Types

| Type | Description | Use Case |
|---|---|---|
| **Full load** | Migrate all existing data | One-time migration |
| **Full load + CDC** | Migrate existing data, then replicate ongoing changes | Migration with minimal downtime |
| **CDC only** | Only replicate ongoing changes | Already loaded data via another method |

### Key DMS Exam Facts

- DMS replication instance must be in the same VPC or have network access to source/target.
- Supports multi-AZ for the replication instance (high availability).
- Can migrate to S3 (as a target) for data lake scenarios.
- Can migrate from S3 (as a source) into a database.
- Supports snowball edge for large-scale data migrations (DMS + Snowball Edge integration).

---

## AWS Application Migration Service (MGN)

**What it does:** Automated lift-and-shift (rehost) migration service for physical, virtual, and cloud servers to AWS.

### How MGN Works

1. Install the **AWS Replication Agent** on each source server.
2. Agent performs **continuous block-level replication** to a staging area in AWS (lightweight EC2 instances with EBS volumes).
3. When ready, perform a **test launch** (creates EC2 instances from replicated data).
4. Validate the test, then perform a **cutover launch** (production).
5. Decommission the source server.

### Key MGN Features

| Feature | Detail |
|---|---|
| Replication | Continuous block-level, not snapshot-based |
| Downtime | Minutes (during final cutover) |
| OS support | Linux and Windows |
| Testing | Non-disruptive test launches |
| Automation | Launch templates, post-launch actions |
| Cost | Free for MGN service; pay for staging/launched EC2 and EBS |

### MGN vs DMS

| Aspect | MGN | DMS |
|---|---|---|
| What it migrates | Entire servers (OS + apps + data) | Databases only |
| Strategy | Rehost (lift and shift) | Replatform (database migration) |
| Agent required | Yes (on source server) | No (replication instance in AWS) |
| Continuous replication | Block-level | Transaction log (CDC) |

**Exam tip:** If the question says "migrate servers" or "lift and shift," the answer is MGN. If the question says "migrate a database," the answer is DMS.

---

## Migration Patterns -- Exam Scenarios

| Scenario | Strategy | Key Service |
|---|---|---|
| "Move 500 servers to AWS quickly with minimal changes" | Rehost | MGN |
| "Move Oracle DB to Aurora PostgreSQL" | Replatform | DMS + SCT |
| "Move MySQL to Aurora MySQL" | Replatform | DMS (no SCT) |
| "Replace on-prem email server with SaaS" | Repurchase | N/A |
| "Redesign monolith as microservices" | Refactor | Lambda, ECS, API GW |
| "Move VMware workloads keeping same tooling" | Relocate | VMware Cloud on AWS |
| "Shut down unused legacy application" | Retire | Application Discovery |
| "Keep mainframe for now, migrate later" | Retain | Migration Hub |

---

## Key Takeaways

1. **7 R's from least to most change:** Retire, Retain, Rehost, Relocate, Repurchase, Replatform, Refactor.
2. **MGN = servers, DMS = databases.** Do not confuse them.
3. **SCT is only needed for heterogeneous database migrations** (different engines).
4. **CDC enables near-zero downtime** for database migrations.
5. **Migration Hub is for tracking**, not for performing migrations.
6. **Application Discovery Service (agent-based) is for dependency mapping** before migration.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The 7 R's of Cloud Migration
- 7 R's Decision Flowchart (Text)
- AWS Migration Hub
- AWS Application Discovery Service

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
