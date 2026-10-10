# 09 — Storage Gateway & Snow Family

## Table of Contents
1. [AWS Storage Gateway — Overview](#aws-storage-gateway--overview)
2. [S3 File Gateway](#s3-file-gateway)
3. [FSx File Gateway](#fsx-file-gateway)
4. [Volume Gateway](#volume-gateway)
5. [Tape Gateway](#tape-gateway)
6. [Storage Gateway Comparison Table](#storage-gateway-comparison-table)
7. [AWS Snow Family](#aws-snow-family)
8. [Snowcone](#snowcone)
9. [Snowball Edge](#snowball-edge)
10. [Snowmobile](#snowmobile)
11. [Snow Family Comparison Table](#snow-family-comparison-table)
12. [AWS DataSync](#aws-datasync)
13. [AWS Transfer Family](#aws-transfer-family)
14. [Data Migration Decision Framework](#data-migration-decision-framework)
15. [Key Takeaways for the Exam](#key-takeaways-for-the-exam)

---

## AWS Storage Gateway — Overview

AWS Storage Gateway is a hybrid cloud storage service that connects your on-premises environment to AWS cloud storage. It runs as a **virtual machine (VM)** or **hardware appliance** in your data center.

**Why use it:**
- Extend on-premises storage to the cloud.
- Provide low-latency access to cloud data via local caching.
- Migrate data to AWS gradually.
- Integrate with backup and archival workflows.

**Deployment options:**
- VMware ESXi, Microsoft Hyper-V, or Linux KVM virtual machine.
- Amazon EC2 instance (for cloud-to-cloud scenarios).
- AWS Storage Gateway Hardware Appliance (physical device).

---

## S3 File Gateway

Provides a **file interface** (NFS or SMB) to Amazon S3. On-premises applications read and write files through the gateway, and the gateway stores them as objects in S3.

**How it works:**
```
On-Premises Server/App
    ↓ NFS or SMB
S3 File Gateway (VM/Appliance with local cache)
    ↓ HTTPS
Amazon S3 (Standard, Standard-IA, One Zone-IA, Intelligent-Tiering)
    ↓ Lifecycle rule
S3 Glacier / Deep Archive
```

**Key features:**
- Files stored as S3 objects. Metadata (permissions, timestamps) stored as S3 object metadata.
- **Local cache**: Most recently accessed data is cached on the gateway for low-latency access.
- Supports **S3 Standard, Standard-IA, One Zone-IA, and Intelligent-Tiering** as the target storage class.
- Transitioning to **Glacier** is done via S3 lifecycle rules (not directly by the gateway).
- **Active Directory** integration for SMB shares.
- Bucket access via IAM roles associated with the gateway.

**Exam tip:** "On-premises applications need to access S3 via NFS/SMB" = S3 File Gateway. "Need to archive to Glacier" = S3 File Gateway + lifecycle rules.

---

## FSx File Gateway

Provides low-latency local access to a fully managed **FSx for Windows File Server** file system.

**How it works:**
```
On-Premises Windows Server/App
    ↓ SMB
FSx File Gateway (local cache)
    ↓
Amazon FSx for Windows File Server
```

**Key features:**
- Local cache of frequently accessed data on the gateway.
- Useful when on-premises users need low-latency access to FSx for Windows File Server.
- Supports **SMB** protocol.
- Integrates with **Active Directory**.
- FSx for Windows handles backups, Multi-AZ, etc.

**Exam tip:** "On-premises Windows users need low-latency access to a cloud-based Windows file share" = FSx File Gateway.

---

## Volume Gateway

Provides an **iSCSI block storage** interface. On-premises applications use the gateway as a block storage device.

### Two Modes

| Mode | Data Location | Cache | Use Case |
|---|---|---|---|
| **Stored Volumes** | **Full dataset on-premises**. Asynchronously backed up to S3 as EBS snapshots. | No (all data local) | Low-latency access to full dataset, with cloud backup |
| **Cached Volumes** | **Full dataset in S3**. Frequently accessed data cached locally. | Yes | Large datasets where you want to minimize on-premises storage |

**Stored Volumes:**
- Volume size: 1 GiB - 16 TiB.
- Data stored on-premises, point-in-time snapshots sent to S3 (as EBS snapshots).
- You can restore EBS volumes from these snapshots in AWS.

**Cached Volumes:**
- Volume size: 1 GiB - 32 TiB.
- Primary data in S3, local cache for hot data.
- Minimizes the need for on-premises storage expansion.

**Exam tip:** "Need full dataset on-premises with backup to cloud" = Stored Volumes. "Need to minimize on-premises storage, keep data in cloud with local cache" = Cached Volumes.

---

## Tape Gateway

Provides a **virtual tape library (VTL)** interface using iSCSI, compatible with existing backup software (Veeam, Veritas, Commvault, etc.).

**How it works:**
```
On-Premises Backup Software
    ↓ iSCSI (VTL)
Tape Gateway (virtual tape library with local cache)
    ↓
Amazon S3 (virtual tapes)
    ↓ Archive
S3 Glacier Flexible Retrieval or S3 Glacier Deep Archive
```

**Key features:**
- Virtual tapes stored in S3. Archived tapes stored in Glacier.
- No changes to existing backup workflows — the backup software sees a standard tape library.
- Each virtual tape: 100 GiB to 5 TiB.
- Up to 1,500 virtual tapes (1 PB total).

**Exam tip:** "Replace physical tape backup with cloud-based backup without changing backup software" = Tape Gateway.

---

## Storage Gateway Comparison Table

| Gateway Type | Protocol | Data Stored In | Local Cache | Use Case |
|---|---|---|---|---|
| **S3 File Gateway** | NFS, SMB | S3 (objects) | Yes (frequently accessed) | File access to S3, extend on-prem to cloud |
| **FSx File Gateway** | SMB | FSx for Windows | Yes (frequently accessed) | Low-latency access to FSx from on-prem |
| **Volume Gateway — Stored** | iSCSI | On-premises + S3 (snapshots) | No (all data local) | Full dataset on-prem, cloud backup |
| **Volume Gateway — Cached** | iSCSI | S3 (primary) | Yes (hot data) | Minimize on-prem storage, cloud-primary |
| **Tape Gateway** | iSCSI (VTL) | S3 + Glacier | Yes | Replace physical tapes |

---

## AWS Snow Family

Physical devices that AWS ships to you for **offline data transfer** and/or **edge computing**. Used when network transfer is impractical (too slow, too expensive, too unreliable).

**Rule of thumb:** If transferring data over the network would take more than **1 week**, consider Snow Family.

---

## Snowcone

The smallest and most portable Snow device.

| Feature | Snowcone | Snowcone SSD |
|---|---|---|
| **Storage** | 8 TB HDD | 14 TB SSD |
| **Compute** | 2 vCPUs, 4 GB RAM | 2 vCPUs, 4 GB RAM |
| **Weight** | 4.5 lbs (2.1 kg) | 4.5 lbs (2.1 kg) |
| **Power** | Battery or USB-C power | Battery or USB-C power |
| **Network** | 2x 1 Gbps (RJ45), Wi-Fi | 2x 1 Gbps (RJ45), Wi-Fi |
| **DataSync agent** | Pre-installed | Pre-installed |
| **Use cases** | Edge computing, IoT, data collection in harsh/remote environments, drones | Same, with more storage |

**Key:** Snowcone has a **DataSync agent pre-installed**, so you can send data to AWS over the network as well as shipping the device.

---

## Snowball Edge

A larger device available in two variants.

| Feature | Snowball Edge Storage Optimized | Snowball Edge Compute Optimized |
|---|---|---|
| **Storage** | 80 TB usable HDD + 1 TB SSD | 42 TB usable HDD + 7.68 TB NVMe SSD |
| **Compute** | 40 vCPUs, 80 GB RAM | 104 vCPUs, 416 GB RAM |
| **GPU** | No | Optional NVIDIA V100 GPU |
| **Network** | 1x 100 Gbps, 2x 10 Gbps | 2x 100 Gbps, 1x 40 Gbps |
| **Clustering** | Up to 15 devices | Up to 15 devices |
| **Use cases** | Large data transfer, data migration | Edge ML inference, video processing, edge analytics |

**Key features:**
- Can run **EC2 instances** and **Lambda functions** locally (using AWS IoT Greengrass).
- Can be clustered for additional storage and compute.
- Typical data transfer time: shipped to you, you load data, ship back, AWS uploads to S3.

---

## Snowmobile

An **exabyte-scale** data transfer service. Literally a 45-foot shipping container pulled by a semi-truck.

| Feature | Snowmobile |
|---|---|
| **Storage** | 100 PB per Snowmobile |
| **Security** | GPS tracking, alarm monitoring, 24/7 video surveillance, escort security vehicle |
| **Network** | Multiple 40 Gbps connections |
| **Use case** | Transfer exabytes of data (>10 PB) |

**Exam tip:** Use Snowmobile for **>10 PB** of data. Use Snowball Edge for **10 TB to 10 PB**. Use Snowcone for **<10 TB or edge/remote scenarios**.

---

## Snow Family Comparison Table

| Feature | **Snowcone / Snowcone SSD** | **Snowball Edge Storage Opt.** | **Snowball Edge Compute Opt.** | **Snowmobile** |
|---|---|---|---|---|
| **Storage** | 8 TB / 14 TB | 80 TB | 42 TB | 100 PB |
| **Compute** | 2 vCPUs, 4 GB | 40 vCPUs, 80 GB | 104 vCPUs, 416 GB | N/A |
| **GPU** | No | No | Optional | N/A |
| **Data Transfer** | Offline or DataSync (online) | Offline only | Offline only | Offline only |
| **Clustering** | No | Up to 15 | Up to 15 | N/A |
| **Migration Target** | S3 | S3, Glacier | S3, Glacier | S3 |
| **Weight** | 4.5 lbs | ~50 lbs | ~50 lbs | N/A (shipping container) |
| **Best For** | Small, remote, IoT | Large migration | Edge compute + migration | Exabyte-scale migration |

### Edge Computing Use Cases

All Snow devices (except Snowmobile) support edge computing:
- Process data locally before shipping to AWS.
- Run EC2 instances and Lambda functions at the edge.
- Use cases: ships at sea, remote mining sites, factory floors, military operations.

---

## AWS DataSync

A data transfer service for **moving large amounts of data** between on-premises storage and AWS, or between AWS storage services.

**Key features:**
- **Agent-based**: Install a DataSync agent on-premises (VM or EC2).
- **High speed**: Up to 10 Gbps per agent, uses a purpose-built network protocol.
- **Incremental transfers**: Only changed data is transferred after the initial sync.
- **Scheduling**: Set up recurring transfers (hourly, daily, weekly).
- **Data integrity**: Automatic verification of data consistency.

**Supported sources and destinations:**
- On-premises NFS, SMB, HDFS, object storage -> S3, EFS, FSx
- S3 -> S3 (cross-region, cross-account)
- EFS -> EFS

**DataSync vs Storage Gateway:**

| Feature | DataSync | Storage Gateway |
|---|---|---|
| Purpose | **One-time or scheduled migration** of data | **Ongoing hybrid access** to cloud storage |
| Direction | On-prem -> AWS (or vice versa, or AWS-to-AWS) | Bidirectional (on-prem apps access cloud storage) |
| Use case | Migrate NFS/SMB to S3/EFS/FSx | Extend on-prem storage to cloud with local caching |
| Agent | DataSync agent (for on-prem) | Storage Gateway VM/appliance |

**Exam tip:** "Migrate data from on-premises NFS to S3 or EFS on a schedule" = DataSync. "On-premises applications need ongoing access to S3 via NFS" = S3 File Gateway.

---

## AWS Transfer Family

A fully managed service for **file transfers into and out of S3 or EFS** using standard protocols.

**Supported protocols:**
- **SFTP** (SSH File Transfer Protocol)
- **FTPS** (FTP over SSL)
- **FTP** (unencrypted — only within VPC)
- **AS2** (Applicability Statement 2 — B2B)

**Key features:**
- Managed infrastructure (no servers to manage).
- Integrates with existing authentication systems (Active Directory, LDAP, custom identity providers via API Gateway + Lambda).
- Files are stored directly in S3 or EFS.
- DNS endpoint: you can use your own domain with Route 53.

**Exam tip:** "Partners need to upload files via SFTP to S3" = AWS Transfer Family. Not DataSync, not Storage Gateway.

---

## Data Migration Decision Framework

| Scenario | Recommended Service |
|---|---|
| On-prem apps need ongoing NFS/SMB access to S3 | S3 File Gateway |
| On-prem Windows apps need access to cloud file share | FSx File Gateway |
| On-prem apps need block storage with cloud backup | Volume Gateway (Stored) |
| Minimize on-prem storage, keep data in cloud | Volume Gateway (Cached) |
| Replace physical tape backup | Tape Gateway |
| One-time migration of NFS to S3/EFS | DataSync |
| Scheduled incremental data sync | DataSync |
| Transfer < 10 TB from remote/edge location | Snowcone |
| Transfer 10 TB - 10 PB | Snowball Edge |
| Transfer > 10 PB | Snowmobile |
| Edge computing in remote location | Snowball Edge Compute Optimized |
| External partners upload files via SFTP/FTPS | AWS Transfer Family |
| High-performance parallel upload to S3 | S3 Transfer Acceleration (or multipart upload) |

---

## Key Takeaways for the Exam

1. **S3 File Gateway**: NFS/SMB to S3. Local cache. Lifecycle to Glacier.
2. **FSx File Gateway**: SMB to FSx for Windows. Local cache. Active Directory.
3. **Volume Gateway Stored**: Full data on-prem, snapshots to S3. Low latency, cloud backup.
4. **Volume Gateway Cached**: Data in S3, hot data cached locally. Minimize on-prem storage.
5. **Tape Gateway**: Virtual tape library. Replace physical tapes. Archive to Glacier.
6. **Storage Gateway**: For ongoing hybrid access. DataSync: for one-time or scheduled migration.
7. **Snowcone**: 8-14 TB, portable, DataSync agent included, edge computing.
8. **Snowball Edge Storage Optimized**: 80 TB, large data migration.
9. **Snowball Edge Compute Optimized**: 42 TB, high compute (104 vCPUs), optional GPU, edge ML.
10. **Snowmobile**: 100 PB, exabyte-scale migration.
11. **DataSync**: Fast, scheduled, incremental transfers. Agent-based. On-prem to AWS or AWS-to-AWS.
12. **Transfer Family**: SFTP/FTPS/FTP to S3 or EFS. For external partners/users.
13. **Network transfer > 1 week?** Use Snow Family. **< 1 week?** Use DataSync or Transfer Acceleration.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- AWS Storage Gateway — Overview
- S3 File Gateway
- FSx File Gateway
- Volume Gateway

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
