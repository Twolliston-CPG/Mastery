# Phase 3: Databases & Application Integration (Weeks 5-6)

## Phase Overview

Phase 3 shifts focus to the data layer and the glue that holds modern AWS architectures together. You will learn when to reach for a relational database versus a NoSQL store, how to cache data at the edge or in-memory, and how to decouple services with queues, topics, event buses, and streams. By the end of these two weeks you will be comfortable designing data-tier architectures and loosely coupled, event-driven systems -- skills that account for roughly 25-30% of SAA-C03 exam questions.

The phase is split into two weeks:

- **Week 5 -- Databases:** RDS, Aurora, DynamoDB, ElastiCache, and purpose-built databases (Redshift, Neptune, DocumentDB, Keyspaces, QLDB, Timestream).
- **Week 6 -- Application Integration:** SQS, SNS, EventBridge, Kinesis, API Gateway, Step Functions, AppSync, and Amazon MQ.

---

## Prerequisites

- **Phase 1 and Phase 2 Complete:** You should have a working AWS account, be comfortable with IAM, VPC networking, EC2, Lambda, and S3.
- **Tools Installed:**
  - AWS CLI v2 configured with a named profile (`aws configure --profile saa-study`)
  - Python 3.10+ with `boto3` installed
  - Terraform >= 1.5
  - A MySQL client (e.g., `mysql` CLI or MySQL Workbench) for the RDS lab
- **Budget:** A valid payment method on your AWS account. Most labs use Free Tier. The RDS lab may cost $2-5 if not torn down promptly.

---

## Learning Objectives

By completing Phase 3 you will be able to:

1. Choose the correct AWS database service for a given set of requirements (relational, key-value, graph, ledger, time-series, in-memory, data warehouse).
2. Configure RDS Multi-AZ for high availability and Read Replicas for read scaling, and explain the difference.
3. Describe Aurora's storage architecture, replication model, and when to choose Aurora over standard RDS.
4. Design DynamoDB tables with appropriate partition keys, sort keys, and secondary indexes (LSI vs GSI).
5. Implement caching strategies with ElastiCache (Lazy Loading, Write-Through) and choose between Redis and Memcached.
6. Decouple application components using SQS (Standard and FIFO), SNS fan-out, and EventBridge event routing.
7. Distinguish between SQS (messaging) and Kinesis (streaming) and select the right service for a given scenario.
8. Build a REST API with API Gateway backed by Lambda and DynamoDB.
9. Describe Step Functions workflow orchestration and when to use Standard vs Express workflows.
10. Design and implement an end-to-end event-driven architecture using multiple integration services.

---

## Estimated Time

| Activity | Hours |
|---|---|
| Notes (reading and review) | 12-14 |
| Hands-on Labs (5 labs) | 8-10 |
| Projects (2 projects) | 6-8 |
| Practice Questions and Review | 3-4 |
| **Total** | **29-36 hours over 2 weeks** |

Suggested pace: ~2.5 hours per day across 14 days.

---

## Services Covered

### Databases (Week 5)
- Amazon RDS (MySQL, PostgreSQL, MariaDB, Oracle, SQL Server, RDS Custom)
- Amazon Aurora (MySQL/PostgreSQL compatible, Serverless v2, Global Database)
- Amazon DynamoDB (key-value/document, DAX, Global Tables, Streams)
- Amazon ElastiCache (Redis, Memcached)
- Amazon Redshift (data warehouse, Spectrum, Serverless)
- Amazon Neptune (graph)
- Amazon DocumentDB (MongoDB compatible)
- Amazon Keyspaces (Cassandra compatible)
- Amazon QLDB (ledger)
- Amazon Timestream (time-series)

### Application Integration (Week 6)
- Amazon SQS (Standard and FIFO queues)
- Amazon SNS (topics, subscriptions, fan-out, message filtering)
- Amazon EventBridge (event buses, rules, schema registry, archive/replay)
- Amazon Kinesis (Data Streams, Data Firehose, Data Analytics)
- Amazon API Gateway (REST, HTTP, WebSocket APIs)
- AWS Step Functions (Standard and Express workflows)
- AWS AppSync (managed GraphQL)
- Amazon MQ (ActiveMQ, RabbitMQ)

---

## What You Will Build

### Labs

| Lab | Description | Tools | Estimated Cost |
|---|---|---|---|
| Lab 01 -- RDS MySQL Setup | Launch RDS MySQL, configure Multi-AZ, create Read Replica, test failover | CLI + Boto3 + Terraform | ~$2-5 (tear down fast) |
| Lab 02 -- DynamoDB CRUD | Create table, CRUD with Boto3, add GSI, enable Streams, configure TTL | Python/Boto3 | Free Tier |
| Lab 03 -- SQS & SNS Messaging | Create queues, send/receive messages, SNS fan-out, DLQ | CLI + Boto3 | Free Tier |
| Lab 04 -- API Gateway + Lambda + DynamoDB | Build a full CRUD REST API end-to-end | Python + CLI | Free Tier (mostly) |
| Lab 05 -- Kinesis Streaming | Kinesis Data Stream, produce/consume, Firehose to S3 | Boto3 + CLI | ~$1-3 |

### Projects

| Project | Description | Estimated Cost |
|---|---|---|
| Event-Driven Architecture | API Gateway -> Lambda -> SQS -> Lambda -> DynamoDB with SNS notifications, DLQ, CloudWatch | ~$1-3 |
| Real-Time Data Pipeline | Kinesis Streams -> Lambda -> DynamoDB + S3 via Firehose (simulated IoT data) | ~$1-3 |

**Total Phase 3 estimated spend: $5-14** (tear down all resources after each session).

---

## Directory Structure

**`phase-3-databases-integration/`**

- `README.md` — This file
- `notes/`
  - `01-rds.md` — RDS engines, Multi-AZ, Read Replicas, backups
  - `02-aurora.md` — Aurora architecture, Serverless v2, Global DB
  - `03-dynamodb.md` — Keys, indexes, Streams, DAX, Global Tables
  - `04-elasticache.md` — Redis vs Memcached, caching strategies
  - `05-other-databases.md` — Redshift, Neptune, DocumentDB, Keyspaces, QLDB, Timestream
  - `06-sqs.md` — Standard vs FIFO, visibility timeout, DLQ
  - `07-sns-eventbridge.md` — SNS fan-out, EventBridge rules, comparison
  - `08-kinesis.md` — Data Streams, Firehose, Analytics
  - `09-api-gateway-step-functions.md` — API types, Step Functions, AppSync, MQ
- `labs/`
  - `lab-01-rds-mysql-setup.md`
  - `lab-02-dynamodb-crud.md`
  - `lab-03-sqs-sns-messaging.md`
  - `lab-04-api-gateway-lambda-dynamodb.md`
  - `lab-05-kinesis-streaming.md`
- `projects/`
  - `project-01-event-driven-architecture.md`
  - `project-02-real-time-data-pipeline.md`
- `practice-questions/`
  - `questions.md` — 25 SAA-style scenario questions
- `cheat-sheets/`
  - `databases-cheat-sheet.md` — All database services at a glance
  - `messaging-integration-cheat-sheet.md` — SQS, SNS, EventBridge, Kinesis, API GW


---

## Suggested Weekly Schedule

### Week 5 -- Databases

| Day | Activity |
|---|---|
| Day 1 | Read notes 01 (RDS) and 02 (Aurora) |
| Day 2 | Complete Lab 01 (RDS MySQL Setup) -- **tear down when done** |
| Day 3 | Read notes 03 (DynamoDB) |
| Day 4 | Complete Lab 02 (DynamoDB CRUD) |
| Day 5 | Read notes 04 (ElastiCache) and 05 (Other Databases) |
| Day 6 | Review databases cheat sheet; do practice questions 1-12 |
| Day 7 | Rest or catch up |

### Week 6 -- Application Integration

| Day | Activity |
|---|---|
| Day 8 | Read notes 06 (SQS) and 07 (SNS & EventBridge) |
| Day 9 | Complete Lab 03 (SQS & SNS Messaging) |
| Day 10 | Read notes 08 (Kinesis) and 09 (API Gateway & Step Functions) |
| Day 11 | Complete Lab 04 (API Gateway + Lambda + DynamoDB) and Lab 05 (Kinesis) |
| Day 12-13 | Build Project 01 (Event-Driven Architecture) and/or Project 02 (Real-Time Pipeline) -- **tear down when done** |
| Day 14 | Review messaging cheat sheet; do practice questions 13-25; revisit weak areas |

---

## Tips for Success

- **Understand the "why":** The exam rarely asks you to configure a service step-by-step. Instead it asks you to choose the right service or feature for a given scenario. Focus on decision criteria.
- **Comparison tables are your friend:** This phase includes many "X vs Y" decisions (RDS vs Aurora, Redis vs Memcached, SQS vs Kinesis). Commit the key differences to memory.
- **DynamoDB is heavily tested:** Understand partition keys, sort keys, GSI vs LSI, capacity modes, and DAX. Expect 3-5 questions on DynamoDB alone.
- **Tear down RDS and Kinesis resources:** These are the most expensive resources in this phase. Delete them as soon as you finish each lab.
- **Build the projects:** The event-driven architecture project ties together nearly every integration service in this phase. It is the single best thing you can do to prepare for the exam.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Suggested Weekly Schedule
- Databases (Week 5)
- Application Integration (Week 6)
- Projects

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
