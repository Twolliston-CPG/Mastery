# Cheat Sheet: Architecture Patterns

Quick-reference tables and decision guides for the SAA-C03 exam.

---

## CloudFront vs Global Accelerator

| Factor | CloudFront | Global Accelerator |
|---|---|---|
| Type | CDN (caches content) | Network accelerator (proxies traffic) |
| Layer | Layer 7 (HTTP/HTTPS) | Layer 4 (TCP/UDP) |
| Caching | **Yes** | No |
| Static IPs | No | **Yes** (2 Anycast IPs) |
| Protocol | HTTP/HTTPS only | **TCP, UDP** (any protocol) |
| Failover speed | DNS TTL dependent | **< 30 seconds** |
| Edge processing | CF Functions, Lambda@Edge | No |
| Signed URLs/Cookies | Yes | No |

### Decision Rule

```
Need caching?                          --> CloudFront
UDP or non-HTTP?                       --> Global Accelerator
Need static IPs?                       --> Global Accelerator
Need instant failover (< 30s)?        --> Global Accelerator
Need edge processing (headers, auth)?  --> CloudFront
Serving static website/media?          --> CloudFront
Gaming, IoT, VoIP?                     --> Global Accelerator
```

---

## CloudFront Functions vs Lambda@Edge

| Factor | CloudFront Functions | Lambda@Edge |
|---|---|---|
| Runtime | JavaScript | Node.js, Python |
| Triggers | Viewer Request/Response only | All 4 (Viewer + Origin) |
| Exec time | < 1 ms | 5-30 seconds |
| Memory | 2 MB | 128 MB - 10 GB |
| Network access | No | Yes |
| Cost | ~$0.10/million | ~$0.60/million + duration |
| Use cases | Headers, redirects, URL rewrites | Auth, A/B testing, image resize |

### Decision Rule

```
Simple header manipulation?  --> CloudFront Functions
URL rewrites?                --> CloudFront Functions
JWT validation (simple)?     --> CloudFront Functions
Need origin request trigger? --> Lambda@Edge
Need network access?         --> Lambda@Edge
Image resizing?              --> Lambda@Edge
A/B testing with origins?    --> Lambda@Edge
```

---

## Serverless Patterns

### Pattern 1: REST API
```
API Gateway -> Lambda -> DynamoDB
```
Use for: CRUD APIs, mobile/web backends, microservice endpoints.

### Pattern 2: File Processing
```
S3 Event -> Lambda -> Step Functions -> [Lambda steps] -> S3/DynamoDB
```
Use for: Image processing, ETL, multi-step workflows.

### Pattern 3: Event-Driven
```
EventBridge -> [Lambda / Step Functions / SQS / SNS]
```
Use for: Respond to AWS events, scheduled tasks, fan-out.

### Pattern 4: Queue-Based Decoupling
```
Producer -> SQS -> Lambda/EC2 Consumer -> DynamoDB
```
Use for: Buffer bursty traffic, decouple components, handle failures with DLQ.

---

## Compute Decision Guide

| Requirement | Lambda | Fargate | EC2 |
|---|---|---|---|
| Event-driven, < 15 min | **Best** | Good | Overkill |
| Long-running process | No | **Best** | Good |
| GPU needed | No | No | **Best** |
| Scale to zero | **Yes** | Yes | No |
| Lowest ops overhead | **Best** | Good | Most |
| Docker/K8s | Container image | **Best** | Good |
| Cheapest at 24/7 high scale | Expensive | Medium | **Best** (RI) |
| Full OS control | No | No | **Yes** |
| > 10 GB memory | No | Yes (up to 120 GB) | **Yes** |

### Quick Rule
```
"Minimize operational overhead" + event-driven = Lambda
"Docker" or "containers" or "Kubernetes"        = ECS/EKS (Fargate if no ops)
"GPU" or "specific hardware"                     = EC2
"Run 24/7, cost-optimize"                        = EC2 with Reserved Instances
```

---

## Container Decision Guide

| Question | ECS | EKS |
|---|---|---|
| Team uses Kubernetes? | No | **Yes** |
| Multi-cloud strategy? | No | **Yes** |
| Simplest setup? | **Yes** | No |
| AWS-native, no K8s experience? | **Yes** | No |
| Need Helm, Istio, K8s ecosystem? | No | **Yes** |

| Question | Fargate | EC2 Launch Type |
|---|---|---|
| Minimize ops? | **Yes** | No |
| Need GPU? | No | **Yes** |
| Cheapest at sustained scale? | No | **Yes** (Reserved) |
| Need host/OS access? | No | **Yes** |

---

## Analytics Pipeline

```
Ingest -> Store -> Catalog -> Query -> Visualize
```

| Stage | Service | Key Fact |
|---|---|---|
| **Ingest (real-time)** | Kinesis Data Streams | Multiple consumers, replay, real-time |
| **Ingest (near real-time)** | Kinesis Data Firehose | Auto-delivery to S3/Redshift/OpenSearch |
| **Store** | S3 (data lake) | Raw/Processed/Curated zones, Parquet format |
| **Store (warehouse)** | Redshift | Columnar MPP, complex SQL analytics |
| **Catalog** | Glue Data Catalog | Central metadata store for all tables |
| **Discover schema** | Glue Crawlers | Auto-detect schema from S3 data |
| **ETL (serverless)** | Glue ETL | PySpark, serverless, job bookmarks |
| **ETL (full control)** | EMR | Spark/Hadoop, custom configs, Spot instances |
| **Query (serverless SQL)** | Athena | $5/TB scanned, use Parquet + partitioning |
| **Search/Logs** | OpenSearch | Full-text search, log analytics |
| **Visualize** | QuickSight | Serverless BI dashboards |
| **Fine-grained access** | Lake Formation | Column/row-level permissions |

### Kinesis Decision

| Use Case | Service |
|---|---|
| "Deliver logs to S3 with no code" | Firehose |
| "Multiple consumers, replay data" | Data Streams |
| "Real-time SQL on streaming data" | Managed Apache Flink |
| "Deliver to Redshift" | Firehose |
| "Deliver to OpenSearch" | Firehose |

### Athena Cost Reduction

```
1. Use Parquet/ORC (columnar) instead of CSV/JSON
2. Partition data by date (year/month/day)
3. Compress data (gzip, snappy)
4. SELECT specific columns (avoid SELECT *)
5. Set workgroup scan limits
```

---

## Connectivity Options

| Need | Solution |
|---|---|
| Quick, encrypted connection to AWS | Site-to-Site VPN |
| High bandwidth, consistent latency | Direct Connect |
| Encrypt Direct Connect traffic | VPN over Direct Connect |
| Connect to VPCs in multiple regions | Direct Connect Gateway |
| Connect 20+ VPCs (hub-and-spoke) | Transit Gateway |
| VPN bandwidth > 1.25 Gbps | Transit Gateway + ECMP |
| AWS services in your data center | Outposts |
| Ultra-low latency for 5G mobile | Wavelength |
| Low latency for a metro area | Local Zones |

---

## OAC vs OAI (S3 + CloudFront)

| Factor | OAC (use this) | OAI (legacy) |
|---|---|---|
| SSE-KMS support | **Yes** | No |
| All HTTP methods | **Yes** | GET/HEAD limited |
| All S3 regions | **Yes** | Original regions only |
| Recommended | **Yes** | Deprecated for new setups |

---

## Signed URLs vs Signed Cookies

| Factor | Signed URLs | Signed Cookies |
|---|---|---|
| Scope | One file per URL | Multiple files per cookie |
| Use case | Single file download | Video streaming (many segments) |
| Client requirement | None (just a URL) | Must support cookies |

---

## S3 Replication Key Facts

```
- Versioning MUST be enabled on both buckets
- Existing objects NOT replicated (use S3 Batch Replication)
- Replication is NOT chained (A->B->C does not mean A->C)
- Delete marker replication is optional (must enable)
- CRR = Cross-Region Replication
- SRR = Same-Region Replication
- Replication Time Control (RTC) = 99.99% within 15 minutes
```

---

## Exam Power Keywords

| If the question says... | Think... |
|---|---|
| "Minimal operational overhead" | Serverless (Lambda, Fargate, DynamoDB) |
| "Cost-effective" | Smallest/cheapest option that meets requirements |
| "Static IPs" | Global Accelerator or NLB |
| "Non-HTTP protocol" | Global Accelerator (NOT CloudFront) |
| "Cacheable content globally" | CloudFront |
| "Multiple consumers for same data stream" | Kinesis Data Streams |
| "Deliver to S3 automatically" | Kinesis Data Firehose |
| "Query S3 with SQL, no servers" | Athena |
| "Full-text search" | OpenSearch |
| "Column-level access control in data lake" | Lake Formation |
| "Orchestrate multi-step workflow" | Step Functions |
| "Event-driven, respond to AWS events" | EventBridge |
| "Decouple components" | SQS |
| "Fan-out to multiple subscribers" | SNS |
| "Apache Spark with full control" | EMR |
| "Serverless ETL" | Glue |
| "5G mobile edge" | Wavelength |
| "AWS on-premises" | Outposts |
| "Metro area latency" | Local Zones |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- CloudFront vs Global Accelerator
- CloudFront Functions vs Lambda@Edge
- Serverless Patterns
- Compute Decision Guide

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
