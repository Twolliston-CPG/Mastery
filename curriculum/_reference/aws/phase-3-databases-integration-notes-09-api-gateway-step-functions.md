# API Gateway, Step Functions, AppSync, and Amazon MQ

## Part 1: Amazon API Gateway

### What is API Gateway?

Amazon API Gateway is a fully managed service for creating, publishing, securing, and monitoring APIs at any scale. It serves as the front door for applications to access backend services such as Lambda, EC2, or any HTTP endpoint.

---

### API Types -- Comparison Table

| Feature | REST API | HTTP API | WebSocket API |
|---|---|---|---|
| **Protocol** | HTTPS (RESTful) | HTTPS (RESTful) | WebSocket (bidirectional) |
| **Cost** | ~$3.50 per million requests | ~$1.00 per million requests | $1.00 per million messages + $0.25 per million connection minutes |
| **Latency** | Higher (more features) | Lower (optimized for Lambda/HTTP) | Persistent connection |
| **Authorization** | IAM, Cognito, Lambda authorizer | IAM, Cognito, Lambda authorizer, JWT | IAM, Lambda authorizer |
| **API keys / Usage plans** | Yes | No | No |
| **Caching** | Yes | No | No |
| **Request validation** | Yes | No | No |
| **WAF integration** | Yes | No | Yes |
| **Throttling** | Yes (10,000 RPS default, 5,000 burst) | Yes | Yes |
| **Custom domain** | Yes | Yes | Yes |
| **Resource policies** | Yes | No | Yes |
| **Private APIs** | Yes (VPC endpoint) | No | No |
| **Edge-optimized** | Yes | No (Regional only) | No (Regional only) |
| **Use case** | Full-featured REST APIs | Simple, low-cost Lambda proxies | Chat, real-time notifications, dashboards |

### Decision Framework

**Choose REST API when:**
- You need caching, request validation, API keys, usage plans, or WAF.
- You need resource policies or private APIs.
- You need edge-optimized deployment.

**Choose HTTP API when:**
- You want the lowest cost for simple Lambda or HTTP backend proxies.
- You do not need caching, API keys, or request validation.
- You want lower latency.

**Choose WebSocket API when:**
- You need real-time bidirectional communication (chat, live scores, IoT dashboards).

> **Exam tip:** Most exam questions assume REST API. If the question emphasizes "lowest cost" and the API is simple -> HTTP API. If "real-time two-way communication" -> WebSocket API.

---

### Stages and Deployments

- An API is deployed to a **stage** (e.g., `dev`, `staging`, `prod`).
- Each stage has its own URL: `https://{api-id}.execute-api.{region}.amazonaws.com/{stage}`.
- **Stage variables** allow you to pass configuration to your backend (e.g., Lambda alias or HTTP endpoint URL per stage).
- **Canary deployments:** Route a percentage of traffic to a new deployment for testing before promoting.

---

### Throttling

| Level | Default Limit |
|---|---|
| **Account-level** | 10,000 requests per second across all APIs |
| **Stage-level** | Configurable per stage |
| **Method-level** | Configurable per method |
| **Burst limit** | 5,000 concurrent requests |

When throttled, API Gateway returns **429 Too Many Requests**.

---

### Caching (REST API Only)

- Cache responses to reduce backend calls.
- Cache capacity: 0.5 GB to 237 GB.
- Default TTL: 300 seconds (5 minutes). Range: 0 to 3600 seconds.
- Cache is defined per stage.
- Clients can invalidate cache with `Cache-Control: max-age=0` header (requires IAM authorization).

---

### Authorizers

| Authorizer Type | How It Works | Use Case |
|---|---|---|
| **IAM** | Caller signs request with SigV4. API Gateway validates with IAM. | Internal AWS services, cross-account access |
| **Cognito User Pools** | Client authenticates with Cognito, gets a token. API Gateway validates the token. | Web/mobile apps with user sign-up/sign-in |
| **Lambda Authorizer** | API Gateway calls a Lambda function with the request token/parameters. Lambda returns an IAM policy. | Custom auth logic (third-party tokens, legacy systems) |

> **Exam tip:** "Users sign up and sign in to a web app, then call an API" -> Cognito User Pool authorizer. "Custom authentication with a third-party identity provider" -> Lambda authorizer. "AWS service calling another AWS service" -> IAM authorizer.

---

### Integration Types

| Type | Description |
|---|---|
| **Lambda Proxy** | Most common. API Gateway passes the entire request to Lambda. Lambda returns status code, headers, body. |
| **Lambda (Custom)** | API Gateway uses mapping templates to transform request/response. More control, more complexity. |
| **HTTP Proxy** | Pass request directly to an HTTP endpoint. |
| **HTTP (Custom)** | Transform request/response with mapping templates before forwarding to HTTP endpoint. |
| **AWS Service** | Directly invoke an AWS service API (e.g., SQS SendMessage, Step Functions StartExecution). No Lambda needed. |
| **Mock** | Return a hardcoded response without calling a backend. Good for testing. |

> **Exam tip:** "API Gateway directly to SQS without Lambda" -> AWS Service integration. This is a cost-optimization and simplification pattern.

---

## Part 2: AWS Step Functions

### What is Step Functions?

AWS Step Functions is a serverless workflow orchestration service. You define workflows as **state machines** using Amazon States Language (JSON). Each state performs a task, makes a decision, or waits.

### Key Concepts

| Concept | Description |
|---|---|
| **State machine** | The workflow definition |
| **State** | A step in the workflow (Task, Choice, Wait, Parallel, Map, Pass, Succeed, Fail) |
| **Task state** | Invokes a service (Lambda, ECS, Batch, DynamoDB, SNS, SQS, Glue, SageMaker, etc.) |
| **Choice state** | Branching logic (if/else) |
| **Parallel state** | Execute multiple branches in parallel |
| **Map state** | Iterate over a collection (like a for-each loop) |
| **Wait state** | Delay for a specified time |
| **Execution** | A running instance of the state machine |

### Standard vs Express Workflows -- Comparison Table

| Feature | Standard | Express |
|---|---|---|
| **Duration** | Up to 1 year | Up to 5 minutes |
| **Execution model** | Exactly-once | At-least-once (async) or at-most-once (sync) |
| **Execution history** | Stored in Step Functions (viewable in console for 90 days) | Stored in CloudWatch Logs (you must configure) |
| **Pricing** | Per state transition (~$0.025 per 1,000 transitions) | Per request + duration (~$1.00 per million requests) |
| **Max executions** | 2,000/sec start rate (soft limit) | 100,000/sec start rate |
| **Use case** | Long-running workflows, human approval, audit trail | High-volume, short-duration (IoT data processing, streaming transforms) |

### When to Use Step Functions

- Orchestrate multiple Lambda functions in sequence or parallel.
- Implement retry logic, error handling, and compensation (saga pattern).
- Human approval workflows (wait for callback).
- ETL pipelines with multiple stages.
- Machine learning model training and deployment pipelines.

> **Exam tip:** "Orchestrate multiple Lambda functions" or "workflow with branching, retries, and error handling" -> Step Functions. "Long-running workflow with human approval" -> Step Functions Standard. "High-volume, short processing" -> Step Functions Express.

---

## Part 3: AWS AppSync

### What is AppSync?

AWS AppSync is a fully managed service for building GraphQL APIs. It connects to data sources like DynamoDB, Lambda, Aurora, OpenSearch, and HTTP endpoints.

### Key Facts

| Feature | Detail |
|---|---|
| **API type** | GraphQL (query, mutation, subscription) |
| **Real-time** | Supports WebSocket-based subscriptions for real-time updates |
| **Offline** | Built-in offline data synchronization for mobile/web clients |
| **Data sources** | DynamoDB, Aurora, Lambda, OpenSearch, HTTP APIs |
| **Caching** | Server-side caching |
| **Auth** | API key, Cognito, IAM, OIDC |

### When to Use AppSync

- You want a GraphQL API instead of REST.
- You need real-time data synchronization (e.g., collaborative editing, live dashboards).
- Your mobile app needs offline access with automatic sync when reconnected.
- You want to combine data from multiple sources in a single API call.

> **Exam tip:** "GraphQL" in the question -> AppSync. "Real-time data sync for a mobile app" -> AppSync.

---

## Part 4: Amazon MQ

### What is Amazon MQ?

Amazon MQ is a managed message broker service for Apache ActiveMQ and RabbitMQ. It is designed for migrating existing on-premises applications that use standard messaging protocols (AMQP, MQTT, STOMP, OpenWire, WSS) to AWS with minimal code changes.

### Key Facts

| Feature | Detail |
|---|---|
| **Engines** | Apache ActiveMQ, RabbitMQ |
| **Protocols** | AMQP, MQTT, STOMP, OpenWire, WSS |
| **Multi-AZ** | Active/standby deployment for HA |
| **Storage** | EBS (durable) or EFS (shared for ActiveMQ) |
| **Scaling** | Does NOT scale like SQS/SNS. Fixed broker instance size. |

### Amazon MQ vs SQS/SNS

| Feature | Amazon MQ | SQS/SNS |
|---|---|---|
| **Use case** | Migrate existing apps using standard protocols | New cloud-native applications |
| **Protocols** | AMQP, MQTT, STOMP, OpenWire, WSS | AWS proprietary API |
| **Scaling** | Limited (broker instance size) | Virtually unlimited |
| **Management** | More operational overhead | Fully serverless |
| **Cost** | Higher (running broker instances) | Lower (pay per message) |

> **Exam tip:** "Migrate on-premises application that uses ActiveMQ/RabbitMQ to AWS with minimal changes" -> Amazon MQ. "Build a new serverless messaging system" -> SQS/SNS.

---

## Key Exam Scenarios

| Scenario | Answer |
|---|---|
| "Build a REST API for Lambda functions" | API Gateway (REST or HTTP API) |
| "Lowest cost API for simple Lambda proxy" | HTTP API |
| "Real-time bidirectional communication" | WebSocket API |
| "API caching to reduce Lambda invocations" | REST API with caching enabled |
| "Users authenticate via Cognito then call API" | Cognito User Pool authorizer |
| "API Gateway directly to SQS, no Lambda" | AWS Service integration |
| "Orchestrate multiple Lambda functions with retries" | Step Functions |
| "Long-running workflow with human approval" | Step Functions Standard |
| "High-volume, short event processing workflow" | Step Functions Express |
| "GraphQL API" | AppSync |
| "Real-time data sync for mobile app" | AppSync |
| "Migrate ActiveMQ application to AWS" | Amazon MQ |
| "Rate limit API callers" | API Gateway throttling + usage plans + API keys |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Amazon API Gateway
- AWS Step Functions
- AWS AppSync
- Amazon MQ

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
