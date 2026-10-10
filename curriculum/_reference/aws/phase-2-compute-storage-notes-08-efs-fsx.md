# 08 — EFS and FSx

## Table of Contents
1. [Amazon EFS — Elastic File System](#amazon-efs--elastic-file-system)
2. [EFS Performance Modes](#efs-performance-modes)
3. [EFS Throughput Modes](#efs-throughput-modes)
4. [EFS Storage Classes](#efs-storage-classes)
5. [EFS Cross-AZ and Access](#efs-cross-az-and-access)
6. [Amazon FSx — Overview](#amazon-fsx--overview)
7. [FSx for Windows File Server](#fsx-for-windows-file-server)
8. [FSx for Lustre](#fsx-for-lustre)
9. [FSx for NetApp ONTAP](#fsx-for-netapp-ontap)
10. [FSx for OpenZFS](#fsx-for-openzfs)
11. [FSx Comparison Table](#fsx-comparison-table)
12. [EBS vs EFS vs S3](#ebs-vs-efs-vs-s3)
13. [Key Takeaways for the Exam](#key-takeaways-for-the-exam)

---

## Amazon EFS — Elastic File System

A fully managed, elastic NFS (Network File System) file system for use with AWS compute services and on-premises resources.

**Key characteristics:**
- **POSIX-compliant** shared file system (NFS v4.1).
- Works with **Linux** instances (not Windows — use FSx for Windows File Server instead).
- Supports **thousands of concurrent connections**.
- Scales automatically to **petabytes** without provisioning.
- Pay only for storage used (no need to provision capacity upfront).
- Available across **multiple AZs** within a region for high availability.

---

## EFS Performance Modes

Set at creation time — cannot be changed after.

| Performance Mode | Description | Use Case |
|---|---|---|
| **General Purpose** (default) | Lowest latency. Suitable for most workloads. | Web serving, content management, WordPress, home directories |
| **Max I/O** | Higher aggregate throughput and IOPS, but with slightly higher latency. | Big data, media processing, highly parallelized workloads with many instances |

**Note:** With **Elastic Throughput** mode (see below), Max I/O is less commonly needed because Elastic Throughput can handle bursting workloads without the latency trade-off.

---

## EFS Throughput Modes

| Throughput Mode | How It Works | Use Case |
|---|---|---|
| **Bursting** (default) | Throughput scales with file system size. Earn burst credits when idle. 50 MiB/s per TiB stored, can burst to 100 MiB/s. | Small to medium file systems with variable throughput needs |
| **Provisioned** | Specify throughput independent of storage size. Pay for provisioned throughput. | When you need more throughput than your storage size provides (small FS, high throughput) |
| **Elastic** (recommended) | Automatically scales throughput up and down based on workload. Up to 10 GiB/s read, 3 GiB/s write. Pay per GiB transferred. | Unpredictable or spiky workloads. Default recommendation for new file systems. |

**Exam tip:** If a question says "small file system but needs high throughput" — use Provisioned throughput. If "unpredictable workload" — use Elastic throughput.

---

## EFS Storage Classes

| Storage Class | Description | Price (us-east-1) |
|---|---|---|
| **Standard** | Frequently accessed data. Multi-AZ durability. | $0.30/GB/month |
| **Standard-IA (Infrequent Access)** | Lower cost for infrequently accessed data. Retrieval fee applies. | $0.025/GB/month + retrieval |
| **One Zone** | Data stored in a single AZ. Lower cost, less durability. | $0.16/GB/month |
| **One Zone-IA** | Single AZ + infrequent access. Cheapest option. | $0.0133/GB/month + retrieval |

### EFS Lifecycle Management

- Automatically moves files not accessed for a configurable period (7, 14, 30, 60, or 90 days) to the IA storage class.
- Can also move files **back** to Standard on next access (if configured).
- Similar concept to S3 lifecycle rules but at the file system level.

**Exam tip:** "Reduce EFS costs for files that are rarely accessed" = enable lifecycle management to move to IA.

---

## EFS Cross-AZ and Access

### Multi-AZ Architecture

- EFS creates **mount targets** in each AZ where you want to access the file system.
- Each mount target has its own IP address and ENI in the specified subnet.
- Instances connect to the mount target in their AZ.
- Data is replicated across all AZs in the region (for Standard storage class).

### Access Methods

| Method | Description |
|---|---|
| **EC2 instances** | Mount via NFS using mount target in the same AZ |
| **ECS tasks** | Mount as a volume in the task definition (EC2 and Fargate) |
| **Lambda** | Mount EFS in the Lambda function configuration (Lambda must be in a VPC) |
| **On-premises** | Connect via AWS Direct Connect or VPN, then mount via NFS |
| **EKS pods** | Use the EFS CSI driver |

### EFS Security

- **Security groups** on mount targets control which instances can connect.
- **EFS Access Points**: Enforce a POSIX user and group for applications connecting through the access point. Useful for providing different access to different applications.
- **IAM policies**: Control who can create/manage EFS file systems and mount targets.
- **Encryption**: At rest (KMS) and in transit (TLS via EFS mount helper).

---

## Amazon FSx — Overview

Amazon FSx provides fully managed third-party high-performance file systems.

There are four variants:
1. **FSx for Windows File Server** — Windows-native (SMB protocol).
2. **FSx for Lustre** — High-performance computing (HPC).
3. **FSx for NetApp ONTAP** — Enterprise multi-protocol.
4. **FSx for OpenZFS** — Linux/ZFS workloads.

---

## FSx for Windows File Server

A fully managed Windows file system built on Windows Server. Uses the **SMB protocol**.

**Key features:**
- Supports **Active Directory** integration (AWS Managed AD or self-managed AD).
- Supports **Windows features**: ACLs, user quotas, DFS (Distributed File System) namespaces, DFS Replication.
- Can be mounted on **Windows and Linux** EC2 instances.
- **Deployment options**:
  - **Single-AZ**: Lower cost, data replicated within AZ.
  - **Multi-AZ**: Automatic failover to a standby in another AZ.
- **Storage options**: SSD (low latency, IOPS-intensive) or HDD (throughput-intensive).
- **Backup**: Automatic daily backups to S3.
- Can be accessed from **on-premises** via Direct Connect or VPN.

**Exam tip:** "Windows-based application needing shared file storage with AD integration" = FSx for Windows File Server.

---

## FSx for Lustre

A high-performance parallel file system for compute-intensive workloads. Based on the open-source Lustre file system.

**Key features:**
- Designed for **HPC, machine learning, video processing, financial modeling, EDA**.
- Throughput up to **hundreds of GB/s**, millions of IOPS, sub-millisecond latency.
- **S3 integration**: Can be linked to an S3 bucket. Files in S3 are presented as files in Lustre. Changes can be written back to S3.
- **Deployment options**:
  - **Scratch**: Temporary storage, no replication, highest throughput (200 MiB/s per TiB). Data is not persisted if server fails.
  - **Persistent**: Long-term storage, data replicated within AZ, automatic failover. Higher durability.

| Deployment | Durability | Use Case |
|---|---|---|
| **Scratch** | No replication (temporary) | Short-term processing, burst workloads |
| **Persistent** | Replicated within AZ | Long-term HPC, ML training datasets |

**Exam tip:** "High-performance file system for HPC or ML with S3 integration" = FSx for Lustre.

---

## FSx for NetApp ONTAP

A fully managed file system built on NetApp's ONTAP technology. Supports **NFS, SMB, and iSCSI** protocols.

**Key features:**
- **Multi-protocol**: Access the same data via NFS (Linux), SMB (Windows), or iSCSI (block storage).
- **Storage efficiency**: Automatic compression, deduplication, and compaction.
- **Point-in-time snapshots**: Instant, space-efficient copies.
- **SnapMirror replication**: Replicate data between on-premises NetApp systems and AWS.
- **Multi-AZ** deployment for high availability.
- **Auto-tiering**: Automatically moves infrequently accessed data to a lower-cost capacity pool.
- Supports **Linux, Windows, macOS**, VMware Cloud on AWS, Amazon WorkSpaces, and containers.

**Exam tip:** "Need a file system that supports NFS and SMB simultaneously" or "migrate from on-premises NetApp" = FSx for ONTAP.

---

## FSx for OpenZFS

A fully managed file system built on the open-source OpenZFS file system.

**Key features:**
- Supports **NFS protocol** (v3, v4, v4.1, v4.2).
- Up to **1 million IOPS**, sub-millisecond latency.
- **Snapshots, cloning, compression** — ZFS features.
- **Point-in-time snapshots**: Instant copies, usable for testing or rollback.
- Good for migrating **Linux-based ZFS workloads** to AWS.
- Compatible with **Linux and macOS**.

**Exam tip:** "Migrate on-premises ZFS-based workloads to AWS" = FSx for OpenZFS.

---

## FSx Comparison Table

| Feature | **FSx for Windows** | **FSx for Lustre** | **FSx for ONTAP** | **FSx for OpenZFS** |
|---|---|---|---|---|
| **Protocol** | SMB | Lustre (POSIX) | NFS, SMB, iSCSI | NFS |
| **OS Compatibility** | Windows, Linux | Linux | Windows, Linux, macOS | Linux, macOS |
| **Max Throughput** | 2 GB/s | Hundreds of GB/s | 4 GB/s | 12.5 GB/s |
| **Max IOPS** | Hundreds of thousands | Millions | Hundreds of thousands | 1 million |
| **S3 Integration** | No | Yes (native) | No | No |
| **Multi-AZ** | Yes | No (single AZ per file system, but persistent is durable) | Yes | No (single AZ) |
| **Active Directory** | Yes | No | Yes (via SMB) | No |
| **Deduplication** | Yes | No | Yes (auto) | Yes |
| **Compression** | Yes | Yes | Yes (auto) | Yes |
| **Snapshots** | VSS snapshots | No | Yes (ONTAP snapshots) | Yes (ZFS snapshots) |
| **On-Premises Access** | Yes (DX/VPN) | Yes (DX/VPN) | Yes (SnapMirror, DX/VPN) | Yes (DX/VPN) |
| **Primary Use Case** | Windows file shares, AD, DFS | HPC, ML, video processing | Multi-protocol, NetApp migration | ZFS migration, Linux workloads |

---

## EBS vs EFS vs S3

| Feature | EBS | EFS | S3 |
|---|---|---|---|
| **Type** | Block storage | File storage (NFS) | Object storage |
| **Access** | Single instance (or Multi-Attach for io1/io2) | Thousands of instances concurrently | Unlimited clients via HTTP/S |
| **AZ Scope** | Single AZ | Multi-AZ (or One Zone) | Regional (multi-AZ by default) |
| **Performance** | Up to 256K IOPS (Block Express) | Up to 10 GiB/s (Elastic) | High throughput, high latency |
| **Scaling** | Must provision size | Automatic (petabyte scale) | Unlimited |
| **Cost** | Pay for provisioned capacity | Pay for used storage | Pay for used storage |
| **Protocol** | Block device (mounted as filesystem) | NFS v4.1 | HTTP REST API |
| **Use Case** | Boot volumes, databases, single-instance apps | Shared storage for web servers, CMS, containers | Static assets, backups, data lakes, archives |
| **OS Support** | Linux, Windows | Linux only | Any (via API/SDK) |

---

## Key Takeaways for the Exam

1. **EFS**: Shared NFS storage for Linux. Multi-AZ. Scales automatically. Supports EC2, ECS (Fargate), Lambda, on-premises.
2. **EFS Performance Modes**: General Purpose (low latency) vs Max I/O (high parallelism).
3. **EFS Throughput**: Bursting (scales with size), Provisioned (fixed), Elastic (auto-scales, recommended).
4. **EFS Storage Classes**: Standard, Standard-IA, One Zone, One Zone-IA. Use lifecycle management to save cost.
5. **EFS is Linux only**. For Windows, use FSx for Windows File Server.
6. **FSx for Windows**: SMB, Active Directory, DFS namespaces. Multi-AZ available.
7. **FSx for Lustre**: HPC, ML, sub-ms latency, millions of IOPS, **native S3 integration**.
8. **FSx for ONTAP**: Multi-protocol (NFS + SMB + iSCSI), dedup, compression, SnapMirror, NetApp migration.
9. **FSx for OpenZFS**: NFS, ZFS snapshots, 1M IOPS, Linux/ZFS migration.
10. **"Shared storage for containers on Fargate"** = EFS (only option).
11. **"Windows shared file storage with AD"** = FSx for Windows.
12. **"HPC file system with S3 backend"** = FSx for Lustre.
13. **"Multi-protocol file system"** = FSx for ONTAP.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Amazon EFS — Elastic File System
- EFS Performance Modes
- EFS Throughput Modes
- EFS Storage Classes

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
