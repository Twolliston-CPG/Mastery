# 05 — Lambda & Serverless

## Table of Contents
1. [What is AWS Lambda](#what-is-aws-lambda)
2. [Execution Model](#execution-model)
3. [Concurrency](#concurrency)
4. [Event Sources and Triggers](#event-sources-and-triggers)
5. [Lambda Layers](#lambda-layers)
6. [Versions and Aliases](#versions-and-aliases)
7. [Lambda@Edge vs CloudFront Functions](#lambdaedge-vs-cloudfront-functions)
8. [Lambda Limits](#lambda-limits)
9. [Lambda Networking](#lambda-networking)
10. [Lambda Destinations](#lambda-destinations)
11. [Key Takeaways for the Exam](#key-takeaways-for-the-exam)

---

## What is AWS Lambda

AWS Lambda is a serverless compute service that runs your code in response to events. You upload your code, and Lambda handles provisioning, scaling, patching, and high availability.

**Key characteristics:**
- No servers to manage.
- Pay per invocation and per compute time (GB-seconds).
- Scales automatically from 0 to thousands of concurrent executions.
- Supports Python, Node.js, Java, C#, Go, Ruby, and custom runtimes.
- Integrates with dozens of AWS services as event sources.

**Free tier:** 1 million requests and 400,000 GB-seconds per month (perpetual, not just 12 months).

---

## Execution Model

### Lifecycle of a Lambda Invocation

**Cold start versus warm invocation**

| Cold start — every step runs | Warm invocation |
|---|---|
| download the code | |
| start the execution environment | |
| initialise the runtime | |
| **run init code** (outside the handler) | |
| execute `handler()` | execute `handler()` |

Everything above the handler runs **once per execution environment**, not once per request. That is
why you open database connections and load configuration *outside* the handler — and why a VPC
Lambda's ENI attachment used to dominate cold start time.

- **Cold start**: Happens when there is no available execution environment. Lambda must download your code, start a container, initialize the runtime, and run any code outside the handler function. Takes 100ms to a few seconds.
- **Warm invocation**: A previously initialized environment is reused. Only the handler function runs. Much faster.
- **Init code** (outside the handler): Runs once per cold start. Use this for expensive initialization (database connections, loading ML models, reading config).

```python
import boto3

# This runs ONCE during cold start (init phase)
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('my-table')

def lambda_handler(event, context):
    # This runs on EVERY invocation
    response = table.get_item(Key={'id': event['id']})
    return response['Item']
```

### Invocation Types

| Type | Behavior | Retries | Example |
|---|---|---|---|
| **Synchronous** | Caller waits for the response | No automatic retries (caller retries) | API Gateway, ALB, CloudFront |
| **Asynchronous** | Lambda queues the event, caller gets 202 | 2 retries (total 3 attempts) with backoff | S3, SNS, EventBridge, CloudFormation |
| **Event Source Mapping** | Lambda polls a stream/queue | Depends on source (retries until expiry for streams) | SQS, Kinesis, DynamoDB Streams |

**Asynchronous failure handling:**
- After 2 retries, the event goes to a **Dead Letter Queue (DLQ)** if configured (SQS or SNS).
- Or configure **Lambda Destinations** (success and failure destinations).

---

## Concurrency

### Types of Concurrency

| Type | Description |
|---|---|
| **Unreserved concurrency** | Shared pool available to all functions in the account. Default account limit: 1,000 concurrent executions. |
| **Reserved concurrency** | A portion of the account limit exclusively for one function. Guarantees that function always has capacity. Limits its max concurrency. No extra cost. |
| **Provisioned concurrency** | Pre-initializes a specified number of execution environments. Eliminates cold starts. Costs money (you pay for always-on environments). |

### Concurrency Examples

Account limit: 1,000 concurrent executions.

- Function A: reserved concurrency = 100 (guaranteed 100, max 100).
- Function B: reserved concurrency = 200 (guaranteed 200, max 200).
- All other functions share the remaining 700 unreserved concurrent executions.

### Burst Concurrency

- In each region, Lambda can burst by 500-3,000 concurrent executions per minute (region-dependent).
- After the burst limit, Lambda scales at 500 additional concurrent executions per minute.

### Throttling

- When concurrency limit is reached, additional invocations are **throttled**.
- Synchronous invocations: return 429 (Too Many Requests).
- Asynchronous invocations: Lambda retries with backoff, then sends to DLQ.

**Exam tip:** If a question says "eliminate cold starts for a production function" — Provisioned Concurrency. If it says "prevent one function from consuming all capacity" — Reserved Concurrency.

---

## Event Sources and Triggers

### Common Event Sources

| Source | Invocation Type | Key Notes |
|---|---|---|
| **API Gateway** | Synchronous | REST or HTTP APIs, request/response |
| **ALB** | Synchronous | Lambda as a target group |
| **S3** | Asynchronous | Object created, deleted, restored |
| **SNS** | Asynchronous | Pub/sub messaging |
| **EventBridge** | Asynchronous | Event-driven rules and schedules |
| **CloudWatch Logs** | Asynchronous | Log stream processing |
| **SQS** | Event Source Mapping | Lambda polls the queue |
| **SQS FIFO** | Event Source Mapping | Ordered processing |
| **Kinesis Data Streams** | Event Source Mapping | Real-time stream processing |
| **DynamoDB Streams** | Event Source Mapping | React to table changes |
| **Cognito** | Synchronous | User pool triggers |
| **CloudFront** | Synchronous | Lambda@Edge |

### Event Source Mapping — Details

For SQS, Kinesis, and DynamoDB Streams, Lambda **polls** the source (not pushed by the source).

**SQS specifics:**
- Lambda long-polls the queue.
- Batch size: 1-10 messages.
- On failure: message returns to the queue after visibility timeout.
- Set up a DLQ **on the SQS queue** (not on Lambda) for failed messages.

**Kinesis / DynamoDB Streams specifics:**
- Lambda reads records in order, per shard.
- If a record fails, the entire batch is retried (blocks the shard).
- Solutions: configure `BisectBatchOnFunctionError` (split the batch), `MaximumRetryAttempts`, `MaximumRecordAgeInSeconds`, or an `OnFailure` destination.

---

## Lambda Layers

A .zip archive containing libraries, custom runtimes, or other dependencies that you can share across multiple functions.

**Benefits:**
- Keep deployment packages small (separate code from dependencies).
- Share common code (e.g., a utility library) across multiple functions.
- Up to **5 layers per function**.
- Total unzipped size (function + all layers) must be under 250 MB.

**Example uses:**
- Python: Package `pandas`, `numpy`, `boto3` in a layer.
- Custom runtime: Package a Rust or Bash runtime.

---

## Versions and Aliases

### Versions

- When you publish a version, Lambda creates an immutable snapshot of your function code and configuration.
- Each version gets a unique ARN: `arn:aws:lambda:us-east-1:123456789012:function:my-func:1`.
- `$LATEST` is the mutable, unpublished version you work on.

### Aliases

- A named pointer to a specific version (e.g., `prod` -> version 5, `dev` -> version 8).
- Aliases have their own ARN: `arn:aws:lambda:us-east-1:123456789012:function:my-func:prod`.
- **Traffic shifting**: An alias can split traffic between two versions for canary deployments.

```
Alias "prod" -> 90% version 5, 10% version 6
```

**Exam tip:** Aliases enable blue/green and canary deployments for Lambda. Use CodeDeploy with Lambda aliases for automated traffic shifting.

---

## Lambda@Edge vs CloudFront Functions

Both run code at CloudFront edge locations. Key differences:

| Feature | **CloudFront Functions** | **Lambda@Edge** |
|---|---|---|
| **Runtime** | JavaScript only | Node.js, Python |
| **Execution location** | 218+ CloudFront edge locations | ~13 regional edge caches |
| **Scale** | Millions of requests/sec | Thousands of requests/sec |
| **Max execution time** | < 1 ms | 5 sec (viewer) / 30 sec (origin) |
| **Max memory** | 2 MB | 128 - 10,240 MB |
| **Network access** | No | Yes |
| **File system access** | No | No |
| **Request body access** | No | Yes |
| **Triggers** | Viewer Request, Viewer Response | Viewer Request, Viewer Response, Origin Request, Origin Response |
| **Pricing** | 1/6th the cost of Lambda@Edge | More expensive |
| **Use case** | Cache key normalization, header manipulation, URL rewrites, simple A/B testing | Authentication/authorization, dynamic content, origin selection, image transformation |

**Exam tip:** For lightweight, high-scale request/response manipulation = **CloudFront Functions**. For complex logic requiring network access or origin-side processing = **Lambda@Edge**.

---

## Lambda Limits

### Per-Function Limits

| Limit | Value |
|---|---|
| Memory allocation | 128 MB to 10,240 MB (10 GB), in 1 MB increments |
| Maximum execution time (timeout) | 900 seconds (15 minutes) |
| Environment variables | 4 KB total |
| Deployment package (zipped) | 50 MB (direct upload) |
| Deployment package (unzipped, including layers) | 250 MB |
| Container image size | 10 GB |
| Temporary disk space (`/tmp`) | 512 MB to 10,240 MB (10 GB) |
| Concurrent executions (account default) | 1,000 per region |
| Function burst concurrency | 500 - 3,000 (region-dependent) |

### Per-Invocation Limits

| Limit | Value |
|---|---|
| Synchronous payload (request + response) | 6 MB |
| Asynchronous payload (event) | 256 KB |
| Layers | 5 per function |

**Exam tip:** If a question mentions a task that takes longer than 15 minutes, Lambda is NOT the answer. Use ECS Fargate, Step Functions, or EC2 instead.

---

## Lambda Networking

### Default (No VPC)

- Lambda runs in an AWS-managed VPC.
- Has internet access.
- Cannot access private resources in your VPC (e.g., RDS in a private subnet).

### VPC-Connected Lambda

- You can configure Lambda to connect to your VPC by specifying subnets and security groups.
- Lambda creates **Hyperplane ENIs** in your subnets.
- Can now access private resources (RDS, ElastiCache, etc.).
- **Loses internet access** unless the subnet has a NAT Gateway (Lambda in private subnet -> NAT Gateway in public subnet -> Internet Gateway).
- Use **VPC endpoints** to access AWS services (S3, DynamoDB, SQS) without internet.

**Exam tip:** "Lambda needs to access RDS in a private subnet" = attach Lambda to the VPC. "Lambda in VPC needs to call an external API" = need a NAT Gateway.

---

## Lambda Destinations

An alternative to DLQs. Configure where successful and failed asynchronous invocations are routed.

**Supported destinations (success or failure):**
- SQS queue
- SNS topic
- Lambda function
- EventBridge event bus

Advantages over DLQ:
- Supports both **success** and **failure** destinations (DLQ only handles failures).
- Includes the full invocation record (request payload, response, metadata).

---

## Key Takeaways for the Exam

1. **Max timeout: 15 minutes**. If a task takes longer, use ECS, EC2, or Step Functions.
2. **Max memory: 10 GB**. CPU scales with memory.
3. **Cold starts**: Mitigate with Provisioned Concurrency (costs money) or keep functions warm.
4. **Synchronous invocations** (API Gateway): caller handles retries. **Asynchronous** (S3, SNS): Lambda retries twice.
5. **SQS as event source**: Lambda polls. DLQ goes on the SQS queue, not Lambda.
6. **Kinesis/DynamoDB Streams**: Failure blocks the shard. Use bisect-on-error or max retry config.
7. **Layers**: Share dependencies. Max 5 layers, 250 MB total unzipped.
8. **Aliases + traffic shifting**: For canary/blue-green deployments.
9. **Lambda in VPC**: Loses internet; needs NAT Gateway or VPC endpoints.
10. **CloudFront Functions**: Lightweight, <1ms, viewer events only. **Lambda@Edge**: Complex, up to 30s, all four CloudFront events.
11. **Destinations > DLQ**: Supports success + failure, richer event data.
12. **Free tier**: 1M requests + 400,000 GB-seconds per month (perpetual).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What is AWS Lambda
- Execution Model
- Concurrency
- Event Sources and Triggers

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
