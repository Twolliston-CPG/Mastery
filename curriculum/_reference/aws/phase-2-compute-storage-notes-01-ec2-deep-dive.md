# 01 — EC2 Deep Dive

## Table of Contents
1. [What is EC2](#what-is-ec2)
2. [Instance Types and Families](#instance-types-and-families)
3. [Purchase Options](#purchase-options)
4. [Placement Groups](#placement-groups)
5. [Instance Store vs EBS](#instance-store-vs-ebs)
6. [User Data](#user-data)
7. [Instance Metadata](#instance-metadata)
8. [Networking: ENI, ENA, EFA](#networking-eni-ena-efa)
9. [Key Takeaways for the Exam](#key-takeaways-for-the-exam)

---

## What is EC2

Amazon Elastic Compute Cloud (EC2) provides resizable virtual servers (instances) in the cloud. You choose the operating system, instance type (CPU, memory, storage, network), and networking configuration. You pay for what you use, with multiple pricing models.

**Key concepts:**
- An EC2 instance runs inside a VPC, in a specific Availability Zone.
- You connect to instances via SSH (Linux) or RDP (Windows).
- An instance has a lifecycle: pending -> running -> stopping -> stopped -> terminated.
- Stopped instances do not incur compute charges, but EBS volumes attached to them still cost money.

---

## Instance Types and Families

AWS names instance types as: `<family><generation>.<size>` (e.g., `m7g.xlarge`).

### Instance Family Overview

| Family | Category | Optimized For | Example Use Case |
|---|---|---|---|
| **M** (m5, m6i, m7g) | General Purpose | Balanced CPU/memory | Web servers, app servers, small databases |
| **T** (t3, t3a, t4g) | General Purpose (burstable) | Variable workloads using CPU credits | Dev/test, small web apps, microservices |
| **C** (c5, c6i, c7g) | Compute Optimized | High-performance processors | Batch processing, ML inference, gaming servers |
| **R** (r5, r6i, r7g) | Memory Optimized | Large in-memory datasets | In-memory caches (Redis), real-time analytics |
| **X** (x1, x2idn) | Memory Optimized | Extreme memory (up to 4 TB) | SAP HANA, large in-memory databases |
| **I** (i3, i4i) | Storage Optimized | High sequential read/write to local storage | NoSQL databases (Cassandra), data warehousing |
| **D** (d2, d3) | Storage Optimized | Dense HDD storage | MapReduce, distributed file systems (HDFS) |
| **P** (p4d, p5) | Accelerated Computing | GPU for ML training | Deep learning training, HPC |
| **G** (g5, g6) | Accelerated Computing | Graphics-intensive | Video rendering, game streaming |
| **Inf** (inf1, inf2) | Accelerated Computing | ML inference | Low-cost inference at scale |
| **HPC** (hpc6a, hpc7g) | HPC Optimized | Tightly coupled HPC workloads | Computational fluid dynamics, weather modeling |

### Instance Size Progression

Sizes double resources (vCPUs, memory) with each step up:

```
nano < micro < small < medium < large < xlarge < 2xlarge < ... < metal
```

Example for m6i family:

| Size | vCPUs | Memory (GiB) | Network (Gbps) |
|---|---|---|---|
| m6i.large | 2 | 8 | Up to 12.5 |
| m6i.xlarge | 4 | 16 | Up to 12.5 |
| m6i.2xlarge | 8 | 32 | Up to 12.5 |
| m6i.4xlarge | 16 | 64 | Up to 12.5 |
| m6i.8xlarge | 32 | 128 | 12.5 |
| m6i.16xlarge | 64 | 256 | 25 |
| m6i.metal | 128 | 512 | 50 |

### T-Series Burstable Instances (Exam Favorite)

- T instances earn **CPU credits** while idle and spend them during bursts.
- `T3 Unlimited`: allows sustained high CPU but charges extra per vCPU-hour when credits are exhausted.
- If your workload has consistent high CPU, use C-family instead. T-series is for **variable** workloads.

**Exam tip:** If a question says "variable workload" or "occasional spikes" — think T-series. If it says "consistently high CPU" — think C-series.

### Graviton (ARM) Instances

- Suffix `g` in the generation (e.g., m7**g**, c7**g**, r7**g**).
- Up to 40% better price-performance than x86 equivalents.
- Requires ARM-compatible AMIs and software.
- **Exam tip:** When the question asks for "most cost-effective" and the workload supports ARM, Graviton is the answer.

---

## Purchase Options

### Comparison Table

| Purchase Option | Commitment | Discount vs On-Demand | Payment | Use Case |
|---|---|---|---|---|
| **On-Demand** | None | 0% (baseline) | Per second (Linux) or per hour (Windows) | Unpredictable workloads, short-term, testing |
| **Reserved Instances (RI)** | 1 or 3 years | Up to 72% | All Upfront, Partial Upfront, or No Upfront | Steady-state, predictable workloads |
| **Savings Plans** | 1 or 3 years ($/hour commitment) | Up to 72% | Hourly spend commitment | Flexible across instance types/regions |
| **Spot Instances** | None (can be interrupted) | Up to 90% | Per second, market price | Fault-tolerant, flexible workloads (batch, CI/CD) |
| **Dedicated Instances** | None or Reserved | ~higher than shared | Per instance | Compliance requiring no shared hardware |
| **Dedicated Hosts** | None or Reserved | Varies | Per host | Licensing (BYOL), regulatory compliance |
| **Capacity Reservations** | None | 0% (On-Demand price) | Whether used or not | Guarantee capacity in an AZ |

### Reserved Instances — Details

- **Standard RI**: Up to 72% discount. Can change AZ, instance size (within family), networking type. Cannot change instance family.
- **Convertible RI**: Up to 66% discount. Can change instance family, OS, tenancy, and payment option. More flexibility, less discount.
- You can sell unused Standard RIs on the **Reserved Instance Marketplace**.

### Savings Plans — Details

- **Compute Savings Plans**: Most flexible. Applies to EC2, Fargate, and Lambda. Up to 66% discount.
- **EC2 Instance Savings Plans**: Locked to a specific instance family in a specific region. Up to 72% discount.
- Automatically applies to usage that matches the plan; anything beyond is billed at On-Demand rates.

### Spot Instances — Details

- You define a **max price** you are willing to pay. If the spot price exceeds your max, your instance is interrupted with a **2-minute warning**.
- **Spot Fleet**: Collection of Spot Instances (and optionally On-Demand) that meet your target capacity.
- **Spot Block** (deprecated in some regions): Request Spot for 1-6 hours without interruption.
- Strategies for Spot Fleet: `lowestPrice`, `diversified`, `capacityOptimized`, `priceCapacityOptimized` (recommended).

**Exam tip:** If the question says "can tolerate interruptions" or "fault-tolerant batch job" — Spot. If it says "cannot be interrupted" — not Spot.

### Capacity Reservations

- Reserve capacity in a specific AZ. No billing discount (On-Demand rates).
- Combine with Savings Plans or Regional RIs for both a capacity guarantee and a discount.
- Use case: ensure capacity is available during a planned event.

---

## Placement Groups

Control how instances are placed on underlying hardware.

| Strategy | Description | Use Case | Limitation |
|---|---|---|---|
| **Cluster** | Instances packed close together in a single AZ, same rack | Low latency, high throughput (HPC, big data) | Single AZ only; if rack fails, all instances fail |
| **Spread** | Instances on distinct hardware (different racks) | High availability for critical instances | Max 7 instances per AZ per group |
| **Partition** | Instances grouped into partitions on separate racks | Large distributed workloads (HDFS, Cassandra, Kafka) | Up to 7 partitions per AZ |

**Exam tips:**
- "Low latency between instances" = Cluster.
- "Maximize availability, isolate failure" = Spread.
- "Large distributed and replicated workloads" = Partition.
- Cluster placement groups can span **only one AZ**. Spread and Partition can span multiple AZs.

---

## Instance Store vs EBS

| Feature | Instance Store | EBS |
|---|---|---|
| Persistence | **Ephemeral** — data lost on stop/terminate | **Persistent** — survives stop, not terminate (unless DeleteOnTermination is false) |
| Performance | Very high IOPS (millions for NVMe) | Up to 256,000 IOPS (io2 Block Express) |
| Replication | None | Replicated within AZ |
| Snapshots | Not supported | Supported (to S3) |
| Size | Fixed by instance type | 1 GiB - 64 TiB |
| Attach at launch | Must be specified at launch | Can be attached/detached anytime |
| Cost | Included in instance price | Separate charge |

**When to use Instance Store:**
- Buffer, cache, scratch data, temporary content.
- Data that is replicated at the application level (e.g., Cassandra, HDFS).

**When to use EBS:**
- Boot volumes, databases, any data that must persist beyond instance lifecycle.

---

## User Data

A script that runs **once** when an instance first starts (on launch). Used to automate setup tasks.

```bash
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
```

- Runs as **root** (no need for `sudo`).
- Maximum size: 16 KB (raw), larger scripts should be pulled from S3.
- Passed as Base64-encoded text via the API.
- Viewable at `http://169.254.169.254/latest/user-data`.

**Exam tip:** User data runs only on the **first boot** by default. To run on every boot, use a `cloud-init` configuration with `[scripts-user, always]`.

---

## Instance Metadata

Available from within the instance at:

```
http://169.254.169.254/latest/meta-data/
```

Useful metadata paths:

| Path | Returns |
|---|---|
| `/latest/meta-data/instance-id` | i-0abc123def456 |
| `/latest/meta-data/ami-id` | ami-0abcdef12345 |
| `/latest/meta-data/local-ipv4` | Private IP address |
| `/latest/meta-data/public-ipv4` | Public IP address |
| `/latest/meta-data/placement/availability-zone` | us-east-1a |
| `/latest/meta-data/iam/security-credentials/<role-name>` | Temporary IAM credentials |
| `/latest/meta-data/instance-type` | m6i.large |

### IMDSv2 (Instance Metadata Service Version 2)

IMDSv2 is the **recommended** and more secure version. It requires a session token obtained via a PUT request:

```bash
# Get a token (TTL of 21600 seconds = 6 hours)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Use the token
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

**Exam tip:** If a question mentions "protecting against SSRF attacks on metadata" — the answer is IMDSv2 (or disabling IMDSv1).

---

## Networking: ENI, ENA, EFA

### Elastic Network Interface (ENI)

- A virtual network card attached to an instance.
- Every instance has a **primary ENI** (eth0) that cannot be detached.
- You can attach **secondary ENIs** from the same AZ for:
  - Dual-homing (management network + data network).
  - Failover: move a secondary ENI (and its private IP) to a standby instance.
- Each ENI can have: one primary private IP, multiple secondary private IPs, one Elastic IP per private IP, one public IP, one or more security groups, a MAC address.

### Enhanced Networking (ENA)

- Uses **SR-IOV** (Single Root I/O Virtualization) to provide higher I/O performance and lower CPU utilization.
- **Elastic Network Adapter (ENA)**: Supports up to **100 Gbps**.
- No additional charge — available on most current-generation instances.
- Must be enabled in the AMI and instance type.

### Elastic Fabric Adapter (EFA)

- An ENI with additional OS-bypass capabilities for **HPC** and **machine learning** workloads.
- Provides lower and more consistent latency than traditional TCP.
- Supports **Message Passing Interface (MPI)** standard.
- Only supported on Linux.

**Exam tip mapping:**
- "High throughput, low latency between instances in a cluster" = ENA or EFA.
- "HPC, tightly coupled parallel workloads, MPI" = EFA.
- "Failover using a secondary network interface" = ENI.

---

## Key Takeaways for the Exam

1. **Instance family selection**: Match the workload to the right family (M=general, C=compute, R=memory, I/D=storage, P/G=GPU).
2. **T-series**: Burstable, uses CPU credits, good for variable workloads. T3 Unlimited avoids throttling but costs more.
3. **Purchase options**: Spot for fault-tolerant (up to 90% off), Reserved/Savings Plans for steady-state (up to 72% off), On-Demand for short-term/unpredictable.
4. **Savings Plans vs Reserved**: Savings Plans are more flexible (especially Compute Savings Plans). RIs give slightly more discount for less flexibility.
5. **Dedicated Hosts**: For BYOL (bring your own license) and regulatory requirements.
6. **Placement groups**: Cluster=low latency, Spread=high availability (max 7/AZ), Partition=distributed systems.
7. **Instance Store**: Ephemeral, ultra-high performance. EBS: Persistent, snapshotable.
8. **User Data**: Runs once at first boot as root. Max 16 KB.
9. **IMDSv2**: Secure metadata access using session tokens. Protects against SSRF.
10. **EFA**: For HPC/MPI workloads. ENA: For high-throughput networking. ENI: Basic networking, failover.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What is EC2
- Instance Types and Families
- Purchase Options
- Placement Groups

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
