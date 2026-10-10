# Domain 2: Design Resilient Architectures (26% of Exam)

This domain tests your ability to design architectures that survive failures gracefully. Expect approximately 17 questions on resilience, high availability, disaster recovery, and decoupling.

---

## 1. Multi-AZ Deployments

### The Golden Rule
**If the exam asks about "high availability" or "survive AZ failure" — the answer almost always involves Multi-AZ.**

### Service-Level Multi-AZ Support

| Service | Multi-AZ Behavior |
|---|---|
| EC2 + Auto Scaling | Deploy across 2+ AZs with min capacity to survive AZ loss |
| ALB | Automatically distributes across enabled AZs |
| RDS Multi-AZ | Synchronous standby in different AZ; automatic failover (1-2 min) |
| Aurora | Storage spans 3 AZs (6 copies of data); up to 15 replicas across AZs |
| ElastiCache Redis | Multi-AZ with automatic failover to replica |
| EFS | Automatically spans all AZs in a region |
| DynamoDB | Automatically spans 3 AZs |
| NAT Gateway | Deploy one per AZ for HA (each AZ has its own) |

### Capacity Planning for AZ Failure
If you need N instances to handle load and have M AZs:
- Each AZ should have at least N/(M-1) instances
- Example: Need 6 instances, 3 AZs → 9 total (3 per AZ). Lose 1 AZ → 6 remain.

---

## 2. Read Replicas vs Multi-AZ

| Feature | Multi-AZ | Read Replicas |
|---|---|---|
| Purpose | High availability | Read performance |
| Replication | Synchronous | Asynchronous |
| Failover | Automatic (DNS changes) | Manual promotion |
| Read traffic | Standby cannot serve reads | Can serve read traffic |
| Cross-region | No (same region only) | Yes |
| RDS MySQL limit | 1 standby | Up to 5 replicas |
| Aurora limit | Built into storage layer | Up to 15 replicas |

### Key Exam Scenarios
- **"Improve read performance"** → Read Replicas
- **"Survive AZ failure automatically"** → Multi-AZ
- **"DR in another region"** → Cross-Region Read Replica
- **"Both HA and read scaling"** → Multi-AZ + Read Replicas (they are independent features)

---

## 3. Auto Scaling

### Scaling Policies

| Policy Type | How It Works | Best For |
|---|---|---|
| Target Tracking | Maintains a metric at a target value (e.g., CPU at 60%) | Most common, simplest |
| Step Scaling | Scales in steps based on alarm thresholds | Variable responses to different levels |
| Scheduled Scaling | Scales at specific times | Predictable traffic patterns |
| Predictive Scaling | Uses ML on historical data to pre-provision | Recurring patterns with startup lag |

### Key Settings
- **Minimum capacity**: Floor — never goes below this
- **Maximum capacity**: Ceiling — never goes above this
- **Desired capacity**: Current target
- **Health check grace period**: Time to wait before checking health on new instances
- **Cooldown period**: Time to wait between scaling activities
- **Warm pools**: Pre-initialized stopped instances for faster scaling

### Key Exam Scenarios
- **"Predictable daily spike at 9 AM"** → Scheduled scaling to increase capacity before 9 AM
- **"Traffic spikes take 5 min to respond"** → Predictive scaling or warm pools
- **"Scale based on SQS queue depth"** → Target tracking on ApproximateNumberOfMessagesVisible
- **"New instances get terminated before ready"** → Increase health check grace period

---

## 4. Elastic Load Balancing

### ALB vs NLB vs Gateway LB

| Feature | ALB | NLB | Gateway LB |
|---|---|---|---|
| Layer | 7 (HTTP/HTTPS) | 4 (TCP/UDP/TLS) | 3 (IP) |
| Use Case | Web apps, microservices | Extreme performance, static IP | Third-party appliances |
| Routing | Path, host, header, query string | Port-based | IP-based |
| Protocols | HTTP, HTTPS, WebSocket | TCP, UDP, TLS | IP (GENEVE) |
| Static IP | No (use Global Accelerator) | Yes (one per AZ) | No |
| Cross-zone LB | Enabled by default | Disabled by default | N/A |
| SSL Termination | Yes | Yes (TLS listener) | No |
| Sticky Sessions | Yes | Yes | No |

### Key Exam Scenarios
- **"Path-based routing (/api vs /images)"** → ALB
- **"Static IP addresses required"** → NLB
- **"Millions of requests, ultra-low latency"** → NLB
- **"WebSocket support"** → ALB
- **"Third-party firewall appliance"** → Gateway LB
- **"gRPC support"** → ALB

---

## 5. Route 53

### Routing Policies

| Policy | Use Case |
|---|---|
| Simple | Single resource, no health checks |
| Weighted | A/B testing, gradual migration (e.g., 90/10 split) |
| Latency | Route to lowest-latency region |
| Failover | Active-passive DR (primary/secondary) |
| Geolocation | Route based on user's country/continent |
| Geoproximity | Route based on geographic distance with bias |
| Multi-value | Return multiple healthy IPs (like simple + health checks) |

### Key Exam Scenarios
- **"Route to closest region"** → Latency-based routing
- **"Active-passive DR"** → Failover routing with health checks
- **"Different content per country"** → Geolocation routing
- **"Blue-green deployment"** → Weighted routing (0/100 → 10/90 → 50/50 → 100/0)

---

## 6. S3 Resilience Features

### Durability & Availability
- **11 nines durability (99.999999999%)** — all storage classes except One Zone-IA
- **99.99% availability** — Standard
- **99.9% availability** — Standard-IA, Intelligent-Tiering
- **99.5% availability** — One Zone-IA (single AZ risk)

### Replication
- **Cross-Region Replication (CRR)**: DR, compliance, latency reduction
- **Same-Region Replication (SRR)**: Log aggregation, live replication between accounts
- Requires versioning on source and destination
- Existing objects are NOT replicated (only new objects after enabling)

### Versioning
- Protects against accidental deletion and overwrites
- Deleted objects get a delete marker (recoverable)
- MFA Delete adds additional protection

---

## 7. Disaster Recovery Strategies

Listed from cheapest/slowest to most expensive/fastest:

### 1. Backup and Restore
- **RTO**: Hours | **RPO**: Hours (depends on backup frequency)
- **Cost**: Lowest
- **How**: Store backups (AMIs, snapshots, S3 data) in another region. Restore when needed.
- **Use when**: Non-critical workloads, loose RTO/RPO requirements

### 2. Pilot Light
- **RTO**: 10s of minutes | **RPO**: Minutes
- **Cost**: Low
- **How**: Core infrastructure running (database with replication). Compute (EC2/ECS) is OFF — launch when needed.
- **Use when**: Critical databases with moderate RTO

### 3. Warm Standby
- **RTO**: Minutes | **RPO**: Seconds to minutes
- **Cost**: Medium
- **How**: Scaled-down but fully functional copy in another region. Scale up during failover.
- **Use when**: Business-critical applications

### 4. Multi-Site Active-Active
- **RTO**: Near zero | **RPO**: Near zero
- **Cost**: Highest
- **How**: Full production in multiple regions, traffic distributed across both.
- **Use when**: Zero-downtime requirements

### Key Exam Scenarios
- **"Cheapest DR for non-critical app"** → Backup and Restore
- **"RTO 4 hours, minimize cost"** → Pilot Light
- **"RTO 15 minutes, RPO 1 minute"** → Warm Standby
- **"Zero downtime, zero data loss"** → Multi-Site Active-Active

---

## 8. Decoupling with SQS, SNS, and EventBridge

### Amazon SQS
- **Standard**: At-least-once delivery, best-effort ordering, unlimited throughput
- **FIFO**: Exactly-once processing, strict ordering, 3,000 msg/sec with batching (high-throughput mode)
- **Dead-Letter Queue (DLQ)**: Captures messages that fail processing after max receive count
- **Visibility Timeout**: Time a message is hidden from other consumers after being read (default: 30 sec, max: 12 hours)
- **Long Polling**: Reduces empty receives, saves cost (set WaitTimeSeconds > 0)
- **Message Retention**: 1 minute to 14 days (default: 4 days)

### Amazon SNS
- Pub/sub messaging
- Push-based (delivers to subscribers)
- Subscribers: SQS, Lambda, HTTP, email, SMS, mobile push
- **Fan-out pattern**: SNS topic → multiple SQS queues (each gets every message)

### Amazon EventBridge
- Event bus for event-driven architectures
- Advanced content-based routing with event patterns
- Integrates with 90+ AWS services as sources
- Schema registry for event schema discovery
- Replaces CloudWatch Events (same underlying service)

### Key Exam Scenarios
- **"Process messages exactly once in order"** → SQS FIFO
- **"Multiple consumers each get every message"** → SNS fan-out to SQS queues
- **"Decouple web tier from processing tier"** → SQS between tiers
- **"Content-based event routing"** → EventBridge
- **"Failed messages need investigation"** → SQS Dead-Letter Queue

---

## 9. Aurora Specifics

### Aurora vs Standard RDS

| Feature | Standard RDS | Aurora |
|---|---|---|
| Read Replicas | Up to 5 | Up to 15 |
| Storage | Manual provisioning | Auto-scales up to 128 TB |
| Replication | Asynchronous | Shared storage (millisecond lag) |
| Failover | 1-2 minutes | ~30 seconds |
| Endpoints | Instance endpoint, read replica endpoint | Cluster (writer), reader, custom endpoints |
| Global | Cross-region read replicas | Global Database (<1 sec replication) |
| Serverless | No | Aurora Serverless v2 (scales ACUs) |
| Storage Durability | 2 copies (Multi-AZ) | 6 copies across 3 AZs |

### Aurora Global Database
- 1 primary region (read/write) + up to 5 secondary regions (read-only)
- Replication lag: typically <1 second
- Secondary can be promoted in ~1 minute (managed planned failover) or during unplanned (detach + promote)

---

## Common Exam Traps for Domain 2

1. **"Multi-AZ RDS provides read scaling"** → WRONG. The standby in Multi-AZ cannot serve reads. Use Read Replicas for read scaling.
2. **"SQS guarantees ordering"** → Only FIFO queues guarantee ordering. Standard queues use best-effort ordering.
3. **"S3 replication copies existing objects"** → WRONG. Only new objects are replicated after enabling replication.
4. **"Pilot Light has zero RTO"** → WRONG. Pilot Light has 10s of minutes RTO because compute must be launched.
5. **"Auto Scaling is instantaneous"** → WRONG. Instances take minutes to launch and initialize.
6. **"Read Replicas provide automatic failover"** → WRONG for RDS. Aurora Replicas can be failover targets. RDS read replicas must be manually promoted.
7. **"NAT Gateway is highly available"** → Only within a single AZ. Deploy one per AZ for cross-AZ HA.
8. **"DynamoDB needs Multi-AZ configuration"** → WRONG. DynamoDB is automatically distributed across 3 AZs.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Multi-AZ Deployments
- Read Replicas vs Multi-AZ
- Auto Scaling
- Elastic Load Balancing

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
