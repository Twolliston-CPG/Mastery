# Amazon Aurora

## What is Aurora?

Amazon Aurora is a cloud-native relational database built by AWS that is compatible with MySQL and PostgreSQL. It delivers up to 5x the throughput of standard MySQL and 3x the throughput of standard PostgreSQL, with a storage layer designed for high availability and durability.

Aurora is still part of the RDS family -- you manage it through the RDS console and APIs -- but it has a fundamentally different storage architecture.

---

## Storage Architecture

This is what makes Aurora special and what the exam tests heavily.

### Key Facts
- Data is automatically replicated **6 copies across 3 Availability Zones** (2 copies per AZ).
- Aurora needs only **4 out of 6 copies for writes** and **3 out of 6 for reads**.
- This means Aurora can:
  - Lose an entire AZ and still write.
  - Lose an entire AZ plus one more copy and still read.
- Storage is **self-healing**: if a copy is corrupted, Aurora automatically detects and repairs it using data from the other copies.
- Storage is organized into **10 GB segments** called "Protection Groups," spread across many physical disks.
- Storage **auto-scales** from 10 GB up to 128 TB. You never need to provision storage.

> **Exam tip:** "6 copies across 3 AZs" and "self-healing storage" are Aurora's defining characteristics. If a question describes this pattern, the answer is Aurora.

---

## Aurora Replicas

| Feature | Detail |
|---|---|
| **Max replicas** | Up to 15 Aurora Replicas |
| **Replication lag** | Typically < 10 ms (shares the same storage volume) |
| **Automatic failover** | Yes -- Aurora promotes a replica if the primary fails |
| **Failover priority** | Configurable tiers (0-15); lower tier = higher priority |
| **Endpoint** | Reader endpoint load-balances across all replicas |
| **Cross-Region** | Use Aurora Global Database (see below) |

### Aurora Endpoints

| Endpoint | Purpose |
|---|---|
| **Cluster (Writer) endpoint** | Points to the current primary instance. Used for writes. |
| **Reader endpoint** | Load-balances connections across all Aurora Replicas. Used for reads. |
| **Custom endpoint** | Points to a subset of instances (e.g., larger instances for analytics). |
| **Instance endpoint** | Direct connection to a specific instance (rarely used). |

---

## Aurora Global Database

Aurora Global Database allows a single Aurora database to span multiple AWS Regions.

### Key Facts
- **Primary Region:** One primary cluster handles all writes.
- **Secondary Regions:** Up to 5 secondary Regions, each with up to 16 read replicas.
- **Replication lag:** Typically **less than 1 second** across Regions.
- **Promotion:** A secondary Region can be promoted to become the new primary in under 1 minute (for disaster recovery).
- **Use case:** Low-latency global reads and cross-Region disaster recovery.

> **Exam tip:** "Cross-Region reads with < 1 second lag" or "cross-Region disaster recovery for Aurora" -> Aurora Global Database. Do NOT confuse with Aurora Read Replicas (same Region) or RDS Cross-Region Read Replicas (asynchronous, higher lag).

---

## Aurora Serverless v2

Aurora Serverless v2 automatically scales compute capacity based on application demand.

### Key Facts
- Capacity scales in **Aurora Capacity Units (ACUs)**. Each ACU is approximately 2 GB of memory.
- You set a **minimum and maximum ACU** range (e.g., 0.5 to 128 ACUs).
- Scaling is **instant** -- no warm-up or cool-down delays.
- Supports **Multi-AZ**, Read Replicas, and Global Database.
- Billed **per ACU-hour** consumed (pay for what you use).

### When to Use Aurora Serverless v2
- Variable or unpredictable workloads.
- Development and test environments that are idle much of the day.
- Multi-tenant SaaS applications with varying per-tenant load.
- New applications where you cannot predict capacity needs.

> **Exam tip:** "Unpredictable workload" + "relational database" + "cost-effective" -> Aurora Serverless v2.

---

## Aurora Cloning

- Creates a new Aurora cluster from an existing one using **copy-on-write** protocol.
- Initially, the clone shares the same underlying data as the source (no data copy).
- Data is only copied when pages are modified in the clone.
- **Much faster and cheaper** than restoring from a snapshot.
- Use case: Create a staging or test environment from production data without affecting the production cluster.

> **Exam tip:** "Create a test copy of production Aurora database quickly and cheaply" -> Aurora Cloning.

---

## Aurora Backtrack

- Rewinds the Aurora cluster to a specific point in time **without creating a new cluster**.
- Available for **Aurora MySQL only** (not PostgreSQL).
- Must be enabled at cluster creation time.
- **Backtrack window:** Up to 72 hours.
- Does NOT work with Aurora Global Database or Multi-Master.
- Use case: Quickly undo a mistaken DELETE or UPDATE without a full restore.

> **Exam tip:** "Quickly undo an accidental data change on Aurora MySQL" -> Backtrack. If it says PostgreSQL, you must use PITR (creates a new cluster).

---

## Aurora vs Standard RDS -- Comparison Table

| Feature | Standard RDS | Aurora |
|---|---|---|
| **Engines** | MySQL, PostgreSQL, MariaDB, Oracle, SQL Server | MySQL-compatible, PostgreSQL-compatible only |
| **Storage replication** | Single AZ or 2 AZs (Multi-AZ) | 6 copies across 3 AZs (always) |
| **Storage scaling** | Manual (provision up to 64 TB) | Automatic (up to 128 TB) |
| **Self-healing storage** | No | Yes |
| **Max Read Replicas** | 5 | 15 |
| **Replication type** | Asynchronous (separate storage) | Shared storage (< 10 ms lag) |
| **Automatic failover** | Multi-AZ only (60-120 sec) | Always (< 30 sec with replicas) |
| **Global Database** | No (use cross-Region Read Replicas) | Yes (< 1 sec replication) |
| **Serverless option** | No | Aurora Serverless v2 |
| **Backtrack** | No | Yes (MySQL only) |
| **Cloning** | No (use snapshot + restore) | Yes (copy-on-write, fast) |
| **Performance** | Baseline | Up to 5x MySQL, 3x PostgreSQL |
| **Cost** | Lower starting price | ~20% more than RDS MySQL, but includes replication |
| **Free Tier** | Yes (db.t3.micro) | No |

---

## Aurora Pricing Considerations (Budget-Conscious)

- **No Free Tier** for Aurora. The smallest instance (db.t3.medium) costs approximately $0.041/hour (~$30/month).
- **Aurora Serverless v2:** Minimum 0.5 ACU = ~$0.06/hour. Useful for dev/test if you set a low max.
- **Storage:** $0.10/GB/month. Auto-scales so you only pay for what you use.
- **I/O charges:** Aurora Standard charges per million I/O requests. Aurora I/O-Optimized has no I/O charges but higher instance cost.

> **Lab tip:** For study purposes, use standard RDS MySQL (Free Tier) for hands-on work. Read and understand Aurora's architecture conceptually. If you want to briefly test Aurora, use Aurora Serverless v2 with a low max ACU and delete within an hour.

---

## Key Exam Scenarios

| Scenario | Answer |
|---|---|
| "High availability relational DB with auto-scaling storage" | Aurora |
| "MySQL database with 15 read replicas" | Aurora (RDS MySQL maxes at 5) |
| "Cross-Region DR for relational database with < 1 sec lag" | Aurora Global Database |
| "Variable workload, relational, minimize cost when idle" | Aurora Serverless v2 |
| "Create a test copy of production DB quickly" | Aurora Cloning |
| "Undo accidental DELETE on Aurora MySQL" | Backtrack |
| "Undo accidental DELETE on Aurora PostgreSQL" | PITR (restore to new cluster) |
| "Need Oracle or SQL Server" | RDS (Aurora does not support these) |
| "Relational database, absolute lowest cost, Free Tier" | Standard RDS (not Aurora) |
| "Self-healing storage, 6 copies across 3 AZs" | Aurora |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What is Aurora?
- Storage Architecture
- Aurora Replicas
- Aurora Global Database

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
