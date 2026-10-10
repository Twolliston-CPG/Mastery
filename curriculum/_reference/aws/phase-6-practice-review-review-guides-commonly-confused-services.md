# Commonly Confused Services — Deep Comparison Guide

If you can nail these comparisons, you eliminate a major source of exam errors. Study each pair until you can explain the difference without hesitation.

---

## 1. Security Groups vs NACLs

| Feature | Security Groups | NACLs |
|---|---|---|
| **Level** | Instance (ENI) | Subnet |
| **Statefulness** | Stateful (return traffic automatic) | Stateless (must explicitly allow return traffic) |
| **Rule Types** | Allow rules ONLY | Allow AND Deny rules |
| **Default** | Deny all inbound, allow all outbound | Allow all (default NACL) |
| **Evaluation** | All rules evaluated together | Rules evaluated in order (lowest number first) |
| **Can Reference SGs** | Yes (e.g., allow from sg-12345) | No (IP/CIDR only) |
| **Applies To** | Only instances assigned to it | All instances in the subnet |

**When to use NACLs**: Block a specific IP address or range (SGs cannot deny).
**When to use SGs**: Control access between tiers (web SG → app SG → DB SG).
**Exam trap**: NACLs are stateless — if you allow inbound port 80, you MUST also allow outbound ephemeral ports (1024-65535) for the response.

---

## 2. ALB vs NLB

| Feature | ALB | NLB |
|---|---|---|
| **Layer** | 7 (HTTP/HTTPS) | 4 (TCP/UDP/TLS) |
| **Protocols** | HTTP, HTTPS, WebSocket, gRPC | TCP, UDP, TLS |
| **Static IP** | No (DNS name only) | Yes (one per AZ) |
| **Routing** | Path, host, header, query string, HTTP method | Port-based only |
| **Cross-zone LB** | Enabled by default (free) | Disabled by default (charges if enabled) |
| **SSL Termination** | Yes | Yes (TLS listener) |
| **Performance** | Good (millions of req/sec) | Ultra-high (100M+ req/sec, ultra-low latency) |
| **Sticky Sessions** | Yes | Yes |
| **Targets** | EC2, IP, Lambda | EC2, IP, ALB |

**When to use ALB**: HTTP/HTTPS apps, path-based routing, microservices, WebSocket, gRPC.
**When to use NLB**: Extreme performance, static IPs, non-HTTP protocols, UDP, gaming.
**Exam trap**: "Application needs a static IP" → NLB (or Global Accelerator in front of ALB).

---

## 3. SQS vs Kinesis Data Streams

| Feature | SQS | Kinesis Data Streams |
|---|---|---|
| **Model** | Message queue (pull) | Data stream (pull/push) |
| **Consumer** | Single consumer per message | Multiple independent consumers |
| **Ordering** | FIFO only (Standard = best-effort) | Per shard (partition key) |
| **Replay** | No (message deleted after processing) | Yes (within retention period) |
| **Retention** | 4 days default (1 min - 14 days) | 24 hours default (up to 365 days) |
| **Throughput** | Virtually unlimited (Standard) | 1 MB/sec per shard in, 2 MB/sec out |
| **Scaling** | Automatic | Manual (add shards) or on-demand mode |
| **Use Case** | Decoupling, work queues, buffering | Real-time analytics, streaming, event sourcing |

**When to use SQS**: Decoupling between services, job queues, buffering spikes.
**When to use Kinesis**: Real-time analytics, multiple consumers reading the same data, data replay needed.
**Exam trap**: "Multiple services need to process the same data independently" → Kinesis (or SNS fan-out to SQS).

---

## 4. SNS vs EventBridge

| Feature | SNS | EventBridge |
|---|---|---|
| **Model** | Pub/Sub | Event bus |
| **Filtering** | Message attribute filtering | Content-based event pattern matching |
| **Sources** | Any (via Publish API) | 90+ AWS services, custom apps, SaaS |
| **Targets** | SQS, Lambda, HTTP, email, SMS | 15+ targets (Lambda, SQS, Step Functions, API Gateway, etc.) |
| **Schema** | Unstructured | Schema registry with discovery |
| **Cross-account** | Yes (topic policy) | Yes (event bus policy) |
| **Archive/Replay** | No | Yes |

**When to use SNS**: Simple fan-out, notifications (email, SMS), basic pub/sub.
**When to use EventBridge**: Complex event routing, AWS service events, SaaS integration, event archive/replay, schema discovery.
**Exam trap**: "Route events to different targets based on event content" → EventBridge (not SNS).

---

## 5. Aurora vs Standard RDS

| Feature | Standard RDS | Aurora |
|---|---|---|
| **Read Replicas** | Up to 5 | Up to 15 |
| **Storage** | Manual provisioning, up to 64 TB | Auto-scales, up to 128 TB |
| **Replication Lag** | Seconds (async) | Milliseconds (shared storage) |
| **Failover Time** | 1-2 minutes | ~30 seconds |
| **Storage Copies** | 2 (Multi-AZ) | 6 across 3 AZs |
| **Global** | Cross-region read replicas | Global Database (<1 sec replication) |
| **Serverless** | No | Aurora Serverless v2 (ACU-based) |
| **Cost** | Lower (single instance) | ~20% more than RDS for same instance |
| **Endpoints** | Instance endpoint | Writer, reader, custom endpoints |

**When to use Standard RDS**: Small databases, tight budget, simple workloads, need Oracle/SQL Server.
**When to use Aurora**: High availability, many readers, auto-scaling storage, global apps, serverless needs.
**Exam trap**: Aurora is NOT available for Oracle or SQL Server — only MySQL and PostgreSQL compatible.

---

## 6. CloudFront vs Global Accelerator

| Feature | CloudFront | Global Accelerator |
|---|---|---|
| **Purpose** | Content delivery (CDN) | Network-level acceleration |
| **Protocols** | HTTP/HTTPS | TCP, UDP |
| **Caching** | Yes | No |
| **Static IPs** | No | Yes (2 Anycast IPs) |
| **Edge** | 400+ edge locations | AWS edge network entry |
| **Best For** | Cacheable web content, APIs | Non-HTTP apps, static IP needs, gaming |
| **Health Checks** | Origin failover | Endpoint health with instant failover |

**When to use CloudFront**: Static/dynamic web content, API responses, video streaming.
**When to use Global Accelerator**: TCP/UDP applications, need static IPs, global gaming, IoT.
**Exam trap**: "Static IP addresses" → Global Accelerator (not CloudFront).

---

## 7. Secrets Manager vs Parameter Store

| Feature | Secrets Manager | Parameter Store |
|---|---|---|
| **Purpose** | Secrets (passwords, API keys) | Configuration + secrets |
| **Auto Rotation** | Yes (built-in for RDS, custom Lambda) | No native rotation |
| **Encryption** | Always encrypted | Optional (SecureString with KMS) |
| **Cost** | $0.40/secret/month + API calls | Free (Standard), $0.05/advanced |
| **Max Size** | 64 KB | 4 KB (Standard), 8 KB (Advanced) |
| **Cross-Account** | Yes | Limited |
| **Integration** | RDS, Redshift, DocumentDB rotation | ECS, Lambda, CloudFormation |

**When to use Secrets Manager**: Database credentials that need automatic rotation, API keys.
**When to use Parameter Store**: Application configuration, feature flags, non-rotating values, budget constraints.
**Exam trap**: "Automatically rotate database credentials" → Secrets Manager (NOT Parameter Store).

---

## 8. Direct Connect vs VPN

| Feature | Direct Connect | Site-to-Site VPN |
|---|---|---|
| **Connection Type** | Dedicated physical fiber | Encrypted tunnel over internet |
| **Bandwidth** | 1 Gbps, 10 Gbps, 100 Gbps (or hosted: 50 Mbps - 10 Gbps) | Up to 1.25 Gbps per tunnel |
| **Setup Time** | Weeks to months | Minutes to hours |
| **Latency** | Consistent, low | Variable (internet-dependent) |
| **Encryption** | NOT encrypted by default (add VPN overlay) | Encrypted (IPsec) |
| **Cost** | Higher (port fee + data transfer) | Lower (just data transfer) |
| **Redundancy** | Need 2 connections for HA | Active/passive or active/active tunnels |

**When to use Direct Connect**: Consistent latency, high bandwidth, large data transfer, compliance.
**When to use VPN**: Quick setup, encrypted, lower cost, backup for Direct Connect.
**Common pattern**: VPN as immediate solution → Direct Connect for long-term. VPN as backup for Direct Connect.
**Exam trap**: Direct Connect is NOT encrypted by default. Add a VPN overlay for encryption.

---

## 9. NAT Gateway vs NAT Instance

| Feature | NAT Gateway | NAT Instance |
|---|---|---|
| **Managed** | Yes (AWS managed) | No (you manage) |
| **Availability** | HA within an AZ | Single instance (must script failover) |
| **Bandwidth** | Up to 100 Gbps | Depends on instance type |
| **Cost** | $0.045/hour + $0.045/GB | Instance cost (can be t3.micro ~$0.01/hr) |
| **Security Groups** | No (use NACLs) | Yes |
| **Can be bastion** | No | Yes (can also SSH through it) |
| **Scaling** | Automatic | Manual |

**When to use NAT Gateway**: Production, high-bandwidth, managed preference.
**When to use NAT Instance**: Very low traffic, tight budget, need SG or bastion capability.
**Exam trap**: "Minimize operational overhead" → NAT Gateway. "Minimize cost for low traffic" → NAT Instance.

---

## 10. EFS vs FSx

| Feature | EFS | FSx for Windows | FSx for Lustre |
|---|---|---|---|
| **Protocol** | NFS (Linux) | SMB (Windows) | POSIX (Linux HPC) |
| **OS** | Linux | Windows (and Linux via SMB) | Linux |
| **Use Case** | Shared Linux file system | Windows apps, .NET, AD integration | HPC, ML, video processing |
| **Multi-AZ** | Yes (Standard) | Yes (Multi-AZ deployment) | No (single AZ) |
| **S3 Integration** | No | No | Yes (linked to S3 bucket) |
| **Performance** | Up to 10+ GB/s | Up to 2 GB/s | Up to hundreds of GB/s |

**When to use EFS**: Linux workloads, NFS protocol, shared across AZs.
**When to use FSx Windows**: Windows workloads, SMB, Active Directory.
**When to use FSx Lustre**: HPC, ML training, high-throughput parallel file system.
**Exam trap**: "SMB protocol" or ".NET application" or "Windows" → FSx for Windows (not EFS).

---

## 11. DAX vs ElastiCache

| Feature | DAX | ElastiCache |
|---|---|---|
| **Works With** | DynamoDB ONLY | Any database (RDS, custom, etc.) |
| **API Compatible** | Yes (DynamoDB API) | No (Redis/Memcached API) |
| **Latency** | Microseconds | Sub-millisecond |
| **Setup** | Minimal (change endpoint) | Requires application code changes |
| **Data Structures** | Key-value (DynamoDB items) | Strings, lists, sets, sorted sets, etc. |
| **Use Case** | Caching DynamoDB reads | Session store, leaderboard, general caching |

**When to use DAX**: You already use DynamoDB and need faster reads with minimal changes.
**When to use ElastiCache**: Caching for relational databases, complex data structures, session management.
**Exam trap**: "Cache DynamoDB queries with minimal code changes" → DAX. "Cache SQL query results" → ElastiCache.

---

## 12. S3 Storage Classes Comparison

| Class | Access Speed | Min Duration | Min Object Size | Availability | Retrieval Fee |
|---|---|---|---|---|---|
| Standard | Instant | None | None | 99.99% | None |
| Intelligent-Tiering | Instant/Varies | None | 128 KB | 99.9% | None |
| Standard-IA | Instant | 30 days | 128 KB | 99.9% | Yes |
| One Zone-IA | Instant | 30 days | 128 KB | 99.5% | Yes |
| Glacier Instant | Instant | 90 days | 128 KB | 99.9% | Yes |
| Glacier Flexible | Minutes to hours | 90 days | 40 KB | 99.99% | Yes |
| Glacier Deep Archive | Hours | 180 days | 40 KB | 99.99% | Yes |

**Key Decision Points**:
- Unknown access → Intelligent-Tiering
- Infrequent, critical → Standard-IA
- Infrequent, reproducible → One Zone-IA
- Archive, need ms access → Glacier Instant
- Archive, can wait hours → Glacier Flexible
- Long-term archive, can wait 12+ hours → Deep Archive

---

## 13. DR Strategies Compared

| Strategy | RTO | RPO | Cost | Running Components |
|---|---|---|---|---|
| Backup & Restore | Hours | Hours | $ | Nothing (just backups) |
| Pilot Light | 10s of min | Minutes | $$ | Database replication only |
| Warm Standby | Minutes | Seconds-min | $$$ | Scaled-down full stack |
| Multi-Site Active | Near zero | Near zero | $$$$ | Full production in 2+ regions |

**Exam decision tree**:
1. RTO hours + lowest cost → Backup & Restore
2. RTO minutes + low cost → Pilot Light
3. RTO minutes + near-zero RPO → Warm Standby
4. RTO zero + RPO zero → Multi-Site Active

---

## 14. IAM Roles vs Resource-Based Policies

| Feature | IAM Role (cross-account) | Resource-Based Policy |
|---|---|---|
| **Mechanism** | User assumes role in target account | Policy on resource grants access to principal |
| **Permissions** | User GIVES UP original permissions, gets role permissions | User KEEPS original permissions |
| **Supported By** | All AWS services | S3, SQS, SNS, Lambda, KMS, etc. (not all services) |
| **Use Case** | Need specific set of permissions | Need to access resource while keeping existing permissions |

**When to use IAM Roles**: Standard cross-account access, especially when the target service does not support resource-based policies.
**When to use Resource-Based Policies**: When the user needs to keep their existing permissions while also accessing the cross-account resource (e.g., Lambda invoking a function in another account, S3 cross-account access).
**Exam trap**: "Cross-account access without giving up existing permissions" → Resource-based policy.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Security Groups vs NACLs
- ALB vs NLB
- SQS vs Kinesis Data Streams
- SNS vs EventBridge

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
