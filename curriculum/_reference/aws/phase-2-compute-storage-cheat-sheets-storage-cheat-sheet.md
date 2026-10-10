# Storage Cheat Sheet

## S3 Storage Classes

| Class | Availability | Min Duration | Retrieval Time | Retrieval Fee | Cost ($/GB/mo) | Use Case |
|---|---|---|---|---|---|---|
| **Standard** | 99.99% | None | Immediate | None | $0.023 | Default, frequent access |
| **Intelligent-Tiering** | 99.9% | None | Immediate | None (monitoring fee) | Auto-tiers | Unknown access patterns |
| **Standard-IA** | 99.9% | 30 days | Immediate | Per-GB | $0.0125 | Infrequent, rapid retrieval |
| **One Zone-IA** | 99.5% | 30 days | Immediate | Per-GB | $0.01 | Infrequent, re-creatable |
| **Glacier Instant** | 99.9% | 90 days | Milliseconds | Per-GB | $0.004 | Archive, instant access (quarterly) |
| **Glacier Flexible** | 99.99% | 90 days | 1-5 min / 3-5 hr / 5-12 hr | Per-GB | $0.0036 | Archive, flexible retrieval |
| **Glacier Deep Archive** | 99.99% | 180 days | 12 hr / 48 hr | Per-GB | $0.00099 | Long-term archive, compliance |

### Glacier Flexible Retrieval Speed Options

| Tier | Time | Cost |
|---|---|---|
| Expedited | 1-5 minutes | Most expensive |
| Standard | 3-5 hours | Default |
| Bulk | 5-12 hours | Cheapest |

### Glacier Deep Archive Retrieval

| Tier | Time |
|---|---|
| Standard | 12 hours |
| Bulk | 48 hours |

---

## EBS Volume Types

| Type | **gp3** | **gp2** | **io2 Block Express** | **io1/io2** | **st1** | **sc1** |
|---|---|---|---|---|---|---|
| Category | SSD General | SSD General | SSD Provisioned | SSD Provisioned | HDD Throughput | HDD Cold |
| Size | 1 GiB-16 TiB | 1 GiB-16 TiB | 4 GiB-64 TiB | 4 GiB-16 TiB | 125 GiB-16 TiB | 125 GiB-16 TiB |
| Max IOPS | 16,000 | 16,000 | **256,000** | 64,000 | 500 | 250 |
| Max Throughput | 1,000 MiB/s | 250 MiB/s | 4,000 MiB/s | 1,000 MiB/s | 500 MiB/s | 250 MiB/s |
| IOPS Model | 3,000 free + provision | 3 IOPS/GiB + burst | Provision | Provision (50 or 500 IOPS/GiB) | N/A | N/A |
| Boot Volume | Yes | Yes | Yes | Yes | **No** | **No** |
| Multi-Attach | No | No | Yes | Yes (io1/io2) | No | No |
| Cost ($/GiB/mo) | $0.08 | $0.10 | $0.08 + IOPS | $0.125 + IOPS | $0.045 | $0.015 |
| Best For | **Default choice** | Legacy | Massive databases | Sustained IOPS DB | Big data, logs | Cold archives |

### Key EBS Facts

- **gp3 > gp2**: 20% cheaper, higher throughput (1,000 vs 250 MiB/s), independent IOPS.
- **HDD cannot be boot volumes** (st1, sc1).
- **Multi-Attach**: io1/io2 only, same AZ, up to 16 instances, cluster-aware FS required.
- **Encryption**: KMS-based, encrypt at rest + in transit. To encrypt existing: snapshot -> copy with encryption -> new volume.
- **Snapshots**: Incremental, stored in S3. Archive tier: 75% cheaper, 24-72 hr retrieval.

---

## EFS Quick Reference

| Feature | Value |
|---|---|
| Protocol | NFS v4.1 |
| OS Support | **Linux only** |
| Availability | Multi-AZ (Standard) or Single AZ (One Zone) |
| Scaling | Automatic, up to petabytes |
| Performance Modes | General Purpose (default), Max I/O |
| Throughput Modes | Bursting, Provisioned, **Elastic** (recommended) |
| Storage Classes | Standard, Standard-IA, One Zone, One Zone-IA |
| Encryption | At rest (KMS) + in transit (TLS) |
| Access From | EC2, ECS/Fargate, Lambda (in VPC), on-premises (DX/VPN) |

---

## FSx Variants

| Feature | **Windows File Server** | **Lustre** | **ONTAP** | **OpenZFS** |
|---|---|---|---|---|
| Protocol | SMB | Lustre/POSIX | NFS + SMB + iSCSI | NFS |
| OS | Windows + Linux | Linux | Windows + Linux + macOS | Linux + macOS |
| Max Throughput | 2 GB/s | Hundreds GB/s | 4 GB/s | 12.5 GB/s |
| S3 Integration | No | **Yes** (native) | No | No |
| Multi-AZ | Yes | No | Yes | No |
| Active Directory | Yes | No | Yes (SMB) | No |
| Dedup/Compression | Yes | No/Yes | Yes (auto) | Yes |
| Best For | Windows shares, AD | HPC, ML | Multi-protocol, NetApp migration | ZFS migration |

### FSx Decision Flow

```
Need SMB + Active Directory?         → FSx for Windows
Need HPC performance + S3 backend?   → FSx for Lustre
Need NFS + SMB + iSCSI?             → FSx for ONTAP
Migrating from ZFS?                  → FSx for OpenZFS
Need shared Linux file storage?      → EFS (unless you need FSx features)
```

---

## Storage Gateway Types

| Type | Protocol | Where Data Lives | Cache | Use Case |
|---|---|---|---|---|
| **S3 File Gateway** | NFS/SMB | S3 | Yes | On-prem apps access S3 as NFS/SMB |
| **FSx File Gateway** | SMB | FSx for Windows | Yes | On-prem low-latency access to FSx |
| **Volume — Stored** | iSCSI | **On-premises** (backup to S3) | No | Full data on-prem + cloud backup |
| **Volume — Cached** | iSCSI | **S3** (hot data cached locally) | Yes | Cloud-primary, minimize on-prem |
| **Tape Gateway** | iSCSI (VTL) | S3 + Glacier | Yes | Replace physical tapes |

---

## Snow Family

| Device | Storage | Compute | Best For |
|---|---|---|---|
| **Snowcone** | 8 TB HDD / 14 TB SSD | 2 vCPU, 4 GB | < 10 TB, edge/remote, has DataSync agent |
| **Snowball Edge Storage** | 80 TB | 40 vCPU, 80 GB | 10 TB - 10 PB migration |
| **Snowball Edge Compute** | 42 TB | 104 vCPU, 416 GB (opt. GPU) | Edge compute + migration |
| **Snowmobile** | 100 PB | N/A | > 10 PB (exabyte-scale) |

### When to Use Snow vs Network

| Data Size | 100 Mbps Link | 1 Gbps Link | Recommendation |
|---|---|---|---|
| 10 TB | ~10 days | ~1 day | Snowcone or network |
| 50 TB | ~50 days | ~5 days | Snowball Edge |
| 100 TB | ~100 days | ~10 days | Snowball Edge |
| 1 PB | ~3 years | ~100 days | Snowball Edge (multiple) |
| 10+ PB | Decades | Years | Snowmobile |

---

## DataSync vs Storage Gateway vs Transfer Family

| Service | Purpose | Direction | Protocol |
|---|---|---|---|
| **DataSync** | One-time or scheduled migration | On-prem -> AWS, AWS -> AWS | NFS, SMB, HDFS, S3 |
| **Storage Gateway** | Ongoing hybrid access | Bidirectional | NFS, SMB, iSCSI |
| **Transfer Family** | File transfer (external partners) | In/out of S3/EFS | SFTP, FTPS, FTP, AS2 |

---

## Exam Pattern Matching — Storage

| Keyword in Question | Answer |
|---|---|
| "Unknown access pattern" | S3 Intelligent-Tiering |
| "Once per quarter access, milliseconds" | Glacier Instant Retrieval |
| "Archive, 12-hour retrieval OK" | Glacier Flexible or Deep Archive |
| "Cheapest storage" | Glacier Deep Archive ($0.00099/GB) |
| "No one can delete, not even root" | S3 Object Lock — Compliance Mode |
| "Temporary download link" | Presigned URL |
| "Audit encryption key usage" | SSE-KMS + CloudTrail |
| "Customer provides encryption key" | SSE-C |
| "Shared file storage, Linux, multi-AZ" | EFS |
| "Shared file storage, Windows, AD" | FSx for Windows |
| "HPC file system + S3" | FSx for Lustre |
| "NFS + SMB + iSCSI simultaneously" | FSx for ONTAP |
| "On-prem NFS access to S3" | S3 File Gateway |
| "Minimize on-prem storage, iSCSI" | Volume Gateway — Cached |
| "Replace physical tapes" | Tape Gateway |
| "Transfer > 1 week over network" | Snow Family |
| "Migrate NFS to EFS on a schedule" | DataSync |
| "Partners upload via SFTP" | Transfer Family |
| "Need more than 64,000 IOPS per volume" | io2 Block Express (or RAID 0) |
| "Boot volume" | SSD only (gp2, gp3, io1, io2) — NOT st1/sc1 |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- S3 Storage Classes
- EBS Volume Types
- EFS Quick Reference
- FSx Variants

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
