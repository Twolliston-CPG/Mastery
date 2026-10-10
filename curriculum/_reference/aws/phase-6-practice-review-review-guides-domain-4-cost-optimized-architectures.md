# Domain 4: Design Cost-Optimized Architectures (20% of Exam)

This domain tests your ability to select cost-effective solutions. Expect approximately 12-13 questions. Cost optimization is a favorite distractor topic — many questions across ALL domains have a cost angle.

---

## 1. EC2 Purchase Options

### Pricing Models Comparison

| Option | Discount | Commitment | Interruption | Best For |
|---|---|---|---|---|
| On-Demand | 0% | None | No | Short-term, unpredictable workloads |
| Reserved Instances | Up to 72% | 1 or 3 year | No | Steady-state, predictable workloads |
| Savings Plans | Up to 72% | 1 or 3 year ($/hr) | No | Flexible commitment across services |
| Spot Instances | Up to 90% | None | Yes (2-min warning) | Fault-tolerant, flexible workloads |
| Dedicated Instances | Premium | None or RI | No | Compliance, licensing |
| Dedicated Hosts | Premium | None or RI | No | BYOL, compliance, server-bound licenses |

### Reserved Instances Deep Dive
- **Standard RI**: Locked to instance family, size, region, OS, tenancy. Highest discount.
- **Convertible RI**: Can change instance family, size, OS, tenancy. Lower discount (~54%).
- **Payment Options**: All Upfront (most savings) > Partial Upfront > No Upfront (least savings)
- **Term**: 1-year or 3-year (3-year saves more)

### Savings Plans Deep Dive
- **Compute Savings Plans**: Flexible across instance families, regions, OS, tenancy, and even Lambda/Fargate. Up to 66% savings.
- **EC2 Instance Savings Plans**: Locked to instance family + region. Up to 72% savings.
- Both use a $/hour commitment model

### When to Use What

| Workload | Best Option |
|---|---|
| Production, 24/7, predictable | Reserved Instances or EC2 Instance Savings Plans |
| Production, 24/7, may change instance types | Compute Savings Plans |
| Batch processing, fault-tolerant | Spot Instances |
| Short-term project (< 1 year) | On-Demand |
| Dev/test during business hours | On-Demand with scheduling (start/stop) |
| Mixed fleet with Spot + On-Demand | Auto Scaling mixed instance policy |
| License requires specific server | Dedicated Hosts |

### Key Exam Scenarios
- **"Minimize cost for 3-year steady workload"** → 3-year All Upfront RI
- **"Cost-effective, can be interrupted"** → Spot Instances
- **"Need flexibility across instance families"** → Compute Savings Plans
- **"BYOL (Bring Your Own License)"** → Dedicated Hosts
- **"Dev/test, only weekdays 9-5"** → On-Demand + scheduling (Instance Scheduler)

---

## 2. S3 Storage Classes and Lifecycle

### Storage Classes

| Class | Availability | Min Duration | Retrieval Fee | Use Case |
|---|---|---|---|---|
| Standard | 99.99% | None | None | Frequently accessed data |
| Intelligent-Tiering | 99.9% | None | None | Unknown/changing access patterns |
| Standard-IA | 99.9% | 30 days | Per GB | Infrequent but rapid access needed |
| One Zone-IA | 99.5% | 30 days | Per GB | Reproducible, infrequent data |
| Glacier Instant Retrieval | 99.9% | 90 days | Per GB | Archive, millisecond access |
| Glacier Flexible Retrieval | 99.99% | 90 days | Per GB | Archive, minutes to hours |
| Glacier Deep Archive | 99.99% | 180 days | Per GB | Long-term archive, 12 hours |

### Glacier Retrieval Times

| Option | Glacier Flexible | Glacier Deep Archive |
|---|---|---|
| Expedited | 1-5 minutes | Not available |
| Standard | 3-5 hours | 12 hours |
| Bulk | 5-12 hours | 48 hours |

### Lifecycle Policies
- Transition actions: Move objects between storage classes based on age
- Expiration actions: Delete objects after a specified number of days
- Minimum transition periods: Standard → Standard-IA (30 days); Standard-IA → Glacier (30 days after IA)

### S3 Intelligent-Tiering
- Monitors access patterns and moves objects automatically
- Tiers: Frequent → Infrequent (30 days no access) → Archive Instant (90 days) → Archive (optional, 90-730 days) → Deep Archive (optional, 180-730 days)
- No retrieval fees
- Small monthly monitoring fee per object

### Key Exam Scenarios
- **"Unknown access patterns"** → S3 Intelligent-Tiering
- **"Archive for 7 years, rarely accessed"** → Glacier Deep Archive
- **"Infrequent access, cannot reproduce"** → Standard-IA (multi-AZ)
- **"Infrequent access, can reproduce"** → One Zone-IA (cheapest)
- **"Compliance archive, 12-hour retrieval OK"** → Glacier Deep Archive
- **"Access archived data in minutes"** → Glacier Instant Retrieval

---

## 3. Right-Sizing and Optimization Tools

### AWS Compute Optimizer
- Analyzes CloudWatch metrics (CPU, memory, network, disk)
- Recommends optimal instance types, Auto Scaling groups, EBS volumes, Lambda memory
- Free (Enhanced Recommendations for 3-month lookback is paid)

### AWS Cost Explorer
- Visualize and analyze AWS spending
- Forecast future costs
- RI and Savings Plan purchase recommendations
- Filter by service, account, tag, region

### AWS Budgets
- Set custom cost and usage budgets
- Alert when actual or forecasted costs exceed thresholds
- Can trigger automated actions (e.g., apply SCP to stop spending)

### AWS Trusted Advisor
- Best practice checks: cost optimization, performance, security, fault tolerance, service limits
- Full checks require Business or Enterprise support plan
- Cost checks: idle RDS, underutilized EC2, unassociated EIPs, idle load balancers

### S3 Storage Class Analysis
- Analyzes object access patterns
- Recommends when to transition to Standard-IA or Glacier
- Takes 30 days of data to provide recommendations

---

## 4. Serverless Cost Model

### Lambda Pricing
- $0.20 per 1 million requests
- $0.0000166667 per GB-second
- Free tier: 1M requests + 400,000 GB-seconds per month
- **Key insight**: Lambda cost = (number of invocations) x (duration in seconds) x (memory in GB) x (price per GB-second)
- **Optimization**: Increasing memory can reduce duration, potentially reducing total cost

### API Gateway Pricing
- REST API: $3.50 per million requests (first 333M)
- HTTP API: $1.00 per million requests (cheaper, fewer features)
- WebSocket: $1.00 per million messages

### DynamoDB Pricing
- **On-Demand**: $1.25 per million WCU, $0.25 per million RCU
- **Provisioned**: ~$0.00065 per WCU/hour, ~$0.00013 per RCU/hour
- **Reserved Capacity**: Up to 77% savings on provisioned (1 or 3 year)
- Storage: $0.25 per GB/month

### When Serverless Saves Money
- Low, variable, or unpredictable traffic (pay-per-use)
- Sporadic workloads (zero cost when idle)
- New applications with uncertain demand
- Short-duration processing

### When Serverless Costs MORE
- High-volume, sustained workloads (Lambda at millions of long invocations)
- Consistent high traffic (provisioned EC2 + RDS can be cheaper)

---

## 5. Data Transfer Costs

### Free Data Transfer
- Inbound data (into AWS from internet): FREE
- EC2 to S3 in the same region: FREE
- EC2 to EC2 in the same AZ using private IP: FREE
- CloudFront to origin: FREE
- VPC Gateway Endpoints (S3, DynamoDB): FREE

### Costs to Watch

| Transfer | Cost |
|---|---|
| EC2 to internet (egress) | $0.09/GB (first 10 TB/month) |
| EC2 across AZs (same region) | $0.01/GB each direction |
| EC2 across regions | $0.02/GB |
| NAT Gateway data processing | $0.045/GB |
| CloudFront to internet | $0.085/GB (cheaper than direct EC2 egress) |
| S3 to internet | $0.09/GB |
| Direct Connect data transfer out | $0.02/GB |

### Key Cost Optimization Strategies
1. **Use VPC Gateway Endpoints** for S3 and DynamoDB (eliminates NAT Gateway costs for those services)
2. **Use CloudFront** for content delivery (lower egress rates than direct EC2/S3)
3. **Keep traffic in the same AZ** when possible (use AZ-aware architectures)
4. **Compress data** before transfer
5. **Use S3 same-region endpoints** (avoid cross-region transfer)

---

## 6. Database Cost Optimization

### RDS Cost Reduction
- **Right-size**: Use Compute Optimizer to find optimal instance
- **Reserved Instances**: Up to 69% savings for steady-state
- **Read Replicas**: Offload reads instead of scaling up
- **Aurora Serverless v2**: Pay per ACU for variable workloads
- **Stop unused**: RDS instances can be stopped for up to 7 days (storage still charged)

### DynamoDB Cost Reduction
- **On-Demand mode**: For unpredictable workloads (no over-provisioning)
- **Provisioned with Auto Scaling**: For predictable patterns
- **Reserved Capacity**: For steady, predictable workloads
- **DAX**: Reduce read costs by caching (fewer RCUs consumed)
- **TTL**: Automatically delete expired items (no WCU cost)

### ElastiCache Cost Reduction
- **Reserved Nodes**: Up to 55% savings
- **Right-size**: Match node type to workload
- **Data Tiering (Redis)**: Move less-used data to SSD automatically

---

## 7. Storage Cost Optimization

### EBS Optimization
- **gp3 over gp2**: Same performance at lower cost for many workloads
- **Delete unattached volumes**: Use AWS Config to detect
- **Snapshot lifecycle**: Use Amazon Data Lifecycle Manager to automate snapshot creation and deletion
- **Right-size volumes**: Reduce unused capacity

### S3 Optimization
- **Lifecycle policies**: Automate transition to cheaper classes
- **Intelligent-Tiering**: For unknown access patterns
- **S3 Inventory + Analytics**: Understand what you have and how it is accessed
- **Requester Pays**: Shift costs to data consumers
- **S3 Storage Lens**: Dashboard for storage utilization

### EFS Optimization
- **EFS Standard vs EFS IA**: Set lifecycle policy to move infrequent files to IA (up to 92% cheaper)
- **Throughput modes**: Bursting (included), Provisioned (pay for throughput), Elastic (auto-scales)
- **One Zone**: Cheaper than Standard (single-AZ)

---

## 8. Architecture-Level Cost Optimization

### Patterns That Save Money

1. **Serverless first**: API Gateway + Lambda + DynamoDB costs nearly zero at low traffic
2. **Spot for batch**: Any fault-tolerant batch job should use Spot
3. **Schedule dev/test**: Stop/terminate instances outside business hours (save 70%+)
4. **Cache aggressively**: CloudFront for web, ElastiCache for databases
5. **Right-size everything**: Use Compute Optimizer data
6. **Delete idle resources**: Unattached EBS, unused EIPs, idle RDS instances, empty S3 buckets
7. **Use managed services**: Less operational cost (fewer engineers to manage infrastructure)
8. **Consolidate accounts**: Use AWS Organizations for consolidated billing and volume discounts

### Cost Alarms Pattern
- Use AWS Budgets to set spending thresholds
- Alert via SNS when approaching budget
- Use AWS Cost Anomaly Detection for unexpected spikes

---

## Common Exam Traps for Domain 4

1. **"Spot is always cheapest"** → Spot is cheapest per hour but cannot be used for workloads that cannot be interrupted.
2. **"Reserved Instances require upfront payment"** → No Upfront RI exists (lower discount but no upfront payment).
3. **"Lambda is always cheaper than EC2"** → WRONG. For high-volume, long-duration workloads, EC2 can be significantly cheaper.
4. **"S3 Standard-IA has no retrieval fee"** → WRONG. Standard-IA charges per-GB retrieval fees.
5. **"Glacier Expedited retrieval for Deep Archive"** → WRONG. Deep Archive does not support Expedited retrieval.
6. **"NAT Gateway is free"** → WRONG. NAT Gateway charges per hour ($0.045) AND per GB processed ($0.045).
7. **"Data transfer into AWS costs money"** → WRONG. Inbound data transfer is free.
8. **"Savings Plans lock you to an instance type"** → Compute Savings Plans are flexible across families, regions, OS, and even Lambda/Fargate.
9. **"DynamoDB On-Demand is always cheaper"** → For consistent high-throughput, Provisioned with Reserved Capacity is cheaper.
10. **"Intelligent-Tiering has retrieval fees"** → WRONG. No retrieval fees, just a small monthly monitoring fee per object.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- EC2 Purchase Options
- S3 Storage Classes and Lifecycle
- Right-Sizing and Optimization Tools
- Serverless Cost Model

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
