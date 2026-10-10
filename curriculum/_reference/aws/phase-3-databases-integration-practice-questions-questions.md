# Phase 3: Practice Questions (25 SAA-C03 Style)

**Instructions:** Choose the best answer for each question. Allow ~2 minutes per question (50 minutes total). Answers and explanations are at the end.

---

## Questions

### Question 1 — RDS Multi-AZ

A company runs a critical production application on an RDS MySQL database. The database must survive an Availability Zone failure with automatic failover and minimal data loss. The development team does NOT need to read from the standby instance. Which configuration meets these requirements with the LEAST operational overhead?

A. Create a Read Replica in another AZ and manually promote it during failures.
B. Enable Multi-AZ deployment on the RDS instance.
C. Set up an Aurora Global Database across two Regions.
D. Deploy two RDS instances and use Route 53 health checks for failover.

---

### Question 2 — RDS Read Replicas

An e-commerce application uses an RDS PostgreSQL database. The analytics team runs complex reporting queries that are degrading performance for production users. The company wants to offload analytics queries without affecting production. What should a solutions architect recommend?

A. Increase the RDS instance size to handle both workloads.
B. Create a Read Replica and direct analytics queries to the replica endpoint.
C. Enable RDS Proxy to distribute queries across multiple connections.
D. Move the database to Aurora Serverless v2 for automatic scaling.

---

### Question 3 — Aurora Architecture

A solutions architect is designing a relational database solution that must provide automatic storage scaling, self-healing storage, and support up to 15 read replicas. Which database service meets these requirements?

A. RDS MySQL with Multi-AZ
B. RDS PostgreSQL with Read Replicas
C. Amazon Aurora
D. DynamoDB with DAX

---

### Question 4 — Aurora Global Database

A multinational company needs a relational database solution that provides cross-Region disaster recovery with less than 1 second of replication lag. The database must use PostgreSQL. Which solution meets these requirements?

A. RDS PostgreSQL with a cross-Region Read Replica
B. Aurora PostgreSQL with Aurora Global Database
C. DynamoDB Global Tables
D. Aurora PostgreSQL with a cross-Region snapshot copy

---

### Question 5 — Aurora Serverless v2

A startup is launching a new application with unpredictable traffic patterns. During the day, the application may receive thousands of requests per minute, but at night traffic drops to near zero. They need a relational database that automatically scales compute capacity and minimizes cost during idle periods. Which solution is MOST cost-effective?

A. RDS MySQL with the smallest instance type
B. Aurora Serverless v2 with a minimum of 0.5 ACU
C. DynamoDB with on-demand capacity
D. RDS MySQL with Auto Scaling enabled

---

### Question 6 — DynamoDB Partition Keys

A gaming application stores player scores in a DynamoDB table. The table uses `game_date` as the partition key. During peak hours, the application experiences throttling errors. What is the MOST likely cause and solution?

A. The table does not have enough read capacity. Increase RCUs.
B. The partition key has low cardinality, causing hot partitions. Change the partition key to `player_id`.
C. DynamoDB Streams is not enabled. Enable Streams for better performance.
D. The table needs a Global Secondary Index for better distribution.

---

### Question 7 — DynamoDB GSI vs LSI

An application stores orders in a DynamoDB table with `user_id` as the partition key and `order_date` as the sort key. The team later realizes they need to query orders by `status` across all users. The table already has data. What should they do?

A. Create a Local Secondary Index (LSI) with `status` as the sort key.
B. Create a Global Secondary Index (GSI) with `status` as the partition key.
C. Recreate the table with `status` as the partition key.
D. Use Scan with a filter expression on `status`.

---

### Question 8 — DynamoDB DAX vs ElastiCache

An application reads the same popular items from DynamoDB thousands of times per second. The team wants to reduce read latency from milliseconds to microseconds without changing application code. Which solution meets these requirements?

A. Add ElastiCache Redis in front of DynamoDB.
B. Enable DynamoDB Accelerator (DAX).
C. Increase the provisioned read capacity units.
D. Enable DynamoDB Streams for faster reads.

---

### Question 9 — DynamoDB Global Tables

A company operates in North America and Europe. They need a NoSQL database that allows users in both regions to read AND write data with low latency. Which solution provides this capability?

A. DynamoDB with a cross-Region Read Replica
B. Aurora Global Database
C. DynamoDB Global Tables
D. RDS with cross-Region Read Replicas

---

### Question 10 — ElastiCache Redis vs Memcached

An application needs an in-memory caching layer with the following requirements: data must survive node failures, the cache must support Multi-AZ for high availability, and the team needs sorted sets for a real-time leaderboard feature. Which solution meets ALL requirements?

A. ElastiCache Memcached with multiple nodes
B. ElastiCache Redis with Multi-AZ and cluster mode
C. DynamoDB with DAX
D. ElastiCache Memcached with cross-AZ replication

---

### Question 11 — Caching Strategies

A web application uses ElastiCache to cache database query results. Users report that they sometimes see outdated data. The team wants to ensure cached data is always fresh while maintaining good read performance. Which caching strategy should they implement?

A. Lazy Loading with no TTL
B. Write-Through caching
C. Lazy Loading with a short TTL
D. Remove the cache and query the database directly

---

### Question 12 — Database Selection

A financial services company needs to maintain an immutable record of all transactions. The record must be cryptographically verifiable and cannot be modified or deleted after insertion. Which AWS database service meets this requirement?

A. DynamoDB with DynamoDB Streams
B. Amazon QLDB
C. Amazon Neptune
D. Amazon Redshift

---

### Question 13 — SQS Standard vs FIFO

An online ticket booking system processes purchase requests. Each request must be processed exactly once and in the exact order received to prevent double-booking. Which SQS configuration should be used?

A. Standard queue with client-side deduplication
B. FIFO queue with content-based deduplication
C. Standard queue with a Dead-Letter Queue
D. FIFO queue with visibility timeout set to 0

---

### Question 14 — SQS Visibility Timeout

A consumer application polls messages from an SQS queue and processes each message in approximately 5 minutes. The team notices that some messages are being processed by multiple consumers. What is the MOST likely cause?

A. The queue type is Standard instead of FIFO.
B. The visibility timeout is less than 5 minutes, so messages become visible again before processing completes.
C. Long polling is not enabled.
D. The Dead-Letter Queue is misconfigured.

---

### Question 15 — SQS + ASG Scaling

A company processes image uploads asynchronously. Images are submitted to an SQS queue, and EC2 instances in an Auto Scaling Group process them. During peak hours, the queue depth grows and processing slows down. What metric should be used to scale the Auto Scaling Group?

A. EC2 CPU utilization
B. SQS `ApproximateNumberOfMessagesVisible`
C. SQS `NumberOfMessagesSent`
D. EC2 network throughput

---

### Question 16 — SNS Fan-Out

An application needs to process each customer order in three different ways simultaneously: update inventory, send a confirmation email, and update analytics. A single order event should trigger all three processes. What architecture achieves this with the LEAST operational overhead?

A. Have the application call three different APIs sequentially.
B. Publish the order to an SNS topic with three SQS queue subscriptions (fan-out).
C. Write the order to three separate SQS queues from the application.
D. Use EventBridge with three Lambda targets.

---

### Question 17 — EventBridge vs SNS

A company receives events from a third-party SaaS platform (Zendesk) and needs to route specific events to different AWS services based on event content. The company also wants to archive all events for replay during debugging. Which service is BEST suited for this use case?

A. Amazon SNS with message filtering
B. Amazon EventBridge with partner event bus
C. Amazon SQS with multiple consumers
D. Amazon Kinesis Data Streams

---

### Question 18 — Kinesis vs SQS

A social media company needs to process millions of clickstream events per second. Multiple analytics applications need to independently consume the same stream of events, and the company must be able to replay events from the past 7 days. Which service should they use?

A. Amazon SQS Standard queue
B. Amazon SQS FIFO queue
C. Amazon Kinesis Data Streams
D. Amazon SNS

---

### Question 19 — Kinesis Data Firehose

A company collects application logs and needs to automatically deliver them to Amazon S3 for long-term storage. The delivery should happen with minimal management overhead, and data should be compressed to reduce storage costs. Exact real-time delivery is NOT required; a delay of up to 60 seconds is acceptable. Which service should they use?

A. Kinesis Data Streams with a Lambda consumer writing to S3
B. Kinesis Data Firehose with GZIP compression and S3 destination
C. SQS queue with a Lambda consumer writing to S3
D. S3 Transfer Acceleration

---

### Question 20 — API Gateway Types

A company needs to build a simple API that proxies requests to Lambda functions. They want the lowest possible cost and do not need API caching, API keys, or request validation. Which API Gateway type should they choose?

A. REST API
B. HTTP API
C. WebSocket API
D. AppSync GraphQL API

---

### Question 21 — API Gateway Authorizers

A mobile application uses Amazon Cognito User Pools for user authentication. Users sign in and receive a JWT token. The application needs to call an API Gateway REST API that validates the JWT token before allowing access. Which authorizer type should be configured?

A. IAM authorizer
B. Lambda authorizer
C. Cognito User Pool authorizer
D. API key authentication

---

### Question 22 — Step Functions

A company needs to orchestrate a multi-step data processing workflow. The workflow involves: validating input data (Lambda), processing the data (Lambda), and if processing fails, sending a notification (SNS) and retrying up to 3 times. The workflow may take up to 30 minutes. Which service should be used?

A. SQS with a DLQ
B. Step Functions Standard workflow
C. Step Functions Express workflow
D. EventBridge with scheduled rules

---

### Question 23 — Lambda + RDS

A serverless application uses AWS Lambda functions that connect to an RDS MySQL database. During traffic spikes, the database runs out of available connections, causing Lambda invocations to fail. What is the MOST effective solution?

A. Increase the Lambda concurrency limit.
B. Enable RDS Multi-AZ for better connection handling.
C. Use Amazon RDS Proxy to pool and share database connections.
D. Increase the RDS instance size.

---

### Question 24 — Redshift vs Athena

A company stores 5 TB of sales data in Amazon S3. The analytics team needs to run complex SQL queries on this data. They run queries a few times per week and want to minimize costs. Which solution is MOST cost-effective?

A. Load data into Amazon Redshift and run queries.
B. Use Amazon Athena to query data directly in S3.
C. Load data into an RDS PostgreSQL database.
D. Use Amazon Redshift Spectrum to query S3 data.

---

### Question 25 — Event-Driven Architecture

A company is designing a new microservices architecture. Service A generates order events that must be processed by Service B (inventory), Service C (billing), and Service D (notification). Each service must process events independently and at its own pace. If Service B is temporarily unavailable, its events must not be lost. Which architecture BEST meets these requirements?

A. Service A calls Services B, C, and D synchronously via API.
B. Service A publishes to an SNS topic. Services B, C, and D each subscribe with their own SQS queue.
C. Service A writes events to a DynamoDB table. Services B, C, and D poll the table.
D. Service A publishes to an SQS queue. Services B, C, and D share the queue.

---

## Answers and Explanations

### Question 1 — Answer: B

**Enable Multi-AZ deployment on the RDS instance.**

Multi-AZ provides automatic failover with synchronous replication to a standby in another AZ. The standby is not readable (which the question says is fine). This requires no operational overhead -- AWS handles the failover automatically. A Read Replica (A) requires manual promotion. Aurora Global Database (C) is for cross-Region, which is overkill. Manual setup with Route 53 (D) has high operational overhead.

---

### Question 2 — Answer: B

**Create a Read Replica and direct analytics queries to the replica endpoint.**

Read Replicas are specifically designed for offloading read traffic from the primary. Analytics queries run against the replica, leaving the primary free for production traffic. Increasing instance size (A) is expensive and does not decouple workloads. RDS Proxy (C) pools connections but does not offload read traffic. Aurora Serverless (D) helps with scaling but does not separate workloads.

---

### Question 3 — Answer: C

**Amazon Aurora.**

Aurora automatically scales storage up to 128 TB, has self-healing storage with 6 copies across 3 AZs, and supports up to 15 Aurora Replicas. Standard RDS (A, B) supports only 5 Read Replicas and does not have self-healing storage. DynamoDB (D) is NoSQL, not relational.

---

### Question 4 — Answer: B

**Aurora PostgreSQL with Aurora Global Database.**

Aurora Global Database provides cross-Region replication with typically less than 1 second lag. RDS cross-Region Read Replicas (A) have higher replication lag (seconds to minutes). DynamoDB Global Tables (C) is NoSQL, not PostgreSQL. Snapshot copy (D) does not provide continuous replication.

---

### Question 5 — Answer: B

**Aurora Serverless v2 with a minimum of 0.5 ACU.**

Aurora Serverless v2 scales compute capacity automatically based on demand and can scale down to 0.5 ACU during idle periods, minimizing cost. RDS MySQL (A) runs at a fixed instance size regardless of traffic. DynamoDB (C) is NoSQL, and the question requires relational. RDS does not have native Auto Scaling for compute (D).

---

### Question 6 — Answer: B

**The partition key has low cardinality, causing hot partitions.**

Using `game_date` as the partition key means all writes for the current day go to the same partition, creating a hot partition. Changing to `player_id` distributes writes evenly across many partitions. Increasing RCUs (A) helps but does not fix the root cause. Streams (C) does not affect performance. A GSI (D) does not fix the partition key distribution problem.

---

### Question 7 — Answer: B

**Create a Global Secondary Index (GSI) with `status` as the partition key.**

GSIs can be added to an existing table at any time and allow querying by different attributes. LSI (A) can only be created at table creation time. Recreating the table (C) causes downtime and data migration. Scan with filter (D) is expensive and slow because it reads the entire table.

---

### Question 8 — Answer: B

**Enable DynamoDB Accelerator (DAX).**

DAX provides microsecond read latency for DynamoDB and is a drop-in replacement (same API, no code changes). ElastiCache (A) requires application code changes to use a different API. Increasing RCUs (C) improves throughput but not latency. Streams (D) is for change capture, not read acceleration.

---

### Question 9 — Answer: C

**DynamoDB Global Tables.**

Global Tables provide multi-Region, active-active replication -- meaning users in both regions can read AND write. Aurora Global Database (B) is active-passive (writes only in the primary Region). DynamoDB does not have "cross-Region Read Replicas" (A). RDS Read Replicas (D) are read-only.

---

### Question 10 — Answer: B

**ElastiCache Redis with Multi-AZ and cluster mode.**

Redis supports persistence (data survives node failures), Multi-AZ for HA, and sorted sets for leaderboards. Memcached (A, D) does not support persistence, replication, or Multi-AZ. DAX (C) is DynamoDB-specific and does not have sorted sets.

---

### Question 11 — Answer: B

**Write-Through caching.**

Write-Through ensures that every write to the database also updates the cache, so cached data is always fresh. Lazy Loading with no TTL (A) allows data to become infinitely stale. Lazy Loading with short TTL (C) reduces staleness but does not guarantee freshness. Removing the cache (D) eliminates the performance benefit.

---

### Question 12 — Answer: B

**Amazon QLDB.**

QLDB provides an immutable, cryptographically verifiable transaction log. Data cannot be modified or deleted after insertion. DynamoDB (A) allows updates and deletes. Neptune (C) is a graph database with no immutability guarantee. Redshift (D) is a data warehouse, not a ledger.

---

### Question 13 — Answer: B

**FIFO queue with content-based deduplication.**

FIFO queues guarantee strict ordering and exactly-once processing, preventing double-booking. Standard queues (A, C) provide at-least-once delivery (possible duplicates) and best-effort ordering. Setting visibility timeout to 0 (D) would cause messages to be immediately visible to all consumers.

---

### Question 14 — Answer: B

**The visibility timeout is less than 5 minutes.**

If the visibility timeout expires before the consumer finishes processing, the message becomes visible again and another consumer picks it up. The fix is to increase the visibility timeout to at least 5 minutes (or longer). Standard vs FIFO (A) does not explain duplicate processing from the same queue. Long polling (C) affects empty responses, not duplicates. DLQ (D) handles failed messages, not duplicates.

---

### Question 15 — Answer: B

**SQS `ApproximateNumberOfMessagesVisible`.**

This metric represents the queue depth (number of messages waiting to be processed). As queue depth grows, more consumers are needed. CPU utilization (A) may not reflect the actual workload if instances are idle waiting for messages. Messages sent (C) reflects producer rate, not processing backlog. Network throughput (D) is not directly related to queue depth.

---

### Question 16 — Answer: B

**Publish the order to an SNS topic with three SQS queue subscriptions (fan-out).**

The SNS + SQS fan-out pattern delivers one message to multiple subscribers independently. Each SQS queue buffers messages for its respective consumer. Sequential API calls (A) are tightly coupled and slow. Writing to three queues (C) requires the application to know about all consumers. EventBridge (D) could work but has more complexity for a simple fan-out and SNS + SQS is the standard pattern.

---

### Question 17 — Answer: B

**Amazon EventBridge with partner event bus.**

EventBridge has built-in partner integrations (including Zendesk), supports content-based event routing with rules, and offers archive and replay capabilities. SNS (A) does not support partner integrations or archive/replay. SQS (C) does not support routing. Kinesis (D) is for streaming data, not event routing.

---

### Question 18 — Answer: C

**Amazon Kinesis Data Streams.**

Kinesis supports multiple independent consumers reading the same stream, data replay within the retention period (up to 365 days), and high throughput. SQS (A, B) does not support multiple consumers reading the same data (messages are deleted after processing). SNS (D) does not support replay.

---

### Question 19 — Answer: B

**Kinesis Data Firehose with GZIP compression and S3 destination.**

Firehose is fully managed, supports automatic GZIP compression, and delivers to S3 with configurable buffering (minimum 60 seconds). It requires no capacity management. Kinesis Data Streams + Lambda (A) works but requires more operational overhead. SQS + Lambda (C) is more complex. Transfer Acceleration (D) is for uploading to S3, not for log delivery.

---

### Question 20 — Answer: B

**HTTP API.**

HTTP API costs ~$1.00 per million requests (vs ~$3.50 for REST API) and has lower latency. Since the question states no need for caching, API keys, or request validation (features only available in REST API), HTTP API is the best choice. WebSocket (C) is for bidirectional communication. AppSync (D) is for GraphQL.

---

### Question 21 — Answer: C

**Cognito User Pool authorizer.**

When using Cognito User Pools for authentication, the native Cognito authorizer validates JWT tokens directly without requiring custom code. IAM authorizer (A) is for SigV4-signed requests, not JWT tokens. Lambda authorizer (B) works but adds unnecessary complexity and cost. API keys (D) are for throttling, not authentication.

---

### Question 22 — Answer: B

**Step Functions Standard workflow.**

Step Functions provides built-in retry logic, error handling, and workflow orchestration. Standard workflows support executions up to 1 year (more than enough for 30 minutes) and provide exactly-once execution. Express workflows (C) are limited to 5 minutes. SQS + DLQ (A) handles retries but does not orchestrate multi-step workflows. EventBridge (D) is for event routing, not workflow orchestration.

---

### Question 23 — Answer: C

**Use Amazon RDS Proxy to pool and share database connections.**

RDS Proxy is specifically designed for Lambda + RDS scenarios. It pools database connections so that thousands of concurrent Lambda invocations share a small number of actual database connections. Increasing concurrency (A) makes the problem worse. Multi-AZ (B) does not increase connection limits. Increasing instance size (D) increases the connection limit but is more expensive than Proxy.

---

### Question 24 — Answer: B

**Use Amazon Athena to query data directly in S3.**

Athena is serverless, requires no infrastructure setup, and charges only per TB of data scanned. For infrequent queries, Athena is significantly cheaper than running a Redshift cluster 24/7 (A). Loading into RDS (C) is operationally heavy for 5 TB. Redshift Spectrum (D) still requires a running Redshift cluster.

---

### Question 25 — Answer: B

**Service A publishes to an SNS topic. Services B, C, and D each subscribe with their own SQS queue.**

This is the classic fan-out pattern. Each service gets its own SQS queue, ensuring independent processing and buffering. If Service B is unavailable, its messages stay in its SQS queue until it recovers. Synchronous calls (A) are tightly coupled and fail if any service is down. DynamoDB polling (C) is inefficient. Sharing one SQS queue (D) means only one service would receive each message (competing consumers).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Question 1 — RDS Multi-AZ
- Question 2 — RDS Read Replicas
- Question 3 — Aurora Architecture
- Question 4 — Aurora Global Database

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
