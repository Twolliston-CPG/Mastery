# Amazon SQS (Simple Queue Service)

## What is SQS?

Amazon SQS is a fully managed message queuing service that decouples application components. A producer sends messages to a queue, and a consumer polls the queue to receive and process them. SQS is one of the oldest AWS services and is heavily tested on the SAA-C03 exam.

> **Exam tip:** Whenever a question says "decouple," "buffer," or "handle traffic spikes between components," think SQS.

---

## Standard vs FIFO Queues -- Comparison Table

| Feature | Standard Queue | FIFO Queue |
|---|---|---|
| **Throughput** | Virtually unlimited | 300 msg/sec (without batching), 3000 msg/sec (with batching). High throughput mode: up to 70,000 msg/sec. |
| **Ordering** | Best-effort ordering (no guarantee) | Strict first-in-first-out ordering |
| **Delivery** | At-least-once (possible duplicates) | Exactly-once processing (deduplication) |
| **Deduplication** | Not built-in (application must handle) | Built-in (content-based or deduplication ID) |
| **Message Group ID** | Not applicable | Required -- messages with the same group ID are ordered |
| **Queue name** | Any valid name | Must end with `.fifo` suffix |
| **Use cases** | High throughput, order not critical | Financial transactions, order processing, inventory |
| **Cost** | ~$0.40 per million requests | ~$0.50 per million requests |

### When to Choose Which

- **Standard:** Default choice. Use when throughput matters more than ordering or exactly-once delivery.
- **FIFO:** Use when message ordering is critical AND you need exactly-once processing. Accept the throughput trade-off.

> **Exam tip:** "Messages processed in order" or "no duplicate processing" -> FIFO. "Maximum throughput" or "order does not matter" -> Standard.

---

## Visibility Timeout

When a consumer receives a message, SQS does NOT delete it immediately. Instead, it hides the message for a period called the **visibility timeout**.

### How It Works
1. Consumer polls the queue and receives a message.
2. The message becomes **invisible** to other consumers for the duration of the visibility timeout.
3. If the consumer processes the message and sends a `DeleteMessage` call, the message is removed.
4. If the consumer fails or does not delete the message before the timeout expires, the message becomes **visible again** and another consumer can process it.

### Key Details

| Setting | Value |
|---|---|
| **Default** | 30 seconds |
| **Range** | 0 seconds to 12 hours |
| **Can be changed per message** | Yes (`ChangeMessageVisibility` API) |
| **Can be changed per queue** | Yes (queue attribute) |

> **Exam tip:** "Messages are being processed twice" -> Visibility timeout is too short. Increase it. "Consumer needs more time to process" -> Call `ChangeMessageVisibility` to extend the timeout.

---

## Dead-Letter Queues (DLQ)

A DLQ is a separate SQS queue where messages are sent after they fail processing a configured number of times.

### How It Works
1. Set a **redrive policy** on the source queue.
2. The redrive policy specifies: the DLQ ARN and the **maxReceiveCount** (how many times a message can be received before being sent to the DLQ).
3. After a message is received `maxReceiveCount` times without being deleted, SQS moves it to the DLQ.

### Key Details
- A DLQ for a Standard queue must also be Standard.
- A DLQ for a FIFO queue must also be FIFO.
- Set the DLQ retention period to the maximum (14 days) so you have time to investigate failures.
- **Redrive to source:** You can move messages from the DLQ back to the source queue after fixing the issue.

> **Exam tip:** "Handle failed messages" or "messages that cannot be processed" -> Dead-Letter Queue.

---

## Delay Queues

Delay queues postpone delivery of new messages for a specified period.

| Setting | Value |
|---|---|
| **Default delay** | 0 seconds (no delay) |
| **Maximum delay** | 15 minutes |
| **Can override per message?** | Yes (using message timers, Standard queue only) |

Use case: "Wait 5 minutes before processing an order to allow cancellation."

---

## Long Polling vs Short Polling

| Feature | Short Polling | Long Polling |
|---|---|---|
| **Behavior** | Returns immediately, even if queue is empty | Waits up to `WaitTimeSeconds` for a message to arrive |
| **Empty responses** | Yes (wastes API calls and money) | Reduced (only returns when a message arrives or timeout expires) |
| **API cost** | Higher (many empty responses) | Lower (fewer API calls) |
| **Latency** | Potentially higher (may miss messages on other servers) | Lower (queries all servers) |
| **How to enable** | Default behavior | Set `WaitTimeSeconds` to 1-20 seconds (queue or API level) |

> **Exam tip:** "Reduce SQS costs" or "reduce empty responses" -> Enable long polling (set `WaitTimeSeconds` > 0). Long polling is almost always preferred.

---

## Message Retention

| Setting | Value |
|---|---|
| **Default** | 4 days |
| **Minimum** | 1 minute |
| **Maximum** | 14 days |

Messages not consumed within the retention period are automatically deleted.

---

## Message Size

- Maximum message size: **256 KB**.
- For larger payloads: Use the **SQS Extended Client Library** to store the payload in S3 and send a pointer in the SQS message.

---

## SQS + Auto Scaling Group (ASG) Pattern

This is a classic exam architecture for decoupling and scaling.

### Architecture Description

```
                                    CloudWatch Alarm
                                  (ApproximateNumberOfMessagesVisible)
                                         |
                                         v
  Producers --> [ SQS Queue ] --> [ EC2 Auto Scaling Group ]
                                     (Consumers)
                                         |
                                    Scale out/in
```

### How It Works
1. **Producers** send messages to an SQS queue.
2. An **Auto Scaling Group** of EC2 instances (or ECS tasks) polls the queue and processes messages.
3. A **CloudWatch Alarm** monitors the SQS metric `ApproximateNumberOfMessagesVisible` (queue depth).
4. When the queue depth exceeds a threshold, the alarm triggers a **scale-out** action (add more consumers).
5. When the queue depth drops, the alarm triggers a **scale-in** action (remove consumers).

### Why This Pattern Matters
- **Decoupling:** Producers and consumers are independent. Producers do not need to know how many consumers exist.
- **Buffering:** The queue absorbs traffic spikes. Consumers process at their own pace.
- **Cost optimization:** Scale consumers based on actual demand.

> **Exam tip:** "Decouple producers from consumers" + "scale based on queue depth" -> SQS + ASG with CloudWatch alarm on `ApproximateNumberOfMessagesVisible`.

---

## SQS Access Control

| Mechanism | Purpose |
|---|---|
| **IAM policies** | Control who can call SQS APIs (SendMessage, ReceiveMessage, etc.) |
| **SQS Access Policy (Resource-based)** | Allow cross-account access or allow other AWS services (e.g., S3, SNS) to send messages to the queue |

### Common Pattern: S3 Event -> SQS
- S3 bucket sends an event notification to an SQS queue.
- The SQS queue must have a resource-based policy allowing `s3.amazonaws.com` to send messages.

---

## SQS Encryption

| Type | Detail |
|---|---|
| **In-transit** | HTTPS endpoints (always available) |
| **At-rest** | SSE-SQS (AWS managed key) or SSE-KMS (customer managed key) |
| **Client-side** | You encrypt the message body before sending (you manage keys) |

---

## Key Exam Scenarios

| Scenario | Answer |
|---|---|
| "Decouple two application tiers" | SQS queue between them |
| "Handle traffic spikes without losing messages" | SQS (buffers messages) |
| "Process messages in order" | SQS FIFO |
| "Prevent duplicate processing" | SQS FIFO (exactly-once) |
| "Messages processed twice" | Increase visibility timeout |
| "Handle failed messages" | Dead-Letter Queue (DLQ) |
| "Reduce SQS API costs" | Enable long polling |
| "Scale consumers based on workload" | SQS + ASG + CloudWatch alarm on queue depth |
| "Message larger than 256 KB" | SQS Extended Client Library (store payload in S3) |
| "Allow S3 to send notifications to SQS" | SQS resource-based access policy |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What is SQS?
- Standard vs FIFO Queues -- Comparison Table
- Visibility Timeout
- Dead-Letter Queues (DLQ)

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
