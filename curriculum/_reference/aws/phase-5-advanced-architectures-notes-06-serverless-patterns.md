# Serverless Architecture Patterns

## Why This Matters for the Exam

Serverless architectures are tested across all four SAA-C03 domains. You will see scenario questions asking you to design event-driven systems, choose between serverless and containers, and select the right combination of services. The exam rewards candidates who can assemble multi-service architectures from building blocks.

---

## What "Serverless" Means on AWS

Serverless does NOT mean "no servers." It means YOU do not manage, provision, or patch servers. AWS handles all infrastructure.

**Serverless services on AWS:**
- Lambda (compute)
- API Gateway (HTTP endpoints)
- DynamoDB (database)
- S3 (storage)
- Step Functions (orchestration)
- EventBridge (event routing)
- SQS / SNS (messaging)
- Cognito (authentication)
- AppSync (GraphQL)
- Fargate (container compute -- serverless containers)
- Aurora Serverless (relational database)

---

## Pattern 1: API Gateway + Lambda + DynamoDB (REST API)

This is the most common serverless pattern and the foundation of many exam questions.

### Architecture

```
Client (Browser/Mobile)
    |
    | HTTPS
    v
+-------------------+
| Amazon CloudFront | (optional -- caching + global distribution)
+-------------------+
    |
    v
+-------------------+
| API Gateway       | (REST API or HTTP API)
| (rate limiting,   |
|  auth, throttling)|
+-------------------+
    |
    | Lambda Proxy Integration
    v
+-------------------+
| AWS Lambda        | (business logic)
| (Python/Node.js)  |
+-------------------+
    |
    | Boto3 SDK calls
    v
+-------------------+
| DynamoDB          | (NoSQL data store)
| (on-demand or     |
|  provisioned)     |
+-------------------+
```

### Request Flow

1. Client sends HTTPS request to API Gateway endpoint.
2. API Gateway validates the request (auth, throttling, input validation).
3. API Gateway invokes the Lambda function (proxy integration passes the full request).
4. Lambda executes business logic and interacts with DynamoDB.
5. Lambda returns a response to API Gateway.
6. API Gateway sends the response to the client.

### When to Use

- RESTful APIs with variable traffic patterns.
- CRUD applications.
- Mobile/web backends.
- Microservice endpoints.

### Cost Characteristics

- **Pay per request** -- no cost when idle.
- API Gateway: $1.00 per million requests (REST API) or $3.50 per million (HTTP API).
- Lambda: $0.20 per million requests + compute duration.
- DynamoDB: On-demand pricing or provisioned capacity.

### Exam Tips for This Pattern

- **HTTP API is cheaper than REST API** for simple proxy-to-Lambda use cases.
- **REST API** when you need: API keys, usage plans, request validation, WAF integration, caching, or resource policies.
- **DynamoDB on-demand** for unpredictable traffic; **provisioned with auto-scaling** for predictable traffic.
- **Lambda execution role** needs IAM permissions to access DynamoDB.
- **API Gateway authorizers:** Cognito User Pools, Lambda authorizer, or IAM authorization.

---

## Pattern 2: S3 + Lambda + Step Functions (File Processing)

### Architecture

```
User uploads file
    |
    v
+-------------------+
| S3 Bucket         | (trigger on PutObject)
| (source bucket)   |
+-------------------+
    |
    | S3 Event Notification
    v
+-------------------+
| AWS Lambda        | (validate file, start workflow)
| (validator)       |
+-------------------+
    |
    | Start execution
    v
+----------------------------+
| AWS Step Functions         |
| (state machine)            |
|                            |
|  +-- Step 1: Parse file    |
|  |   (Lambda)              |
|  +-- Step 2: Transform     |
|  |   (Lambda)              |
|  +-- Step 3: Enrich        |
|  |   (Lambda)              |
|  +-- Step 4: Store         |
|      (Lambda -> DynamoDB)  |
|                            |
|  +-- Error: Notify         |
|      (SNS -> Email)        |
+----------------------------+
    |
    v
+-------------------+
| S3 Bucket         | (processed output)
| (destination)     |
+-------------------+
```

### Request Flow

1. User uploads a file to the S3 source bucket.
2. S3 sends an event notification to a Lambda function.
3. Lambda validates the file and starts a Step Functions execution.
4. Step Functions orchestrates multiple Lambda functions in sequence (or parallel).
5. Each step processes, transforms, or enriches the data.
6. Final step stores results in DynamoDB and/or a destination S3 bucket.
7. If any step fails, Step Functions routes to an error handler (SNS notification).

### When to Use

- Multi-step file processing (image resizing, document conversion, ETL).
- Workflows that need retries, error handling, and conditional branching.
- Long-running processes that exceed Lambda's 15-minute timeout (chain multiple Lambda steps).

### Why Step Functions Over Chaining Lambdas

| Approach | Pros | Cons |
|---|---|---|
| Lambda chaining (one invokes the next) | Simple for 2-3 steps | Hard to debug, no visual tracking, error handling is manual |
| Step Functions | Visual workflow, built-in retry/error handling, parallel execution, wait states | Additional cost per state transition |

**Exam tip:** If the question describes a "multi-step workflow" or "orchestrate multiple Lambda functions," the answer is Step Functions.

---

## Pattern 3: EventBridge-Driven Architecture

### Architecture

```
Event Sources                    EventBridge                    Targets
+------------------+            +------------------+           +------------------+
| S3 (object       |            |                  |           | Lambda           |
|  created/deleted)|----------->|                  |---------->| (process event)  |
+------------------+            |                  |           +------------------+
                                |   EventBridge    |
+------------------+            |   (Default Bus)  |           +------------------+
| DynamoDB Streams |----------->|                  |---------->| Step Functions   |
| (item changed)   |            |   Rules:         |           | (start workflow) |
+------------------+            |   - Pattern match|           +------------------+
                                |   - Schedule     |
+------------------+            |   - Route to     |           +------------------+
| CloudWatch       |----------->|     targets      |---------->| SQS Queue        |
| (alarm state     |            |                  |           | (buffer events)  |
|  changed)        |            |                  |           +------------------+
+------------------+            |                  |
                                |                  |           +------------------+
+------------------+            |                  |---------->| SNS Topic        |
| Custom App       |----------->|                  |           | (notify team)    |
| (PutEvents API)  |            |                  |           +------------------+
+------------------+            +------------------+

```

### Key Concepts

**Event Bus:** A pipeline that receives events. Types:
- **Default event bus:** Receives events from AWS services automatically.
- **Custom event bus:** Receives events from your applications.
- **Partner event bus:** Receives events from SaaS partners (Zendesk, Datadog, etc.).

**Rules:** Filter events using pattern matching. Each rule has one or more targets.

**Event pattern matching example:**
```json
{
    "source": ["aws.s3"],
    "detail-type": ["Object Created"],
    "detail": {
        "bucket": {
            "name": ["my-important-bucket"]
        }
    }
}
```

### When to Use EventBridge

- Decoupled event-driven architectures.
- Responding to AWS service events (EC2 state change, S3 upload, RDS snapshot).
- Scheduled tasks (cron-like, replacing CloudWatch Events).
- Integrating with SaaS partners.
- Fan-out to multiple targets from a single event.

### EventBridge vs SNS

| Feature | EventBridge | SNS |
|---|---|---|
| Event filtering | Rich content-based filtering (JSON pattern matching) | Basic message attribute filtering |
| Event sources | 100+ AWS services, SaaS partners, custom apps | Your applications |
| Targets | 20+ target types (Lambda, Step Functions, SQS, API Gateway, etc.) | Lambda, SQS, HTTP, Email, SMS |
| Schema registry | Yes (discover and validate event schemas) | No |
| Archive and replay | Yes (replay past events) | No |
| Scheduling | Yes (cron/rate expressions) | No |
| Throughput | Lower (soft limit ~10,000 events/sec/region) | Higher (potentially millions/sec) |

**Exam tip:** If the question mentions "event-driven," "respond to AWS service events," or "schedule tasks," EventBridge is typically the best answer. If the question requires "high-throughput fan-out to SQS queues," SNS + SQS fan-out may be better.

---

## Pattern 4: SQS-Based Decoupling

### Architecture (Queue-Based Load Leveling)

```
Producers                    Queue                    Consumers
+------------------+      +------------------+      +------------------+
| API Gateway +    |      |                  |      | Lambda           |
| Lambda           |----->| SQS Queue        |----->| (auto-triggered  |
| (receive orders) |      | (Standard or     |      |  by SQS)         |
+------------------+      |  FIFO)           |      +------------------+
                          |                  |              |
+------------------+      | DLQ (Dead Letter |              v
| EC2 / ECS        |----->|  Queue) for      |      +------------------+
| (batch producer) |      |  failed messages |      | DynamoDB         |
+------------------+      +------------------+      | (store results)  |
                                                    +------------------+
```

### SQS + ASG Scaling Pattern

```
+------------------+      +------------------+      +------------------+
| Producers        |----->| SQS Queue        |----->| EC2 (ASG)        |
|                  |      |                  |      | (consumers)      |
+------------------+      +------------------+      +------------------+
                                |                          ^
                                |                          |
                          CloudWatch Metric           ASG Scaling
                          (ApproximateNumberOfMessages)  Policy
                                |                          |
                                +--------------------------+
                                   "If queue depth > 1000,
                                    add 2 instances"
```

### When to Use SQS Decoupling

- **Buffer bursty traffic:** Accept messages at any rate, process at a controlled rate.
- **Decouple components:** Producer does not need to know about consumer availability.
- **Handle failures gracefully:** Failed messages go to DLQ for later analysis.
- **Scale consumers independently:** Auto-scale based on queue depth.

### Standard vs FIFO Queue Decision

| Requirement | Queue Type |
|---|---|
| Maximum throughput needed | Standard (nearly unlimited) |
| Ordering does not matter | Standard |
| At-least-once delivery is fine | Standard |
| Messages must be processed in exact order | FIFO |
| No duplicate processing allowed | FIFO (exactly-once) |
| Throughput < 3,000 msg/sec with batching | FIFO is fine |

---

## Serverless vs Containers vs EC2 Decision Guide

This is a critical exam decision framework. The question will describe a workload, and you need to select the right compute model.

### Comparison Table

| Factor | Serverless (Lambda) | Containers (ECS/EKS Fargate) | EC2 |
|---|---|---|---|
| **Execution duration** | Max 15 minutes | No limit | No limit |
| **Scaling** | Automatic, per-request | Task-level auto-scaling | Instance-level auto-scaling |
| **Scale to zero** | Yes (no cost when idle) | Yes (Fargate) | No (minimum 1 instance) |
| **Startup latency** | Cold start (100ms-10s) | Container pull (seconds) | Instance launch (minutes) |
| **State** | Stateless (use DynamoDB/S3 for state) | Can be stateful (with EBS/EFS) | Fully stateful |
| **Package size** | 250 MB (unzipped) / 10 GB (container) | No practical limit | No limit |
| **Runtime control** | Limited (supported runtimes) | Full control (any runtime) | Full OS control |
| **Networking** | VPC optional, limited socket control | Full VPC integration | Full network control |
| **Pricing** | Per request + duration | Per vCPU + memory (per second) | Per instance (per second/hour) |
| **Operational overhead** | Lowest | Medium | Highest |
| **Vendor lock-in** | Higher (Lambda-specific patterns) | Lower (containers are portable) | Lowest |

### Decision Guide

```
Start: What is the workload type?
  |
  +--> Event-driven, short-lived tasks (< 15 min)?
  |      |
  |      +-- Yes --> Lambda (serverless)
  |
  +--> Long-running process, needs specific runtime/libraries?
  |      |
  |      +-- Yes --> Containers (ECS/EKS)
  |              |
  |              +--> Want to manage EC2 instances?
  |                    |
  |                    +-- No  --> Fargate (serverless containers)
  |                    +-- Yes --> ECS/EKS on EC2 (more control, possibly cheaper at scale)
  |
  +--> Need full OS access, GPU, specific hardware?
  |      |
  |      +-- Yes --> EC2
  |
  +--> Variable/unpredictable traffic with periods of zero traffic?
  |      |
  |      +-- Yes --> Lambda or Fargate (scale to zero)
  |
  +--> Steady, predictable high traffic?
         |
         +-- Yes --> EC2 with Reserved Instances (cheapest) or ECS on EC2
```

### Exam Scenarios

| Scenario | Answer | Why |
|---|---|---|
| "Process S3 upload events, each taking 2 minutes" | Lambda | Event-driven, short duration |
| "Run a Java application 24/7 with specific libraries" | ECS Fargate or EC2 | Long-running, needs specific runtime |
| "Thumbnail generation for uploaded images" | Lambda | Event-driven, short-lived |
| "Microservices with 10 different services, Docker-based" | ECS/EKS Fargate | Containerized microservices |
| "Machine learning inference with GPU" | EC2 (P3/P4 instances) | GPU access required |
| "Web app with variable traffic, sometimes zero" | Lambda + API Gateway | Scales to zero, pay-per-use |
| "Batch processing 100GB of data nightly" | AWS Batch or Step Functions + Lambda | Batch workload |
| "Run Kubernetes workloads without managing nodes" | EKS on Fargate | Kubernetes + serverless |

---

## Complete Serverless Architecture Example: E-Commerce Backend

```
                              +------------------+
                              | CloudFront       |
                              | (CDN, HTTPS)     |
                              +--------+---------+
                                       |
                    +------------------+------------------+
                    |                                     |
            +-------+--------+                   +-------+--------+
            | S3 Bucket      |                   | API Gateway    |
            | (Static Site:  |                   | (REST API)     |
            |  HTML/CSS/JS)  |                   +-------+--------+
            +----------------+                           |
                                                 +-------+--------+
                                                 | Cognito        |
                                                 | (User Pools:   |
                                                 |  auth/signup)  |
                                                 +-------+--------+
                                                         |
                                          +--------------+--------------+
                                          |              |              |
                                   +------+---+   +-----+----+  +-----+----+
                                   | Lambda   |   | Lambda   |  | Lambda   |
                                   | (orders) |   | (users)  |  | (catalog)|
                                   +------+---+   +-----+----+  +-----+----+
                                          |              |              |
                                   +------+---+   +-----+----+  +-----+----+
                                   | DynamoDB  |   | DynamoDB |  | DynamoDB |
                                   | (orders)  |   | (users)  |  | (catalog)|
                                   +------+---+   +----------+  +----------+
                                          |
                                   +------+---+
                                   | SQS Queue |
                                   | (order    |
                                   |  process) |
                                   +------+---+
                                          |
                                   +------+---+
                                   | Lambda   |
                                   | (fulfill)|
                                   +------+---+
                                          |
                                   +------+---+
                                   | SNS Topic |
                                   | (notify   |
                                   |  customer)|
                                   +----------+
```

---

## Key Takeaways

1. **API Gateway + Lambda + DynamoDB** is the default serverless pattern. Know it cold.
2. **Step Functions orchestrate multi-step workflows** -- use them instead of chaining Lambdas.
3. **EventBridge is the event router** -- replaces cron jobs and responds to AWS service events.
4. **SQS decouples and buffers** -- use it to protect downstream services from burst traffic.
5. **Lambda for event-driven, < 15 min tasks.** Containers for long-running or complex runtimes. EC2 for full control.
6. **The exam loves "minimal operational overhead"** -- this almost always means serverless.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What "Serverless" Means on AWS
- Pattern 1: API Gateway + Lambda + DynamoDB (REST API)
- Pattern 2: S3 + Lambda + Step Functions (File Processing)
- Pattern 3: EventBridge-Driven Architecture

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
