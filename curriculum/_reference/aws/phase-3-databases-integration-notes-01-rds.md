# Amazon RDS (Relational Database Service)

## What is RDS?

Amazon RDS is a managed relational database service that handles provisioning, patching, backups, and failover so you can focus on your application. You choose the engine, instance size, and storage -- AWS manages the rest.

> **Exam tip:** RDS is "managed" but you still do NOT have SSH/OS access (except with RDS Custom). If a question mentions needing OS-level access for a relational database, think RDS Custom.

---

## Supported Engines

| Engine | Key Notes |
|---|---|
| **MySQL** | Most popular open-source RDBMS. Community Edition. |
| **PostgreSQL** | Advanced open-source with JSON support, extensions. |
| **MariaDB** | MySQL fork. Community-driven. |
| **Oracle** | Enterprise. Bring-your-own-license (BYOL) or License Included. |
| **SQL Server** | Microsoft. License Included or BYOL. |
| **Amazon Aurora** | AWS proprietary (covered in note 02). MySQL and PostgreSQL compatible. |

> **Exam tip:** If the question says "open source" and "relational," think MySQL, PostgreSQL, or MariaDB on RDS. If it says "Oracle" or "SQL Server" and needs OS access, think RDS Custom.

---

## Multi-AZ Deployments (High Availability)

Multi-AZ is designed for **high availability**, NOT read scaling.

### How It Works
1. AWS provisions a **standby replica** in a different Availability Zone.
2. Data is replicated **synchronously** from primary to standby.
3. Both instances share a **single DNS endpoint**. The DNS automatically fails over.
4. **Automatic failover** triggers on: AZ failure, primary instance failure, storage failure, or during maintenance windows.
5. Failover typically takes **60-120 seconds**.

### Multi-AZ Deployment Options

| Feature | Multi-AZ Instance (Classic) | Multi-AZ Cluster (New) |
|---|---|---|
| **Standby instances** | 1 standby (not readable) | 2 readable standbys |
| **Replication** | Synchronous | Semi-synchronous |
| **Failover time** | ~60-120 seconds | ~35 seconds |
| **Read from standby?** | No | Yes (reader endpoint) |
| **Engines supported** | All engines | MySQL, PostgreSQL only |
| **Endpoints** | 1 (single DNS) | 3 (writer, reader, instance) |

> **Exam tip:** Classic Multi-AZ standby is NOT readable. If you need to read from it, use Multi-AZ DB Cluster or Read Replicas.

---

## Read Replicas (Read Scaling)

Read Replicas are designed for **read scaling**, NOT high availability (though cross-region replicas help with DR).

### How They Work
1. Data is replicated **asynchronously** from the primary.
2. Each replica has its **own DNS endpoint**.
3. Applications must be configured to send read traffic to replicas explicitly.
4. Read Replicas can be promoted to a standalone database (breaks replication).

### Key Details

| Feature | Detail |
|---|---|
| **Max replicas** | Up to 15 (Aurora) or 5 (other RDS engines) |
| **Replication** | Asynchronous (eventual consistency) |
| **Cross-AZ** | Yes -- no data transfer charge within same Region |
| **Cross-Region** | Yes -- data transfer charges apply |
| **Readable?** | Yes (that is the whole point) |
| **Automatic failover?** | No (must manually promote) |
| **Use as Multi-AZ?** | A Read Replica can itself be Multi-AZ |

### Network Cost for Read Replicas

| Scenario | Data Transfer Cost |
|---|---|
| Same AZ | Free |
| Cross-AZ (same Region) | Free for RDS replication |
| Cross-Region | Standard inter-Region data transfer charges |

---

## Multi-AZ vs Read Replicas -- Comparison Table

| Feature | Multi-AZ | Read Replicas |
|---|---|---|
| **Purpose** | High availability / failover | Read scaling / performance |
| **Replication** | Synchronous | Asynchronous |
| **Readable?** | No (classic) / Yes (cluster) | Yes |
| **Automatic failover?** | Yes | No (manual promotion) |
| **Cross-Region?** | No (same Region only) | Yes |
| **Number** | 1 standby (classic) or 2 (cluster) | Up to 5 (RDS) or 15 (Aurora) |
| **DNS endpoint** | Same endpoint (DNS flip) | Separate endpoint per replica |
| **Data consistency** | Fully consistent | Eventually consistent |
| **Use case** | Production HA, disaster recovery within Region | Reporting, analytics, geographic read distribution |

---

## RDS Proxy

RDS Proxy sits between your application and the database to pool and share connections.

### Key Features
- **Connection pooling:** Reduces DB connections from thousands of Lambda invocations to a small pool.
- **IAM authentication:** Applications can use IAM roles instead of database passwords.
- **Automatic failover:** RDS Proxy detects failover and routes connections to the new primary, reducing failover time by up to 66%.
- **Enforces TLS/SSL:** All connections through the proxy are encrypted.
- **VPC only:** RDS Proxy is never publicly accessible.

### When to Use RDS Proxy
- Lambda functions connecting to RDS (avoids connection exhaustion).
- Applications with many short-lived connections.
- When you need faster failover times.

> **Exam tip:** "Lambda + RDS" in a question almost always means you should use RDS Proxy.

---

## Backup and Recovery

### Automated Backups

| Feature | Detail |
|---|---|
| **Enabled by default** | Yes |
| **Retention period** | 1-35 days (default 7) |
| **Backup window** | Configurable daily window |
| **Type** | Full daily snapshot + transaction logs every 5 minutes |
| **Storage** | Stored in S3 (managed by AWS, not visible in your S3 console) |
| **Point-in-Time Recovery (PITR)** | Restore to any second within the retention period |
| **Impact** | Brief I/O suspension (unless Multi-AZ, then backup from standby) |

### Manual Snapshots

| Feature | Detail |
|---|---|
| **Initiated by** | User (or automated via scripts/Lambda) |
| **Retention** | Kept until you delete them (no expiration) |
| **Cross-Region copy** | Yes (for DR) |
| **Sharing** | Can share with other AWS accounts |
| **Restore** | Creates a new RDS instance (new endpoint) |

### Automated Backups vs Manual Snapshots

| Feature | Automated Backups | Manual Snapshots |
|---|---|---|
| **Triggered by** | AWS (daily) | You |
| **Retention** | 1-35 days, then deleted | Forever until you delete |
| **PITR** | Yes | No (point-in-time at snapshot only) |
| **Deleted with instance?** | Yes (unless you take a final snapshot) | No |
| **Cross-Region** | Automated backup replication available | Manual copy |
| **Use case** | Routine recovery | Long-term retention, migration, DR |

> **Exam tip:** If you delete an RDS instance, automated backups are deleted. Manual snapshots persist. Always take a final snapshot before deletion if you need the data.

---

## Encryption

### At Rest (KMS)
- Encryption is configured **at creation time**. You cannot encrypt an existing unencrypted DB directly.
- Uses AWS KMS (AES-256).
- Encrypts: storage, automated backups, snapshots, read replicas.
- **To encrypt an existing unencrypted DB:**
  1. Take a snapshot of the unencrypted DB.
  2. Copy the snapshot and enable encryption on the copy.
  3. Restore a new DB instance from the encrypted snapshot.

### In Transit (SSL/TLS)
- Use the SSL certificate provided by AWS.
- Force SSL by setting the `rds.force_ssl` parameter (PostgreSQL) or `REQUIRE SSL` grant (MySQL).
- Download the root CA certificate from AWS and configure your client.

> **Exam tip:** Read Replicas of an encrypted primary are automatically encrypted with the same key. Cross-Region Read Replicas use a KMS key in the destination Region.

---

## RDS Custom

RDS Custom gives you OS and database-level access while still providing managed RDS automation.

| Feature | RDS | RDS Custom |
|---|---|---|
| **OS access (SSH/RDP)** | No | Yes |
| **DB customization** | Limited to parameter groups | Full (install patches, plugins, change OS settings) |
| **Automation** | Always on | Can pause automation for manual changes |
| **Engines** | All 6 | Oracle and SQL Server only |
| **Use case** | Standard managed DB | Legacy apps needing OS-level access or custom patches |

> **Exam tip:** "Oracle database with custom patches" or "SQL Server with third-party software installed on the OS" -> RDS Custom.

---

## RDS Pricing Considerations (Budget-Conscious)

- **Free Tier:** 750 hours/month of db.t2.micro or db.t3.micro (single-AZ) for 12 months. 20 GB storage. 20 GB backup.
- **Multi-AZ:** Roughly 2x the cost of single-AZ (you are running two instances).
- **Read Replicas:** Each replica is billed as a separate instance.
- **Storage:** gp2/gp3 is cheapest. io1/io2 for high IOPS workloads.
- **Data transfer:** Free within same AZ. Free for replication within same Region. Cross-Region replication incurs charges.

> **Lab tip:** Use db.t3.micro (Free Tier eligible) for labs. Enable Multi-AZ only briefly to test, then tear down.

---

## Key Exam Scenarios

| Scenario | Answer |
|---|---|
| "Database must survive an AZ failure" | Multi-AZ deployment |
| "Need to offload read traffic from the primary" | Read Replicas |
| "Reporting queries are slowing down production" | Create a Read Replica for reporting |
| "Users in another continent need low-latency reads" | Cross-Region Read Replica |
| "Lambda functions exhaust database connections" | RDS Proxy |
| "Need to encrypt an existing unencrypted database" | Snapshot -> Copy with encryption -> Restore |
| "Need OS-level access on Oracle RDS" | RDS Custom |
| "Minimize data loss" | Enable automated backups (PITR to within 5 minutes) + Multi-AZ |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What is RDS?
- Supported Engines
- Multi-AZ Deployments (High Availability)
- Read Replicas (Read Scaling)

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
