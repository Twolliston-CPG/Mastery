# Amazon DynamoDB

## What is DynamoDB?

Amazon DynamoDB is a fully managed, serverless NoSQL database that delivers single-digit millisecond performance at any scale. It is a key-value and document database. There are no servers to provision, patch, or manage. DynamoDB is one of the most heavily tested services on the SAA-C03 exam.

---

## Table Basics

### Primary Keys

Every DynamoDB table requires a primary key, defined at table creation. There are two types:

| Key Type | Composition | Example | When to Use |
|---|---|---|---|
| **Partition Key only** | Single attribute (hash key) | `user_id = "u123"` | Each item is uniquely identified by one attribute |
| **Partition Key + Sort Key** | Two attributes (composite key) | `user_id = "u123"`, `order_date = "2024-01-15"` | Multiple items share a partition key, differentiated by sort key; enables range queries |

### How Partitions Work
- DynamoDB hashes the partition key to determine which physical partition stores the item.
- A **well-distributed partition key** (high cardinality) spreads data evenly and avoids hot partitions.
- Bad partition key examples: `status` (only a few values), `date` (all traffic hits today's partition).
- Good partition key examples: `user_id`, `device_id`, `order_id`.

> **Exam tip:** "Hot partition" or "throttling" in a question usually means the partition key has low cardinality. The fix is to choose a better partition key or use a write-sharding strategy.

---

## Capacity Modes

| Feature | Provisioned Mode | On-Demand Mode |
|---|---|---|
| **How it works** | You specify Read Capacity Units (RCUs) and Write Capacity Units (WCUs) | DynamoDB scales automatically based on traffic |
| **Auto Scaling** | Optional (set min/max and target utilization) | Built in (no configuration) |
| **Cost model** | Pay per provisioned RCU/WCU per hour | Pay per request (read/write) |
| **Best for** | Predictable, steady workloads | Unpredictable, spiky, or new workloads |
| **Cost efficiency** | Cheaper for consistent high throughput | Cheaper for low or variable throughput |
| **Throttling** | Yes, if you exceed provisioned capacity | Virtually none (DynamoDB handles scaling) |
| **Switch modes** | Can switch once every 24 hours | Can switch once every 24 hours |

### Capacity Unit Math (Important for Exam)

**Read Capacity Units (RCUs):**
- 1 RCU = 1 strongly consistent read/sec for items up to 4 KB
- 1 RCU = 2 eventually consistent reads/sec for items up to 4 KB
- Larger items: round up to the nearest 4 KB

**Write Capacity Units (WCUs):**
- 1 WCU = 1 write/sec for items up to 1 KB
- Larger items: round up to the nearest 1 KB

**Example:** 10 strongly consistent reads/sec for 8 KB items = 10 x (8/4) = 20 RCUs

> **Exam tip:** The exam loves RCU/WCU calculation questions. Practice them.

---

## Secondary Indexes

### Local Secondary Index (LSI) vs Global Secondary Index (GSI)

| Feature | LSI | GSI |
|---|---|---|
| **When to create** | At table creation ONLY | Anytime (create, modify, delete) |
| **Partition key** | Same as base table | Any attribute |
| **Sort key** | Different from base table | Any attribute |
| **Max per table** | 5 | 20 |
| **Capacity** | Shares RCUs/WCUs with base table | Has its own RCUs/WCUs (provisioned) or scales independently (on-demand) |
| **Consistency** | Supports strongly consistent reads | Eventually consistent reads ONLY |
| **Size limit** | 10 GB per partition key value | No size limit |
| **Projection** | KEYS_ONLY, INCLUDE, ALL | KEYS_ONLY, INCLUDE, ALL |
| **Backfill** | No (must exist at creation) | Yes (existing data is automatically backfilled) |

### When to Use Which

- **LSI:** You need an alternative sort key and you know the query patterns at design time. You need strongly consistent reads on the index.
- **GSI:** You need to query by a completely different partition key. You want flexibility to add indexes later. Most common choice.

> **Exam tip:** "Query by an attribute that is not the primary key" -> GSI. "Must be created at table creation time" -> LSI. "Need strongly consistent reads on an index" -> LSI.

---

## DynamoDB Streams

DynamoDB Streams captures a time-ordered sequence of item-level changes in a table.

### Key Facts
- Records are stored for **24 hours**.
- Each record contains: the key attributes, and optionally the new image, old image, or both.
- **Stream view types:**
  - `KEYS_ONLY` -- only the key attributes
  - `NEW_IMAGE` -- the entire item after the change
  - `OLD_IMAGE` -- the entire item before the change
  - `NEW_AND_OLD_IMAGES` -- both before and after

### Common Use Cases
- Trigger a Lambda function on item changes (e.g., send notification, update a search index).
- Replicate data to another table or service.
- Build an audit trail.
- Power DynamoDB Global Tables (Streams is a prerequisite).

> **Exam tip:** "React to changes in a DynamoDB table" -> DynamoDB Streams + Lambda.

---

## Time to Live (TTL)

- Automatically deletes items after a specified timestamp.
- Define a TTL attribute (epoch time in seconds).
- Items are deleted within **48 hours** of expiration (not instant).
- Deleted items appear in Streams (if enabled) with a system-generated marker.
- **No additional cost** -- TTL deletes do not consume WCUs.
- Use case: Session data, temporary tokens, logs, shopping carts.

---

## DynamoDB Accelerator (DAX)

DAX is a fully managed, in-memory cache specifically designed for DynamoDB.

### Key Facts

| Feature | Detail |
|---|---|
| **Latency** | Microsecond reads (vs millisecond for DynamoDB alone) |
| **Compatibility** | Drop-in replacement -- same API calls, no app code changes (just change the endpoint) |
| **Cache type** | Item cache (GetItem, BatchGetItem) and query cache (Query, Scan) |
| **Cluster** | Runs inside your VPC. Multi-AZ for HA. |
| **TTL** | Default 5 minutes (configurable) |
| **Write-through** | Writes go to DynamoDB and update the DAX cache simultaneously |

### DAX vs ElastiCache

| Feature | DAX | ElastiCache |
|---|---|---|
| **Use case** | Cache for DynamoDB specifically | General-purpose caching (any data source) |
| **API changes** | None (DynamoDB-compatible API) | Requires application changes (Redis/Memcached API) |
| **Data source** | DynamoDB only | Any (RDS, APIs, computed results) |
| **Latency** | Microseconds | Sub-millisecond |

> **Exam tip:** "Microsecond latency for DynamoDB reads" -> DAX. "Cache for RDS or general purpose" -> ElastiCache.

---

## Global Tables

DynamoDB Global Tables provide fully managed, multi-Region, multi-active replication.

### Key Facts
- **Active-active:** All replicas accept reads AND writes.
- **Replication lag:** Typically **under 1 second**.
- **Prerequisites:** DynamoDB Streams must be enabled. Table must use on-demand capacity or provisioned with auto scaling.
- **Conflict resolution:** Last-writer-wins (based on timestamps).
- Use case: Global applications that need low-latency reads and writes in multiple Regions.

> **Exam tip:** "Multi-Region active-active database" -> DynamoDB Global Tables. Do NOT confuse with Aurora Global Database (which is active-passive: writes go to the primary Region only).

---

## DynamoDB Transactions

- ACID transactions across multiple items and tables.
- Operations: `TransactWriteItems` (up to 100 items), `TransactGetItems` (up to 100 items).
- **Cost:** Transactions consume 2x the RCUs/WCUs of standard operations (because DynamoDB prepares + commits).
- Use case: Financial transactions, booking systems, inventory management.

---

## Backup Options

| Feature | On-Demand Backup | Point-in-Time Recovery (PITR) |
|---|---|---|
| **Triggered by** | You (manually or via script) | Continuous (automatic) |
| **Retention** | Until you delete the backup | Last 35 days |
| **Granularity** | Full table at a point in time | Any second within the 35-day window |
| **Restore** | Creates a new table | Creates a new table |
| **Performance impact** | None | None |
| **Cost** | $0.10/GB/month for storage | $0.20/GB/month (continuous) |

---

## DynamoDB Pricing (Budget-Conscious)

### Free Tier (Always Free, not just 12 months)
- 25 GB of storage
- 25 provisioned WCUs and 25 provisioned RCUs (enough for ~200 million requests/month)
- 2.5 million read requests from DynamoDB Streams

> **Lab tip:** DynamoDB Free Tier is generous and permanent. All labs in this phase fit within it.

---

## Key Exam Scenarios

| Scenario | Answer |
|---|---|
| "Millisecond latency, key-value lookups" | DynamoDB |
| "Microsecond latency reads" | DynamoDB + DAX |
| "Need to query by non-key attribute" | Add a GSI |
| "React to item changes in real-time" | DynamoDB Streams + Lambda |
| "Auto-delete old session data" | TTL |
| "Multi-Region active-active database" | DynamoDB Global Tables |
| "ACID transactions across multiple items" | DynamoDB Transactions |
| "Unpredictable traffic spikes" | On-Demand capacity mode |
| "Cost-optimize a steady DynamoDB workload" | Provisioned mode with Auto Scaling + Reserved Capacity |
| "Need strongly consistent reads on an index" | LSI (not GSI) |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What is DynamoDB?
- Table Basics
- Capacity Modes
- Secondary Indexes

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
