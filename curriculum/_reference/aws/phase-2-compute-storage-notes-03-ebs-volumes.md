# 03 — EBS Volumes

## Table of Contents
1. [What is EBS](#what-is-ebs)
2. [Volume Types Comparison](#volume-types-comparison)
3. [gp2 vs gp3 Details](#gp2-vs-gp3-details)
4. [io1 vs io2 Details](#io1-vs-io2-details)
5. [Throughput-Optimized HDD (st1) and Cold HDD (sc1)](#throughput-optimized-hdd-st1-and-cold-hdd-sc1)
6. [EBS Snapshots](#ebs-snapshots)
7. [EBS Encryption](#ebs-encryption)
8. [EBS Multi-Attach](#ebs-multi-attach)
9. [RAID Configurations](#raid-configurations)
10. [Key Takeaways for the Exam](#key-takeaways-for-the-exam)

---

## What is EBS

Amazon Elastic Block Store (EBS) provides persistent block-level storage volumes for EC2 instances. Think of an EBS volume as a virtual hard drive that can be attached to an EC2 instance.

**Key characteristics:**
- An EBS volume exists in a **single Availability Zone**. It can only be attached to instances in the same AZ (except with Multi-Attach for io1/io2).
- Data is automatically **replicated within its AZ** for durability.
- You can take **snapshots** (stored in S3) and use them to create volumes in other AZs or regions.
- Volumes can be **resized** (increased) and type-changed on the fly without downtime (elastic volumes).
- Billed by provisioned capacity (GB/month), not by how much data you write.

---

## Volume Types Comparison

| Feature | **gp3** | **gp2** | **io2 Block Express** | **io1 / io2** | **st1** | **sc1** |
|---|---|---|---|---|---|---|
| **Category** | General Purpose SSD | General Purpose SSD | Provisioned IOPS SSD | Provisioned IOPS SSD | Throughput Optimized HDD | Cold HDD |
| **Volume Size** | 1 GiB - 16 TiB | 1 GiB - 16 TiB | 4 GiB - 64 TiB | 4 GiB - 16 TiB | 125 GiB - 16 TiB | 125 GiB - 16 TiB |
| **Max IOPS** | 16,000 | 16,000 (size-dependent) | 256,000 | 64,000 | 500 | 250 |
| **Max Throughput** | 1,000 MiB/s | 250 MiB/s | 4,000 MiB/s | 1,000 MiB/s | 500 MiB/s | 250 MiB/s |
| **IOPS Provisioning** | 3,000 baseline, scale independently | 3 IOPS/GiB (burst to 3,000) | Provision independently | Provision independently (50 IOPS/GiB) | Not applicable | Not applicable |
| **Throughput Provisioning** | 125 MiB/s baseline, scale independently | Tied to IOPS | Provision independently | Tied to IOPS | 40 MiB/s per TiB (burst to 500) | 12 MiB/s per TiB (burst to 250) |
| **Boot Volume** | Yes | Yes | Yes | Yes | **No** | **No** |
| **Multi-Attach** | No | No | Yes (up to 16 instances) | Yes (io1/io2, up to 16) | No | No |
| **Price (us-east-1)** | $0.08/GiB/mo | $0.10/GiB/mo | $0.08/GiB/mo + IOPS | $0.125/GiB/mo + IOPS | $0.045/GiB/mo | $0.015/GiB/mo |
| **Use Case** | Default choice, most workloads | Legacy default, existing workloads | Largest, most demanding databases | Databases requiring sustained IOPS | Big data, log processing, streaming | Infrequent access, archives |

---

## gp2 vs gp3 Details

### gp2 (Legacy General Purpose)

- IOPS are **tied to volume size**: 3 IOPS per GiB, minimum 100 IOPS, maximum 16,000 IOPS.
- To get 16,000 IOPS, you need at least a 5,334 GiB volume.
- Volumes under 1 TiB can **burst** to 3,000 IOPS using I/O credits (similar to T-series CPU credits).
- Throughput maxes at 250 MiB/s.

### gp3 (Current General Purpose)

- **Baseline**: 3,000 IOPS and 125 MiB/s included at no extra cost, regardless of volume size.
- **Scale independently**: Provision up to 16,000 IOPS and 1,000 MiB/s independently of volume size.
- **20% cheaper** per GiB than gp2 ($0.08 vs $0.10).
- No burst credit system needed — baseline is already 3,000 IOPS.

**Exam tip:** gp3 is almost always the correct answer for general-purpose workloads. It is cheaper and more flexible than gp2. The only reason to choose gp2 is if a question specifically mentions an existing gp2 volume.

### Quick Math: When gp2 Gets Expensive

If you need 3,000 IOPS sustained:
- gp2: Need 1,000 GiB volume = $100/month
- gp3: Need only 1 GiB volume (3,000 IOPS free) = $0.08/month

---

## io1 vs io2 Details

### io1

- Provision up to **50 IOPS per GiB**.
- Max 64,000 IOPS per volume (on Nitro instances; 32,000 on others).
- 99.8-99.9% durability.

### io2

- Same IOPS-to-size ratio: **500 IOPS per GiB** (10x better than io1).
- Max 64,000 IOPS per volume.
- **99.999% durability** (100x better than io1).
- Same price as io1 — effectively replaces io1.

### io2 Block Express

- Next generation. Up to **256,000 IOPS** and **4,000 MiB/s** per volume.
- Volume sizes up to **64 TiB**.
- Sub-millisecond latency.
- Requires Nitro-based instances.

**Exam tip:** If a question requires more than 64,000 IOPS on a single volume, io2 Block Express is the answer. If it requires more than 256,000 IOPS, you need instance store or multiple volumes with RAID 0.

---

## Throughput-Optimized HDD (st1) and Cold HDD (sc1)

### st1

- Optimized for **sequential throughput**, not random IOPS.
- 500 MiB/s max throughput, 500 max IOPS.
- Use case: big data, data warehouses, log processing, Apache Kafka.

### sc1

- Lowest cost option. 250 MiB/s max throughput, 250 max IOPS.
- Use case: infrequently accessed data, lowest cost storage.

**Critical for the exam:**
- HDD volumes (st1, sc1) **cannot be boot volumes**. Only SSD volumes (gp2, gp3, io1, io2) can be boot volumes.

---

## EBS Snapshots

A point-in-time backup of an EBS volume, stored in Amazon S3 (managed by AWS — you do not see them in your S3 buckets).

**Key facts:**
- Snapshots are **incremental**: only changed blocks since the last snapshot are saved.
- First snapshot copies all data; subsequent snapshots only copy deltas.
- You can create a volume from a snapshot in **any AZ** within the region.
- You can **copy a snapshot** to another region (for DR or migration).
- Snapshots can be shared with other AWS accounts or made public.

### EBS Snapshot Archive

- Move a snapshot to the **archive tier** for 75% cost reduction.
- Retrieval takes **24-72 hours**.
- Use case: snapshots you need to retain but rarely access.

### Recycle Bin for EBS Snapshots

- Protect against accidental deletion.
- Set retention rules (1 day to 1 year).
- Deleted snapshots go to the recycle bin and can be recovered.

### Fast Snapshot Restore (FSR)

- Eliminates the latency of first access to a volume created from a snapshot.
- Normally, blocks are lazily loaded from S3 on first read; FSR pre-initializes the volume.
- **Expensive**: charged per AZ per hour enabled. Use only when latency-sensitive.

**Exam tip:** To move an EC2 instance to another AZ: create a snapshot -> create a volume from the snapshot in the target AZ -> attach to a new instance. To move to another region: copy the snapshot to the target region first.

---

## EBS Encryption

- EBS encryption uses **AWS KMS** keys (AES-256).
- When you enable encryption on a volume, the following are encrypted:
  - Data at rest on the volume
  - Data in transit between the instance and the volume
  - All snapshots created from the volume
  - All volumes created from encrypted snapshots
- Encryption is handled transparently by EC2 — **minimal latency impact**.
- You can use the **default AWS-managed key** (`aws/ebs`) or a **customer-managed KMS key**.

### Encrypting an Unencrypted Volume

You cannot directly encrypt an existing unencrypted volume. The process is:

1. Create a snapshot of the unencrypted volume.
2. Copy the snapshot with encryption enabled (specify the KMS key).
3. Create a new volume from the encrypted snapshot.
4. Attach the encrypted volume to the instance.

```bash
# Step 1: Create snapshot
aws ec2 create-snapshot --volume-id vol-0abc123 --description "For encryption"

# Step 2: Copy with encryption
aws ec2 copy-snapshot \
  --source-region us-east-1 \
  --source-snapshot-id snap-0abc123 \
  --encrypted \
  --kms-key-id alias/my-key \
  --description "Encrypted copy"

# Step 3: Create volume from encrypted snapshot
aws ec2 create-volume \
  --snapshot-id snap-encrypted123 \
  --availability-zone us-east-1a \
  --volume-type gp3
```

**Exam tip:** You can set **default encryption** for a region so all new EBS volumes are encrypted automatically.

---

## EBS Multi-Attach

- Allows a **single io1 or io2 volume** to be attached to **up to 16 Nitro-based EC2 instances** simultaneously in the same AZ.
- Each instance has full read/write access.
- **You must use a cluster-aware file system** (e.g., GFS2, OCFS2) — NOT ext4 or XFS.
- Use case: high-availability clustered applications, concurrent write operations.

**Limitations:**
- Same AZ only.
- io1/io2 only (not gp2, gp3, st1, sc1).
- Max 16 instances.
- Application must manage concurrent writes.

---

## RAID Configurations

EBS volumes can be combined using software RAID on the OS level.

| Configuration | Description | Use Case |
|---|---|---|
| **RAID 0** (striping) | Data split across volumes. Combines IOPS and throughput. No redundancy. | When you need more IOPS/throughput than a single volume provides (e.g., 128,000 IOPS from two io2 volumes). |
| **RAID 1** (mirroring) | Data duplicated across volumes. Provides redundancy. No performance gain. | When you need extra fault tolerance beyond EBS's built-in replication. |
| **RAID 5, RAID 6** | **Not recommended** for EBS. The parity writes consume IOPS, reducing available performance. AWS explicitly advises against this. | Do not use. |

**Exam tip:** If a question asks for IOPS beyond what a single volume can provide, the answer is RAID 0 (or io2 Block Express, or instance store).

---

## Key Takeaways for the Exam

1. **gp3 is the default choice** for most workloads — cheaper and more flexible than gp2.
2. **gp3 decouples IOPS and throughput from size**; gp2 ties IOPS to size (3 IOPS/GiB).
3. **io2 replaces io1** (same price, better durability, better IOPS-per-GiB ratio).
4. **io2 Block Express**: up to 256,000 IOPS, 64 TiB, sub-ms latency.
5. **HDD (st1/sc1) cannot be boot volumes**. Use for sequential throughput workloads.
6. **Snapshots are incremental** and stored in S3. Use for backups, cross-AZ, cross-region moves.
7. **Snapshot Archive**: 75% cheaper, 24-72 hour retrieval.
8. **EBS Encryption**: Transparent, uses KMS, encrypts data at rest and in transit.
9. **To encrypt an existing volume**: Snapshot -> Copy snapshot with encryption -> Create volume -> Attach.
10. **Multi-Attach**: io1/io2 only, same AZ, up to 16 instances, needs cluster-aware filesystem.
11. **RAID 0**: Combine volumes for more IOPS. **RAID 5/6**: Never use on EBS.
12. **An EBS volume is locked to one AZ**. To move it, use a snapshot.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What is EBS
- Volume Types Comparison
- gp2 vs gp3 Details
- io1 vs io2 Details

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
