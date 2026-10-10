# Other AWS Database Services

## Overview

AWS offers purpose-built databases for specific workloads. The SAA-C03 exam tests your ability to pick the right database for the right use case. You do not need deep operational knowledge of these services -- you need to know WHEN to choose each one.

---

## Amazon Redshift (Data Warehouse)

### What It Is
A fully managed, petabyte-scale data warehouse optimized for Online Analytical Processing (OLAP). NOT for transactional (OLTP) workloads.

### Key Facts

| Feature | Detail |
|---|---|
| **Storage model** | Columnar (stores data by column, not by row) |
| **Performance** | Massively Parallel Processing (MPP). Up to 10x faster than traditional warehouses. |
| **Node types** | RA3 (managed storage, scales independently), DC2 (dense compute, local SSD), DS2 (legacy) |
| **Cluster** | Leader node + compute nodes |
| **Concurrency Scaling** | Automatically adds transient clusters to handle read spikes |
| **Redshift Spectrum** | Query data directly in S3 without loading it into Redshift |
| **Redshift Serverless** | No cluster management, pay per query. Ideal for intermittent analytics. |
| **Snapshots** | Automated and manual. Can copy to another Region for DR. |
| **Encryption** | KMS or CloudHSM |
| **VPC** | Runs inside your VPC |

### Redshift Spectrum
- Extends Redshift queries to S3 data.
- No need to load data into Redshift tables.
- Uses external tables defined in the AWS Glue Data Catalog or an Athena catalog.
- Billed per TB of data scanned.

> **Exam tip:** "Analytics," "data warehouse," "OLAP," "columnar," or "petabyte-scale reporting" -> Redshift. "Query data in S3 without loading" -> Redshift Spectrum or Athena.

---

## Amazon Neptune (Graph Database)

### What It Is
A fully managed graph database optimized for storing and querying highly connected datasets.

### Key Facts

| Feature | Detail |
|---|---|
| **Graph models** | Property Graph (Gremlin queries) and RDF (SPARQL queries) |
| **Replication** | 6 copies across 3 AZs (same storage architecture as Aurora) |
| **Read Replicas** | Up to 15 |
| **Use cases** | Social networks, recommendation engines, fraud detection, knowledge graphs, network management |
| **Performance** | Billions of relationships, millisecond query latency |

> **Exam tip:** "Social network," "recommendation engine," "highly connected data," or "graph relationships" -> Neptune.

---

## Amazon DocumentDB (MongoDB Compatible)

### What It Is
A fully managed document database that is compatible with the MongoDB API. You can use existing MongoDB drivers and tools.

### Key Facts

| Feature | Detail |
|---|---|
| **Compatibility** | MongoDB 3.6, 4.0, 5.0 API compatible |
| **Storage** | Automatically scales up to 128 TB. 6 copies across 3 AZs (Aurora-like). |
| **Replication** | Up to 15 read replicas. Automatic failover. |
| **Use cases** | Content management, user profiles, catalogs -- any workload currently on MongoDB |

> **Exam tip:** "MongoDB" or "document database" in the question -> DocumentDB. If the question says "migrate from on-premises MongoDB to AWS with minimal code changes" -> DocumentDB.

---

## Amazon Keyspaces (Apache Cassandra Compatible)

### What It Is
A fully managed, serverless database compatible with Apache Cassandra. You can use existing Cassandra Query Language (CQL) drivers and tools.

### Key Facts

| Feature | Detail |
|---|---|
| **Compatibility** | CQL (Cassandra Query Language) |
| **Serverless** | No capacity planning. Scales automatically. |
| **Replication** | 3 copies across multiple AZs |
| **Capacity modes** | On-demand or provisioned (like DynamoDB) |
| **Use cases** | IoT, time-series data, any Cassandra workload migrating to AWS |

> **Exam tip:** "Cassandra" or "CQL" in the question -> Amazon Keyspaces.

---

## Amazon QLDB (Quantum Ledger Database)

### What It Is
A fully managed ledger database with an immutable, cryptographically verifiable transaction log.

### Key Facts

| Feature | Detail |
|---|---|
| **Immutability** | Data cannot be deleted or modified after it is committed. Changes are appended. |
| **Verification** | Cryptographic hash chain (like blockchain, but centralized and managed by AWS) |
| **Performance** | 2-3x faster than blockchain frameworks |
| **NOT blockchain** | QLDB is centralized (single authority). Not decentralized. |
| **Use cases** | Financial transactions, supply chain, DMV records, HR systems -- any system needing an auditable, tamper-proof history |

> **Exam tip:** "Immutable ledger," "cryptographically verifiable," or "audit trail that cannot be tampered with" -> QLDB. If the question says "decentralized" -> Amazon Managed Blockchain instead.

---

## Amazon Timestream (Time-Series Database)

### What It Is
A fully managed, serverless time-series database optimized for storing and analyzing time-stamped data.

### Key Facts

| Feature | Detail |
|---|---|
| **Performance** | 1000x faster and 1/10th the cost of relational databases for time-series queries |
| **Storage tiers** | In-memory (recent data) + magnetic (historical data). Automatic tiering. |
| **Built-in analytics** | Time-series functions: interpolation, smoothing, approximation, aggregation |
| **Serverless** | Auto-scales. No capacity planning. |
| **Encryption** | KMS at rest, TLS in transit |
| **Use cases** | IoT sensor data, application metrics, DevOps monitoring, financial tick data, clickstream analytics |

> **Exam tip:** "Time-series data," "IoT metrics," or "application monitoring data stored over time" -> Timestream.

---

## Which Database for Which Use Case -- Decision Table

| Use Case | Best Service | Why |
|---|---|---|
| Traditional relational workload (OLTP) | **RDS** or **Aurora** | Managed relational, SQL, ACID |
| High-performance relational, 15 replicas, auto-scaling storage | **Aurora** | Superior to RDS in HA and performance |
| Key-value lookups, millisecond latency, serverless | **DynamoDB** | Managed NoSQL, scales to any throughput |
| Key-value with microsecond reads | **DynamoDB + DAX** | In-memory acceleration for DynamoDB |
| In-memory caching (general purpose) | **ElastiCache** | Redis or Memcached for sub-ms reads |
| Data warehouse, analytics (OLAP), petabyte scale | **Redshift** | Columnar, MPP, designed for analytics |
| Query S3 data with SQL (ad-hoc, serverless) | **Athena** | Serverless, pay-per-query, no infra |
| Query S3 data joined with Redshift data | **Redshift Spectrum** | Extends Redshift to S3 |
| Social network, recommendation engine, fraud graph | **Neptune** | Graph DB, Gremlin/SPARQL |
| MongoDB workload, document store | **DocumentDB** | MongoDB-compatible, managed |
| Cassandra workload | **Keyspaces** | CQL-compatible, serverless |
| Immutable ledger, audit trail, tamper-proof | **QLDB** | Cryptographic verification, append-only |
| Decentralized ledger (blockchain) | **Managed Blockchain** | Hyperledger Fabric, Ethereum |
| IoT sensor data, application metrics over time | **Timestream** | Time-series optimized, auto-tiering |
| Full-text search, log analytics | **OpenSearch** | Successor to Elasticsearch |
| Machine learning feature store | **DynamoDB** or **S3** | Depends on access pattern |

---

## Exam Strategy for "Other Databases"

The exam typically presents a scenario and asks you to choose the right database. Look for these keywords:

| Keyword in Question | Service |
|---|---|
| "Relational," "SQL," "ACID," "joins" | RDS or Aurora |
| "Key-value," "millisecond," "NoSQL" | DynamoDB |
| "Microsecond" | DynamoDB + DAX or ElastiCache |
| "Analytics," "data warehouse," "OLAP," "columnar" | Redshift |
| "Graph," "relationships," "social network" | Neptune |
| "MongoDB," "document database" | DocumentDB |
| "Cassandra," "CQL" | Keyspaces |
| "Ledger," "immutable," "audit trail" | QLDB |
| "Blockchain," "decentralized" | Managed Blockchain |
| "Time-series," "IoT metrics" | Timestream |
| "Search," "log analytics," "Elasticsearch" | OpenSearch |
| "In-memory," "caching" | ElastiCache |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Amazon Redshift (Data Warehouse)
- Amazon Neptune (Graph Database)
- Amazon DocumentDB (MongoDB Compatible)
- Amazon Keyspaces (Apache Cassandra Compatible)

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
