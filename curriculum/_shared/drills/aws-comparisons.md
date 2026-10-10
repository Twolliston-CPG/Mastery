# AWS Comparison Drill

> Weeks 5–26. **These pairs are ~40% of the SAA exam and are asked verbatim in interviews.**
> Cover the right column. Say the distinction out loud in one sentence.

## Networking

| Pair | The distinction |
|---|---|
| **Security Group vs NACL** | SG: stateful, allow-only, instance level, all rules evaluated. NACL: **stateless**, allow+deny, subnet level, **numbered order, first match wins**, must allow ephemeral ports for return traffic. |
| **IGW vs NAT Gateway** | IGW: bidirectional, public subnets, gives public IPs internet reachability. NAT: **outbound only**, lives in a public subnet, serves private subnets. |
| **NAT Gateway vs NAT Instance** | NAT GW: managed, HA per AZ, scales automatically, costs more. NAT instance: an EC2 you manage, cheaper, single point of failure, can be a bastion too. |
| **VPC Peering vs Transit Gateway** | Peering: 1:1, no transitive routing, free-ish, CIDRs must not overlap. TGW: hub-and-spoke, transitive, scales to hundreds of VPCs, hourly + data cost. |
| **Gateway Endpoint vs Interface Endpoint** | Gateway: **S3 and DynamoDB only**, free, route-table entry. Interface: most other services, an ENI in your subnet, hourly + data charge. |
| **ALB vs NLB vs GWLB** | ALB: L7, HTTP/HTTPS, path/host routing, WAF. NLB: L4, TCP/UDP, static IP, extreme throughput, preserves source IP. GWLB: for inline third-party appliances. |
| **Route 53 routing policies** | Simple · Weighted (split %) · Latency (lowest RTT) · Failover (active/passive) · Geolocation (user location) · Geoproximity (bias) · Multivalue (client-side LB with health checks). |

## Compute

| Pair | The distinction |
|---|---|
| **On-Demand vs Reserved vs Savings Plan vs Spot** | On-Demand: full price, no commitment. RI: 1/3yr commit to instance attributes. **Savings Plan: 1/3yr commit to $/hour spend — more flexible than RI.** Spot: up to 90% off, 2-minute interruption notice. |
| **ECS vs EKS vs Fargate** | ECS: AWS-native orchestrator, simpler. EKS: managed Kubernetes, portable, more complex. **Fargate is a compute mode for either** — serverless containers, no nodes to patch. |
| **Lambda vs Fargate** | Lambda: event-driven, ≤15 min, per-ms billing, cold starts. Fargate: long-running containers, no duration cap. |
| **ASG scaling policies** | Target tracking (pick a metric target — use this by default) · Step (tiered response to alarm breach) · Simple (legacy) · Scheduled (known patterns). |

## Storage

| Pair | The distinction |
|---|---|
| **S3 vs EBS vs EFS** | S3: object, HTTP API, 11 nines durability, unlimited. EBS: block, **one AZ**, attaches to one instance (RWO). EFS: NFS, multi-AZ, many instances at once (RWX). |
| **S3 storage classes** | Standard → Intelligent-Tiering (auto, unknown patterns) → Standard-IA (infrequent, ms) → One Zone-IA (cheaper, one AZ) → Glacier Instant (ms) → Glacier Flexible (min–hrs) → Deep Archive (12h, cheapest). |
| **EBS volume types** | gp3 (default; IOPS decoupled from size) · gp2 (legacy; IOPS scale with size) · io1/io2 (provisioned IOPS, databases) · st1 (throughput HDD, big sequential) · sc1 (cold HDD). |
| **Instance store vs EBS** | Instance store: physically attached, fastest, **ephemeral — lost on stop/terminate**. EBS: network-attached, persistent, snapshot-able. |

## Databases

| Pair | The distinction |
|---|---|
| **Multi-AZ vs Read Replica** | **Multi-AZ = availability.** Synchronous standby, automatic failover, **not readable** (in the classic single-standby setup). **Read Replica = scale reads.** Asynchronous, readable, manual promotion, can cross regions. *This is the single most-asked RDS question.* |
| **RDS vs Aurora** | Aurora: AWS-built storage layer, 6 copies across 3 AZs, up to 15 replicas, faster failover, auto-scaling storage, more expensive. |
| **RDS vs DynamoDB** | Relational, joins, complex queries, vertical scaling vs key-value, single-digit ms at any scale, **access patterns must be known up front**, horizontal. |
| **DynamoDB GSI vs LSI** | GSI: different partition key, created anytime, own capacity, eventually consistent. LSI: **same partition key**, different sort key, **must be created with the table**, shares capacity, can be strongly consistent. |
| **DynamoDB on-demand vs provisioned** | On-demand: pay per request, unpredictable traffic, no capacity planning. Provisioned: cheaper at steady state, needs auto-scaling configured. |

## Integration

| Pair | The distinction |
|---|---|
| **SQS vs SNS vs EventBridge** | SQS: queue, **one consumer group pulls**, decouple + buffer. SNS: pub/sub **fan-out push** to many subscribers. EventBridge: pub/sub with **content-based routing rules**, schemas, SaaS partners, scheduling. |
| **SQS Standard vs FIFO** | Standard: nearly unlimited throughput, **at-least-once**, best-effort ordering. FIFO: strict order, exactly-once processing, limited throughput, needs MessageGroupId. |
| **Step Functions vs SQS+Lambda** | Step Functions: visual state machine, built-in retries/error handling/branching, long-running orchestration. SQS+Lambda: simpler, cheaper, you own the orchestration logic. |

## Security

| Pair | The distinction |
|---|---|
| **IAM User vs Role** | User: long-lived credentials, a person or legacy app. **Role: temporary credentials via STS, assumed** — always prefer this. No keys to leak or rotate. |
| **Resource policy vs Identity policy** | Identity: attached to the principal ("what can Alice do?"). Resource: attached to the resource ("who can touch this bucket?"). Cross-account access generally needs **both**. |
| **Secrets Manager vs Parameter Store** | Secrets Manager: **automatic rotation**, cross-region replication, costs per secret. Parameter Store: free standard tier, config + secrets, no built-in rotation. |
| **KMS CMK vs AWS-managed key** | Customer-managed: your key policy, your rotation schedule, cross-account sharing, costs $1/mo. AWS-managed: free, no policy control, no cross-account. |
| **GuardDuty vs Inspector vs Security Hub vs Config vs Macie** | GuardDuty: threat detection from logs. Inspector: vulnerability scanning of workloads. Security Hub: **aggregates findings** + compliance standards. Config: resource configuration history + compliance rules. Macie: finds sensitive data in S3. |

## Resilience

| Pair | The distinction |
|---|---|
| **The four DR strategies** | Backup & Restore (RTO hours, cheapest) → Pilot Light (core only, RTO ~10s of min) → Warm Standby (scaled-down live copy, RTO minutes) → Multi-Site Active/Active (RTO ~0, most expensive). |
| **RTO vs RPO** | **RTO = how long to get back up** (time to recover). **RPO = how much data you can lose** (time between backups). Both drive the DR strategy choice and cost. |
| **AZ vs Region vs Edge** | AZ: isolated datacenter(s), single-digit-ms apart. Region: geographically separate, independent. Edge: CloudFront PoPs for caching and global entry. |

## The five-second exam heuristic

Read the **last sentence of the question first**, and let the qualifier pick the answer:

| Qualifier | Bias toward |
|---|---|
| "most cost-effective" | Spot, S3 lifecycle, Savings Plans, serverless, gateway endpoints |
| "least operational overhead" | Managed services — Fargate, Aurora, Lambda, RDS over EC2 |
| "highest availability" | Multi-AZ, multiple regions, ASG across AZs |
| "most secure" | IAM roles over keys, KMS, private subnets, VPC endpoints, least privilege |
| "real-time / sub-second" | Kinesis, DynamoDB, ElastiCache, NLB |
| "decouple" | SQS |
| "fan-out" | SNS |
| "existing on-prem / hybrid" | Direct Connect, Site-to-Site VPN, Storage Gateway, Outposts |

The same scenario with a different qualifier has a different correct answer. This is the whole trick
of the exam.
