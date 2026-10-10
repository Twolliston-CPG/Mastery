# Data Analytics Pipeline on AWS

## Why This Matters for the Exam

The SAA-C03 tests your ability to design analytics architectures: how data flows from ingestion to storage to processing to visualization. Expect 3-5 questions on Kinesis, Glue, Athena, and the overall data lake pattern. You need to know which service fits which stage of the pipeline.

---

## The Analytics Pipeline Stages

Every analytics architecture follows the same pattern:

```
Ingest --> Store --> Process/Catalog --> Query/Analyze --> Visualize
```

| Stage | AWS Services |
|---|---|
| **Ingest** | Kinesis Data Streams, Kinesis Data Firehose, AWS DMS, AWS DataSync, S3 Transfer Acceleration, Snow Family |
| **Store** | S3 (data lake), Redshift (data warehouse) |
| **Process / ETL** | AWS Glue, EMR (Spark/Hadoop), Lambda |
| **Catalog** | AWS Glue Data Catalog, Lake Formation |
| **Query / Analyze** | Amazon Athena, Redshift Spectrum, OpenSearch |
| **Visualize** | Amazon QuickSight |

---

## Reference Architecture: Real-Time Analytics Pipeline

```
Data Sources              Ingestion              Storage              Catalog           Query           Visualize
+-----------+         +---------------+       +----------+       +----------+      +----------+     +-----------+
| IoT       |         |               |       |          |       |          |      |          |     |           |
| Devices   |-------->| Kinesis Data  |------>| S3       |------>| Glue     |----->| Athena   |---->| QuickSight|
|           |         | Firehose      |       | (Raw     |       | Crawler  |      | (SQL     |     | (Dashboard|
+-----------+         |               |       |  Zone)   |       | + Data   |      |  Queries)|     |  + Charts)|
                      | (buffers,     |       |          |       | Catalog  |      |          |     |           |
+-----------+         |  transforms,  |       +----------+       +----------+      +----------+     +-----------+
| Web App   |         |  delivers)    |            |
| Clickstream|------->|               |            |
|           |         +---------------+       +----------+
+-----------+                                 | S3       |
                                              | (Process |
+-----------+         +---------------+       |  Zone)   |
| Databases |         | AWS DMS       |       +----------+
| (RDS,     |-------->| (CDC for      |            |
| On-prem)  |         |  ongoing      |       +----------+
+-----------+         |  replication) |       | S3       |
                      +---------------+       | (Curated |
                                              |  Zone)   |
                                              +----------+
```

---

## Amazon Kinesis (Review and Deep Dive)

### Kinesis Data Streams vs Kinesis Data Firehose

| Feature | Kinesis Data Streams | Kinesis Data Firehose |
|---|---|---|
| **Latency** | Real-time (~200 ms) | Near real-time (60 sec buffer minimum) |
| **Data retention** | 1-365 days | No retention (delivers immediately) |
| **Scaling** | Manual (add/remove shards) | Automatic |
| **Consumers** | Custom consumers (Lambda, KCL app, SDK) | S3, Redshift, OpenSearch, Splunk, HTTP endpoint |
| **Data transformation** | Requires consumer application | Built-in Lambda transformation |
| **Replay** | Yes (data retained) | No (fire-and-forget) |
| **Use case** | Custom real-time processing, multiple consumers | Simple delivery to AWS storage |
| **Pricing** | Per shard hour + per PUT | Per GB ingested |
| **Management** | More operational overhead | Fully managed |

### When to Use Which

| Scenario | Answer |
|---|---|
| "Deliver log data to S3 with minimal management" | Firehose |
| "Multiple consumers need to process the same stream" | Data Streams |
| "Need to replay data from 3 days ago" | Data Streams (retention) |
| "Real-time dashboard with < 1 second latency" | Data Streams |
| "Deliver clickstream data to Redshift" | Firehose |
| "Transform data before storing in S3" | Firehose (with Lambda transform) |

### Kinesis Data Streams -- Capacity

| Mode | Detail |
|---|---|
| **Provisioned** | Choose number of shards; each shard: 1 MB/s in, 2 MB/s out, 1000 records/s in |
| **On-Demand** | Auto-scales; up to 200 MB/s write and 400 MB/s read; pay per stream hour + per GB |

### Kinesis Data Firehose -- Delivery Destinations

| Destination | Notes |
|---|---|
| **S3** | Most common; delivers as compressed Parquet/ORC/JSON/CSV files |
| **Redshift** | Via S3 (Firehose writes to S3 first, then COPY to Redshift) |
| **OpenSearch Service** | Direct delivery for search/log analytics |
| **Splunk** | Third-party integration |
| **HTTP Endpoint** | Custom destination (Datadog, New Relic, etc.) |

---

## Amazon S3 as a Data Lake

S3 is the foundation of most AWS data lake architectures due to its durability (11 9's), scalability, and low cost.

### Data Lake Zones

| Zone | Purpose | Data Format | Example |
|---|---|---|---|
| **Raw (Landing)** | Store ingested data as-is, no transformation | Original format (JSON, CSV, logs) | `s3://datalake/raw/clickstream/2024/01/15/` |
| **Processed (Staging)** | Cleaned, validated, deduplicated data | Optimized format (Parquet, ORC) | `s3://datalake/processed/clickstream/` |
| **Curated (Analytics)** | Business-ready, aggregated datasets | Parquet/ORC with partitioning | `s3://datalake/curated/daily-metrics/` |

### Why Parquet/ORC?

| Feature | CSV/JSON | Parquet/ORC |
|---|---|---|
| Format | Row-based | Columnar |
| Compression | Poor | Excellent (up to 75% smaller) |
| Query performance | Read all columns | Read only needed columns |
| Athena cost | Higher (scans more data) | Lower (scans less data) |
| Schema evolution | Manual | Built-in |

**Exam tip:** If the question asks about "reducing Athena query cost" or "optimizing query performance in a data lake," the answer is converting to Parquet/ORC and using partitioning.

---

## AWS Glue

Glue is a fully managed ETL (Extract, Transform, Load) service and a centralized metadata catalog.

### Glue Components

| Component | What It Does |
|---|---|
| **Glue Data Catalog** | Central metadata repository (databases, tables, schemas). Acts as a Hive Metastore compatible catalog. |
| **Glue Crawlers** | Automatically scan data sources (S3, RDS, DynamoDB) and populate the Data Catalog with table definitions. |
| **Glue ETL Jobs** | Serverless Spark jobs that transform data (Python or Scala). |
| **Glue Studio** | Visual ETL job builder (no coding required). |
| **Glue DataBrew** | Visual data preparation tool (clean, normalize, transform without writing code). |

### Glue Crawler Workflow

```
1. Crawler scans S3 bucket (e.g., s3://datalake/raw/clickstream/)
2. Crawler infers schema (column names, types)
3. Crawler creates/updates table in Glue Data Catalog
4. Athena can now query the data using the catalog table
```

### Glue ETL Job Example

```
Source: S3 (raw JSON files)
   |
   v
Glue ETL Job (PySpark):
   - Read JSON from S3 raw zone
   - Filter out invalid records
   - Convert timestamps to standard format
   - Flatten nested JSON
   - Write as Parquet to S3 processed zone
   |
   v
Destination: S3 (processed Parquet files)
```

### Glue Job Bookmarks

Glue job bookmarks track which data has already been processed so that the next run only processes new data. This prevents reprocessing.

**Exam tip:** If the question asks "how to avoid reprocessing data in Glue ETL jobs," the answer is Glue job bookmarks.

---

## AWS Lake Formation

Lake Formation builds on top of Glue to provide a managed data lake with fine-grained access control.

### What Lake Formation Adds Beyond Glue

| Feature | Glue Alone | Lake Formation |
|---|---|---|
| Data Catalog | Yes | Yes (uses Glue Data Catalog underneath) |
| ETL | Yes | Yes (uses Glue ETL underneath) |
| Fine-grained access control | No (IAM only) | **Yes** (column-level, row-level, cell-level) |
| Data sharing across accounts | Complex (bucket policies + IAM) | **Simple** (Lake Formation grants) |
| Governed tables | No | **Yes** (ACID transactions on S3) |
| Blueprint workflows | No | **Yes** (pre-built ingestion templates) |

**Exam tip:** If the question mentions "fine-grained access control to specific columns in a data lake" or "share data lake tables across AWS accounts easily," the answer is Lake Formation.

---

## Amazon Athena

Athena is a serverless, interactive query service that lets you analyze data in S3 using standard SQL.

### Key Characteristics

| Feature | Detail |
|---|---|
| **Serverless** | No infrastructure to manage |
| **Query language** | ANSI SQL (based on Presto/Trino) |
| **Data source** | Primarily S3 (also DynamoDB, RDS, on-premises via connectors) |
| **Catalog** | Uses Glue Data Catalog for table definitions |
| **Pricing** | $5 per TB of data scanned |
| **Performance** | Interactive (seconds to minutes) |

### Reducing Athena Costs

| Technique | How It Helps |
|---|---|
| **Use columnar formats (Parquet/ORC)** | Scan only needed columns; dramatically reduces data scanned |
| **Partition data** | Athena skips partitions that do not match the WHERE clause (e.g., partition by date) |
| **Compress data** | Smaller files = less data scanned = lower cost |
| **Use SELECT specific columns** | Avoid SELECT * (reads all columns) |
| **Use workgroups** | Set per-query data scan limits to control costs |

### Athena Federated Query

Athena can query data beyond S3 using **federated query connectors:**
- DynamoDB
- RDS / Aurora
- Redshift
- On-premises databases (via Lambda connector)
- CloudWatch Logs

**Exam tip:** "Query S3 data using SQL without provisioning servers" = Athena.

---

## Amazon QuickSight

QuickSight is a serverless business intelligence (BI) visualization service.

| Feature | Detail |
|---|---|
| **Serverless** | No infrastructure to manage |
| **Data sources** | Athena, S3, RDS, Redshift, DynamoDB, OpenSearch, on-premises DBs |
| **SPICE** | In-memory calculation engine for fast dashboard performance |
| **ML Insights** | Anomaly detection, forecasting, auto-narratives |
| **Sharing** | Dashboards can be shared with users and embedded in applications |
| **Pricing** | Per-user/month (Standard: $9, Enterprise: $18) |

**Exam tip:** QuickSight is the visualization layer. If the question asks "create dashboards from Athena query results," the answer is QuickSight.

---

## Amazon EMR (Elastic MapReduce)

EMR is a managed cluster platform for big data processing using open-source frameworks.

### Supported Frameworks

| Framework | Use Case |
|---|---|
| **Apache Spark** | General-purpose big data processing, ML, SQL |
| **Apache Hadoop** | MapReduce batch processing |
| **Apache Hive** | SQL-like queries on large datasets |
| **Apache HBase** | NoSQL database on Hadoop |
| **Presto/Trino** | Interactive SQL queries |
| **Apache Flink** | Real-time stream processing |

### EMR Node Types

| Node Type | Role |
|---|---|
| **Primary (Master)** | Manages the cluster, coordinates work |
| **Core** | Runs tasks + stores data on HDFS |
| **Task** | Runs tasks only (no data storage); can use Spot Instances |

### EMR vs Glue ETL

| Feature | EMR | Glue ETL |
|---|---|---|
| **Management** | You manage clusters (launch, scale, terminate) | Fully serverless |
| **Flexibility** | Full access to Spark/Hadoop ecosystem | Simplified PySpark/Scala |
| **Cost** | Can be cheaper for large-scale (Spot instances for Task nodes) | Pay per DPU-hour |
| **Use case** | Complex big data, custom configurations, ML pipelines | Standard ETL, data transformation |

**Exam tip:** If the question says "Apache Spark" or "Hadoop" or "Hive," the answer is EMR. If it says "serverless ETL" or "transform data in S3 without managing clusters," the answer is Glue.

---

## Amazon OpenSearch Service (formerly Elasticsearch)

OpenSearch is a managed search and analytics service.

| Feature | Detail |
|---|---|
| **Use cases** | Log analytics, full-text search, application monitoring, clickstream analytics |
| **Integration** | Kinesis Firehose (direct delivery), Lambda, CloudWatch Logs |
| **Dashboards** | Built-in OpenSearch Dashboards (formerly Kibana) |
| **Deployment** | Managed instances in a VPC or public endpoint |
| **Storage** | UltraWarm (S3-backed, cost-effective for infrequent access) |

### Common Pattern: ELK / EFK Stack on AWS

```
Logs -> Kinesis Firehose -> OpenSearch Service -> OpenSearch Dashboards
        (or CloudWatch       (index, search,      (visualize,
         Logs subscription)   analyze)              dashboards)
```

**Exam tip:** If the question asks about "log analytics," "full-text search," or "real-time search and analytics," think OpenSearch.

---

## Analytics Service Decision Table

| Requirement | Service | Why |
|---|---|---|
| "Deliver streaming data to S3" | Kinesis Data Firehose | Near real-time delivery, fully managed |
| "Process streaming data with custom consumers" | Kinesis Data Streams | Real-time, multiple consumers, replay |
| "Query S3 data with SQL, no servers" | Athena | Serverless SQL on S3 |
| "Create dashboards and visualizations" | QuickSight | Serverless BI |
| "ETL on S3 data, no cluster management" | Glue ETL | Serverless Spark |
| "Fine-grained access to data lake columns" | Lake Formation | Column/row-level security |
| "Discover schema of data in S3" | Glue Crawler | Auto-creates table definitions |
| "Run Apache Spark with full control" | EMR | Managed Spark/Hadoop clusters |
| "Log analytics and full-text search" | OpenSearch Service | Search, analytics, dashboards |
| "Data warehouse for complex SQL analytics" | Redshift | Columnar MPP database |
| "Query Redshift data + S3 data together" | Redshift Spectrum | Extends Redshift to S3 |
| "Real-time analytics on streaming data" | Kinesis Data Analytics (Managed Apache Flink) | SQL/Flink on streams |

---

## Kinesis vs SQS vs Managed Flink -- Streaming Comparison

| Feature | Kinesis Data Streams | SQS | Managed Apache Flink |
|---|---|---|---|
| **Pattern** | Stream (ordered log) | Queue (message buffer) | Stream processing engine |
| **Ordering** | Per-shard ordering | FIFO queues only | Depends on source |
| **Consumers** | Multiple (fan-out) | Single consumer per message | Reads from Kinesis/Kafka |
| **Replay** | Yes (data retention) | No | Yes (reads from stream) |
| **Data retention** | 1-365 days | 1 min - 14 days | N/A (reads from source) |
| **Processing** | Custom consumer code | Consumer code | SQL or Flink application |
| **Use case** | Real-time analytics, IoT telemetry, clickstream | Decoupling, buffering, work queues | Complex real-time analytics |

---

## Complete Pipeline Example: IoT Analytics

```
IoT Devices
    |
    v
Kinesis Data Streams (real-time ingestion, multiple shards)
    |
    +---> Kinesis Data Firehose --> S3 (raw zone, JSON) --> Glue Crawler --> Athena (ad-hoc queries)
    |                                     |
    |                               Glue ETL Job
    |                                     |
    |                                     v
    |                               S3 (processed zone, Parquet)
    |                                     |
    |                               Glue Crawler
    |                                     |
    |                                     v
    |                               Athena --> QuickSight (dashboards)
    |
    +---> Lambda (real-time alerting: if temperature > threshold, send SNS alert)
    |
    +---> Managed Apache Flink (real-time sliding window aggregation)
              |
              v
          DynamoDB (real-time metrics for dashboard API)
```

---

## Key Takeaways

1. **Firehose for delivery to S3/Redshift/OpenSearch; Data Streams for custom real-time processing with multiple consumers.**
2. **S3 is the data lake foundation.** Use raw/processed/curated zones with Parquet format.
3. **Glue = serverless ETL + Data Catalog + Crawlers.** The catalog is used by Athena, Redshift Spectrum, and EMR.
4. **Athena = serverless SQL on S3.** Pay per TB scanned. Reduce cost with Parquet + partitioning.
5. **QuickSight = visualization.** It connects to Athena, S3, RDS, Redshift, and more.
6. **Lake Formation = Glue + fine-grained access control + governed tables.**
7. **EMR for complex big data (Spark/Hadoop); Glue for standard ETL.**
8. **OpenSearch for log analytics and full-text search.**

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The Analytics Pipeline Stages
- Reference Architecture: Real-Time Analytics Pipeline
- Amazon Kinesis (Review and Deep Dive)
- Amazon S3 as a Data Lake

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
