# Amazon ElastiCache

## What is ElastiCache?

Amazon ElastiCache is a fully managed in-memory data store service. It supports two engines: **Redis** and **Memcached**. ElastiCache sits between your application and your database (or other data sources) to reduce latency and offload read traffic.

> **Exam tip:** "In-memory cache," "sub-millisecond latency," or "reduce database read load" -> ElastiCache. The follow-up question is always: Redis or Memcached?

---

## Redis vs Memcached -- Comparison Table

| Feature | Redis | Memcached |
|---|---|---|
| **Data structures** | Strings, lists, sets, sorted sets, hashes, bitmaps, hyperloglogs, streams | Simple key-value (strings) only |
| **Persistence** | Yes (RDB snapshots, AOF logs) | No (data lost on restart) |
| **Replication** | Yes (primary + up to 5 replicas) | No |
| **Multi-AZ** | Yes (automatic failover with replicas) | No |
| **Backup/Restore** | Yes (snapshots to S3) | No |
| **Cluster mode** | Yes (data sharding across multiple shards) | Yes (multi-node, multi-threaded) |
| **Pub/Sub** | Yes | No |
| **Lua scripting** | Yes | No |
| **Geospatial** | Yes | No |
| **Transactions** | Yes (MULTI/EXEC) | No |
| **Encryption at rest** | Yes (KMS) | No |
| **Encryption in transit** | Yes (TLS) | Yes (TLS) |
| **AUTH** | Yes (password or IAM) | Yes (SASL) |
| **Max nodes per cluster** | Up to 500 nodes (cluster mode enabled) | Up to 40 nodes |
| **Multi-threaded** | Single-threaded (uses I/O threads in 6.x+) | Multi-threaded |
| **Use cases** | Session store, leaderboards, real-time analytics, chat, queues, caching | Simple caching, session store (ephemeral) |

### Decision Framework

**Choose Redis when you need:**
- Persistence (data survives restarts)
- Replication and Multi-AZ (high availability)
- Complex data types (sorted sets for leaderboards, lists for queues)
- Backup and restore
- Pub/Sub messaging
- Geospatial data

**Choose Memcached when you need:**
- Simplest possible caching layer
- Multi-threaded performance (scale out with more cores)
- No persistence requirement (pure cache, can rebuild from DB)
- A horizontally scalable cache pool

> **Exam tip:** In about 90% of exam scenarios, Redis is the correct answer. Choose Memcached only when the question explicitly says "simplest caching" with no need for persistence, replication, or advanced features.

---

## Caching Strategies

### Lazy Loading (Cache-Aside)

**How it works:**
1. Application checks the cache first.
2. **Cache hit:** Return data from cache.
3. **Cache miss:** Application reads from the database, then writes the result to the cache.

**Pros:**
- Only requested data is cached (no wasted memory).
- Cache failures are not fatal (application falls back to DB).

**Cons:**
- Cache miss penalty: three round trips (check cache, read DB, write cache).
- Data can become stale (cache may contain old data until TTL expires or item is evicted).

### Write-Through

**How it works:**
1. Application writes data to the cache AND the database simultaneously.
2. Data in the cache is always up-to-date.

**Pros:**
- Data is never stale (cache is updated on every write).
- Reads are always fast (data is already in cache).

**Cons:**
- Write penalty: every write goes to two places.
- Cache may fill with data that is never read.
- If the cache goes down, data in the DB is still correct, but cache must be rebuilt.

### Adding TTL (Time-to-Live)

TTL is commonly combined with either strategy:
- **Lazy Loading + TTL:** Prevents data from becoming infinitely stale. After TTL expires, the next read triggers a cache miss and refreshes the data.
- **Write-Through + TTL:** Prevents the cache from filling with rarely-read data. Items expire and are evicted.

### Strategy Comparison

| Feature | Lazy Loading | Write-Through | Lazy Loading + TTL |
|---|---|---|---|
| **Read performance** | Miss penalty on first read | Always fast | Miss penalty after TTL expires |
| **Write performance** | Normal (DB only) | Slower (DB + cache) | Normal (DB only) |
| **Data freshness** | Can be stale | Always fresh | Stale for up to TTL duration |
| **Memory efficiency** | Good (only requested data) | Poor (all written data cached) | Good (TTL evicts unused data) |
| **Complexity** | Low | Medium | Low |
| **Best for** | Read-heavy, tolerates staleness | Must have fresh data on reads | Most common production pattern |

> **Exam tip:** The exam loves asking "which caching strategy ensures data is never stale?" -> Write-Through. "Which strategy is most memory-efficient?" -> Lazy Loading.

---

## Redis Cluster Mode

### Cluster Mode Disabled
- One primary node, up to 5 replicas.
- All data on one shard (limited by memory of a single node).
- Replication is for HA and read scaling, not data partitioning.

### Cluster Mode Enabled
- Data is **sharded** across multiple primary nodes (up to 500 nodes).
- Each shard has one primary and up to 5 replicas.
- Scales both reads AND writes horizontally.
- Supports up to 6.1 TB of in-memory data (500 nodes x node memory).

> **Exam tip:** "Scale ElastiCache writes" or "need more cache capacity than a single node" -> Redis Cluster Mode Enabled.

---

## Replication and Multi-AZ

### Redis Replication
- Asynchronous replication from primary to replicas.
- Replicas are read-only.
- If the primary fails and Multi-AZ is enabled, ElastiCache automatically promotes a replica.

### Multi-AZ (Redis)
- When enabled, ElastiCache creates replicas in a different AZ.
- Automatic failover: if the primary fails, a replica is promoted (typically within 30 seconds).
- DNS endpoint is updated automatically.

### Memcached Replication
- Memcached does NOT support replication or Multi-AZ.
- Each node is independent. If a node fails, that data is lost.
- Application must handle cache misses (fall back to DB).

---

## ElastiCache Security

| Feature | Detail |
|---|---|
| **VPC** | Runs inside your VPC (private subnets recommended) |
| **Security Groups** | Control inbound/outbound traffic |
| **Encryption at rest** | Redis only (KMS) |
| **Encryption in transit** | Redis (TLS), Memcached (TLS) |
| **Authentication** | Redis: AUTH token (password) or IAM auth. Memcached: SASL. |
| **IAM policies** | Control who can manage the cluster (create, delete). Redis 7+ supports IAM-based data access. |

---

## ElastiCache Pricing (Budget-Conscious)

- **No Free Tier** for ElastiCache.
- Smallest Redis node: cache.t3.micro at ~$0.017/hour (~$12/month).
- Smallest Memcached node: cache.t3.micro at ~$0.017/hour.
- **Reserved Nodes:** Up to 55% discount for 1-year or 3-year reservations.

> **Lab tip:** ElastiCache is not required for any hands-on lab in this phase. Study it conceptually. If you want to experiment, use cache.t3.micro and delete within an hour.

---

## Key Exam Scenarios

| Scenario | Answer |
|---|---|
| "Reduce read load on RDS" | ElastiCache (Redis or Memcached) |
| "Sub-millisecond latency for frequently read data" | ElastiCache |
| "In-memory cache with persistence" | ElastiCache Redis |
| "In-memory cache, simplest, no persistence needed" | ElastiCache Memcached |
| "Session store with replication and failover" | ElastiCache Redis with Multi-AZ |
| "Real-time leaderboard" | ElastiCache Redis (sorted sets) |
| "Cache must survive node failure" | ElastiCache Redis (replication + Multi-AZ) |
| "Data in cache is stale" | Add TTL or switch to Write-Through strategy |
| "Scale cache writes beyond single node" | Redis Cluster Mode Enabled |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What is ElastiCache?
- Redis vs Memcached -- Comparison Table
- Caching Strategies
- Redis Cluster Mode

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
