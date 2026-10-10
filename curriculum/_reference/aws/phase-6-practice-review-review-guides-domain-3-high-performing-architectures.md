# Domain 3: Design High-Performing Architectures (24% of Exam)

This domain tests your ability to select the right compute, storage, database, and networking services for performance requirements. Expect approximately 16 questions.

---

## 1. EC2 Instance Types

### Instance Family Quick Reference

| Family | Optimized For | Use Cases | Example |
|---|---|---|---|
| M (General Purpose) | Balanced CPU/memory | Web servers, small DBs | m5.xlarge, m6i.large |
| C (Compute) | High CPU | Batch processing, ML inference, gaming | c5.2xlarge, c6g.xlarge |
| R (Memory) | High memory | In-memory caching, large DBs | r5.4xlarge, r6g.2xlarge |
| T (Burstable) | Variable CPU | Dev/test, small web apps | t3.micro, t3.large |
| P/G (Accelerated) | GPU | ML training, video encoding | p4d.24xlarge, g5.xlarge |
| I (Storage) | High I/O, NVMe | NoSQL databases, data warehousing | i3.xlarge |
| D (Dense Storage) | High sequential I/O | Data warehousing, Hadoop | d2.xlarge |
| H (High Disk Throughput) | Sequential read/write | MapReduce, HDFS | h1.2xlarge |

### Key Exam Triggers
- **"High-performance computing (HPC)"** → C-family + cluster placement group
- **"Machine learning training"** → P-family (GPU)
- **"In-memory database / caching"** → R-family
- **"Variable workload / dev environment"** → T-family (burstable)
- **"512 GB RAM requirement"** → R-family or X-family (high memory)

### Placement Groups

| Type | Behavior | Use Case |
|---|---|---|
| Cluster | All instances in same rack, same AZ | Lowest latency, HPC |
| Spread | Each instance on different hardware (max 7 per AZ) | Critical instances that must not share hardware |
| Partition | Groups on separate racks (max 7 partitions per AZ) | Hadoop, Cassandra, Kafka |

---

## 2. EBS Volume Types

### SSD Volumes (Random I/O)

| Type | gp3 | gp2 | io2/io2 Block Express |
|---|---|---|---|
| IOPS | 3,000 baseline, up to 16,000 | 3 IOPS/GB, up to 16,000 | Up to 64,000 (io2) / 256,000 (Block Express) |
| Throughput | 125 MB/s baseline, up to 1,000 MB/s | Up to 250 MB/s | Up to 1,000 MB/s (io2) / 4,000 MB/s (Block Express) |
| Size | 1 GB - 16 TB | 1 GB - 16 TB | 4 GB - 64 TB (Block Express) |
| Use Case | Most workloads | Legacy, burst-based | High-performance databases |
| Multi-Attach | No | No | Yes (io1/io2 only, same AZ) |

### HDD Volumes (Sequential I/O)

| Type | st1 (Throughput Optimized) | sc1 (Cold) |
|---|---|---|
| Throughput | Up to 500 MB/s | Up to 250 MB/s |
| IOPS | Up to 500 | Up to 250 |
| Size | 125 GB - 16 TB | 125 GB - 16 TB |
| Use Case | Big data, log processing | Infrequent access, archival |
| Boot Volume | No | No |

### Key Exam Triggers
- **"General purpose, cost-effective"** → gp3
- **"64,000+ IOPS"** → io2 Block Express
- **"Database requiring high IOPS"** → io2 or io2 Block Express
- **"Big data / streaming logs"** → st1
- **"Lowest cost storage"** → sc1
- **"Shared volume between instances in same AZ"** → io1/io2 Multi-Attach
- **"Data lost when instance stops"** → Instance Store (not EBS)

---

## 3. S3 Performance

### Request Rate
- 3,500 PUT/COPY/POST/DELETE per second per prefix
- 5,500 GET/HEAD per second per prefix
- Spread across multiple prefixes for higher aggregate throughput

### S3 Transfer Acceleration
- Uses CloudFront edge locations to speed up uploads to S3
- Best for: long-distance transfers, large uploads
- NOT for downloads (use CloudFront for that)

### S3 Multipart Upload
- Required for objects > 5 GB
- Recommended for objects > 100 MB
- Parallel upload of parts for faster transfers

### S3 Select / Glacier Select
- Retrieve only a subset of data from an object using SQL expressions
- Reduces data transfer and processing time

### Byte-Range Fetches
- Download specific byte ranges of an object in parallel
- Useful for large files or partial downloads

---

## 4. CloudFront

### Core Concepts
- Global CDN with 400+ edge locations
- Caches content close to users for low latency
- Origins: S3 bucket, ALB, EC2, custom HTTP server, MediaStore
- Origin Access Control (OAC): Restricts S3 access to CloudFront only

### Cache Behaviors
- Path patterns (e.g., /images/*, /api/*) with different settings per pattern
- TTL: Minimum, Default, Maximum
- Cache keys: Based on headers, query strings, cookies

### Advanced Features
- **Lambda@Edge**: Run Lambda at edge locations for request/response manipulation
- **CloudFront Functions**: Lightweight functions for simple transformations (viewer request/response only)
- **Origin Failover**: Origin groups with primary and secondary origins
- **Field-Level Encryption**: Encrypt specific POST fields at the edge

### Key Exam Scenarios
- **"Low-latency global content delivery"** → CloudFront
- **"Serve S3 content securely"** → CloudFront + OAC
- **"Customize content per country"** → Lambda@Edge with CloudFront-Viewer-Country header
- **"Reduce S3 data transfer costs"** → CloudFront (lower egress rates)

---

## 5. Global Accelerator

### CloudFront vs Global Accelerator

| Feature | CloudFront | Global Accelerator |
|---|---|---|
| Content Type | HTTP/HTTPS (cacheable) | TCP/UDP (any protocol) |
| Static IPs | No | Yes (2 Anycast IPs) |
| Caching | Yes | No |
| Use Case | Web content, APIs, media | Non-HTTP (gaming, IoT), IP-based clients |
| Edge | 400+ locations | AWS edge network |
| Health Checks | Origin failover | Endpoint health checks |

### Key Exam Triggers
- **"Static IP addresses for application"** → Global Accelerator
- **"TCP/UDP application performance"** → Global Accelerator
- **"Cacheable HTTP content"** → CloudFront
- **"Improve global gaming performance"** → Global Accelerator

---

## 6. Caching Solutions

### ElastiCache

| Feature | Redis | Memcached |
|---|---|---|
| Data Structures | Strings, lists, sets, sorted sets, hashes | Simple key-value |
| Persistence | Yes (RDB/AOF) | No |
| Replication | Yes (Multi-AZ, read replicas) | No |
| Cluster Mode | Yes (partition data across shards) | Yes (auto-discovery) |
| Backup | Yes | No |
| Pub/Sub | Yes | No |
| Sorted Sets | Yes (great for leaderboards) | No |
| Multi-threaded | No (single-threaded per core) | Yes |
| Use Case | Complex data, HA, persistence | Simple caching, multi-threaded |

### Caching Patterns
- **Cache-Aside (Lazy Loading)**: App checks cache first. On miss, reads from DB and writes to cache.
- **Write-Through**: App writes to cache and DB simultaneously. Cache always has latest data.
- **TTL**: Set expiration to prevent stale data.

### DAX (DynamoDB Accelerator)
- In-memory cache for DynamoDB ONLY
- Microsecond response time (10x improvement over DynamoDB)
- API-compatible with DynamoDB (drop-in replacement — minimal code changes)
- Ideal for read-heavy, repetitive DynamoDB workloads

### ElastiCache vs DAX

| Scenario | Use ElastiCache | Use DAX |
|---|---|---|
| DynamoDB reads | Can work | Purpose-built, easier |
| SQL database caching | Yes | No |
| Session storage | Yes (Redis) | No |
| Leaderboards | Yes (Redis sorted sets) | No |
| Complex data structures | Yes (Redis) | No |
| Microsecond latency for DynamoDB | No | Yes |

---

## 7. Database Performance

### Read Replicas
- Offload read traffic from primary
- Asynchronous replication (eventual consistency)
- RDS: up to 5 replicas
- Aurora: up to 15 replicas with shared storage layer

### Aurora Performance
- 5x throughput of MySQL, 3x throughput of PostgreSQL
- Shared storage volume across 3 AZs
- Reader endpoint: automatically load-balances read traffic
- Custom endpoints: route specific queries to specific replicas
- Aurora Serverless v2: auto-scales compute in ACU (Aurora Capacity Units)

### DynamoDB Performance
- Single-digit millisecond latency at any scale
- Auto-scales with on-demand mode
- Provisioned mode: set RCU/WCU with auto-scaling
- Partition key design is critical for performance (avoid hot partitions)
- Global Secondary Indexes (GSI): alternate query patterns
- Local Secondary Indexes (LSI): must be created at table creation

---

## 8. Kinesis

### Kinesis Data Streams
- Real-time data streaming (sub-second latency)
- Shards: each shard handles 1 MB/sec in, 2 MB/sec out
- Data retention: 24 hours (default) to 365 days
- Multiple consumers can read the same data independently
- Enhanced fan-out: 2 MB/sec per consumer per shard (push-based)
- Ordering: per shard (use partition key)

### Kinesis Data Firehose
- Near-real-time delivery (60 seconds minimum buffering)
- Destinations: S3, Redshift, OpenSearch, Splunk, HTTP endpoint
- Automatic scaling (no shard management)
- Can transform data with Lambda before delivery

### Kinesis vs SQS

| Feature | Kinesis Data Streams | SQS |
|---|---|---|
| Consumers | Multiple independent consumers | Single consumer per message |
| Ordering | Per shard | FIFO only |
| Replay | Yes (within retention period) | No (message deleted after processing) |
| Latency | Sub-second | Milliseconds |
| Use Case | Real-time analytics, streaming | Decoupling, work queues |
| Scaling | Manual (add shards) or on-demand | Automatic |

---

## 9. Lambda Performance

### Key Limits
- Timeout: 15 minutes maximum
- Memory: 128 MB to 10,240 MB
- Ephemeral storage (/tmp): up to 10 GB
- Deployment package: 50 MB zipped, 250 MB unzipped
- Concurrent executions: 1,000 default (can request increase)

### Performance Optimization
- **More memory = more CPU**: Lambda allocates CPU proportionally to memory
- **Provisioned concurrency**: Pre-initializes instances to avoid cold starts
- **Lambda@Edge/CloudFront Functions**: Run code at edge locations
- **Lambda in VPC**: Needs NAT Gateway for internet access; use VPC endpoints for AWS services
- **Connection pooling**: Use RDS Proxy to manage database connections

### Key Exam Scenarios
- **"Processing takes 20 minutes"** → Lambda is NOT suitable (15-min max). Use ECS/Fargate or EC2.
- **"Cold start latency issues"** → Provisioned concurrency
- **"Lambda can't connect to internet from VPC"** → Configure NAT Gateway in public subnet
- **"Lambda overwhelms database connections"** → RDS Proxy

---

## 10. Data Transfer and Migration

### AWS DataSync
- Online data transfer (on-premises ↔ AWS, or between AWS storage)
- Supports NFS, SMB, HDFS, S3, EFS, FSx
- Encrypted, automated, and scheduled
- Up to 10 Gbps throughput

### AWS Transfer Family
- Managed SFTP/FTPS/FTP transfers directly into S3 or EFS
- Uses existing workflows — no code changes

### AWS Snow Family

| Device | Storage | Use Case |
|---|---|---|
| Snowcone | 8 TB (HDD) / 14 TB (SSD) | Edge computing, small transfers |
| Snowball Edge Storage | 80 TB | Large data transfers |
| Snowball Edge Compute | 42/80 TB + compute | Edge computing + transfer |
| Snowmobile | 100 PB | Massive data center migrations |

### Key Exam Triggers
- **"Transfer 10 TB online"** → DataSync
- **"Transfer 100 TB, limited bandwidth"** → Snowball Edge
- **"Transfer 10 PB"** → Snowmobile
- **"SFTP to S3"** → Transfer Family

---

## Common Exam Traps for Domain 3

1. **"gp2 is the best general-purpose volume"** → gp3 is newer and more cost-effective (decoupled IOPS/throughput from size).
2. **"Lambda can run for any duration"** → Max 15 minutes. For longer tasks, use ECS/Fargate/EC2.
3. **"Instance Store data persists across stops"** → WRONG. Instance Store data is lost when the instance stops/terminates.
4. **"CloudFront supports TCP/UDP"** → WRONG. CloudFront is HTTP/HTTPS only. Use Global Accelerator for TCP/UDP.
5. **"DAX works with any database"** → WRONG. DAX is DynamoDB ONLY. Use ElastiCache for other databases.
6. **"S3 Transfer Acceleration speeds up downloads"** → It primarily speeds up uploads. Use CloudFront for download acceleration.
7. **"Kinesis Firehose is real-time"** → It is NEAR-real-time (60-second minimum buffer). Kinesis Data Streams is real-time.
8. **"EBS Multi-Attach works across AZs"** → WRONG. Multi-Attach only works within a single AZ.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- EC2 Instance Types
- EBS Volume Types
- S3 Performance
- CloudFront

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
