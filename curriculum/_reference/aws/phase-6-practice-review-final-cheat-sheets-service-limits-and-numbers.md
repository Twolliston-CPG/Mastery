# AWS Service Limits and Numbers to Remember

These are the specific numbers that appear in SAA-C03 exam questions. Memorize them.

---

## S3

| Attribute | Value |
|---|---|
| Max object size | 5 TB |
| Max single PUT | 5 GB |
| Multipart upload recommended above | 100 MB |
| Multipart upload required above | 5 GB |
| Max buckets per account (default) | 100 (can request increase to 1,000) |
| PUT/COPY/POST/DELETE per prefix | 3,500 requests/second |
| GET/HEAD per prefix | 5,500 requests/second |
| S3 Standard availability | 99.99% |
| S3 Standard-IA availability | 99.9% |
| S3 One Zone-IA availability | 99.5% |
| All classes durability | 99.999999999% (11 nines) |
| Standard-IA minimum storage duration | 30 days |
| Glacier Flexible minimum storage duration | 90 days |
| Glacier Deep Archive minimum duration | 180 days |
| Glacier Flexible Expedited retrieval | 1-5 minutes |
| Glacier Flexible Standard retrieval | 3-5 hours |
| Glacier Flexible Bulk retrieval | 5-12 hours |
| Glacier Deep Archive Standard retrieval | 12 hours |
| Glacier Deep Archive Bulk retrieval | 48 hours |
| S3 Versioning | Unlimited versions per object |
| S3 Object Lock retention | Up to 100 years |
| S3 Intelligent-Tiering - move to IA | 30 days no access |

---

## EC2 / EBS

| Attribute | Value |
|---|---|
| gp3 baseline IOPS | 3,000 |
| gp3 max IOPS | 16,000 |
| gp3 baseline throughput | 125 MB/s |
| gp3 max throughput | 1,000 MB/s |
| gp2 IOPS ratio | 3 IOPS per GB |
| gp2 max IOPS | 16,000 (at 5,334+ GB) |
| gp2 burst IOPS | Up to 3,000 (for volumes < 1 TB) |
| io2 max IOPS | 64,000 |
| io2 Block Express max IOPS | 256,000 |
| io2 Block Express max throughput | 4,000 MB/s |
| io2 Block Express max size | 64 TB |
| io2 IOPS/GB ratio | 500 IOPS per GB |
| st1 max throughput | 500 MB/s |
| sc1 max throughput | 250 MB/s |
| EBS max volume size (gp2/gp3) | 16 TB |
| EBS Multi-Attach max instances | 16 (io1/io2, same AZ only) |
| Max EBS volumes per instance | ~28 (varies by instance type) |
| Placement group (Spread) | Max 7 instances per AZ |
| Placement group (Partition) | Max 7 partitions per AZ |
| Security groups per ENI | 5 (default) |
| Rules per security group | 60 inbound + 60 outbound (default) |

---

## Lambda

| Attribute | Value |
|---|---|
| Max timeout | 15 minutes (900 seconds) |
| Max memory | 10,240 MB (10 GB) |
| Default memory | 128 MB |
| Ephemeral storage (/tmp) | 512 MB default, up to 10 GB |
| Deployment package (zipped) | 50 MB |
| Deployment package (unzipped) | 250 MB |
| Container image package | 10 GB |
| Environment variables | 4 KB total |
| Default concurrent executions | 1,000 per region |
| Burst concurrency | 500-3,000 (region-dependent) |
| Max layers | 5 layers per function |
| Layer size | 250 MB unzipped total (including all layers) |
| Invocation payload (sync) | 6 MB |
| Invocation payload (async) | 256 KB |

---

## SQS

| Attribute | Value |
|---|---|
| Max message size | 256 KB |
| Extended client library max | 2 GB (payload in S3) |
| Default retention | 4 days |
| Max retention | 14 days |
| Min retention | 1 minute |
| Default visibility timeout | 30 seconds |
| Max visibility timeout | 12 hours |
| Long polling max wait | 20 seconds |
| FIFO throughput | 300 msg/sec (without batching) |
| FIFO high-throughput | 3,000 msg/sec (per API action with batching) |
| Standard throughput | Virtually unlimited |
| Delay queue max | 15 minutes |
| Max in-flight messages (Standard) | 120,000 |
| Max in-flight messages (FIFO) | 20,000 |

---

## SNS

| Attribute | Value |
|---|---|
| Max message size | 256 KB |
| Max subscriptions per topic | 12,500,000 |
| Max topics per account | 100,000 |
| Filter policies per topic | Limited by subscription count |

---

## DynamoDB

| Attribute | Value |
|---|---|
| Max item size | 400 KB |
| Max partition key size | 2,048 bytes |
| Max sort key size | 1,024 bytes |
| Max GSIs per table | 20 |
| Max LSIs per table | 5 (created at table creation only) |
| Max tables per region | 2,500 (default) |
| On-demand max throughput | 40,000 RCU / 40,000 WCU (default) |
| Provisioned max throughput | 40,000 RCU / 40,000 WCU (default, can request increase) |
| Transaction max items | 100 items or 4 MB |
| PITR retention | 35 days |
| TTL | Automatic (no WCU cost) |
| Batch operations max | 25 items (BatchWriteItem) / 100 items (BatchGetItem) |
| Batch max payload | 16 MB |
| Global Tables max regions | No limit |
| DAX cluster max nodes | 11 |

---

## RDS / Aurora

| Attribute | Value |
|---|---|
| RDS max storage | 64 TB (most engines) |
| Aurora max storage | 128 TB (auto-scaling) |
| RDS read replicas (MySQL/PostgreSQL) | 5 |
| Aurora read replicas | 15 |
| RDS Multi-AZ failover time | 1-2 minutes |
| Aurora failover time | ~30 seconds |
| Automated backup retention | 1-35 days |
| Manual snapshot retention | Until deleted |
| Max RDS instances per account | 40 (default) |
| Aurora storage replication | 6 copies across 3 AZs |
| Aurora Global Database secondary regions | Up to 5 |
| Aurora Global Database replication lag | Typically < 1 second |
| RDS Proxy idle connection timeout | 1-28,800 seconds |

---

## VPC / Networking

| Attribute | Value |
|---|---|
| Max VPCs per region | 5 (default, can increase) |
| VPC CIDR range | /16 (65,536 IPs) to /28 (16 IPs) |
| Max CIDRs per VPC | 5 (can associate secondary CIDRs) |
| Subnets per VPC | 200 (default) |
| Internet Gateways per VPC | 1 |
| NAT Gateway per AZ | 1 recommended for HA |
| NAT Gateway bandwidth | Up to 100 Gbps |
| NAT Gateway cost | $0.045/hr + $0.045/GB processed |
| Route tables per VPC | 200 (default) |
| Routes per route table | 50 (default) |
| VPC peering per VPC | 50 (default, can increase to 125) |
| Security groups per VPC | 2,500 (default) |
| NACLs per VPC | 200 (default) |
| NACL rules per NACL | 20 inbound + 20 outbound (default) |
| Elastic IPs per region | 5 (default) |

---

## Kinesis

| Attribute | Value |
|---|---|
| Data Streams shard read | 2 MB/sec |
| Data Streams shard write | 1 MB/sec (1,000 records/sec) |
| Data Streams record max size | 1 MB |
| Data Streams default retention | 24 hours |
| Data Streams max retention | 365 days |
| Enhanced fan-out per consumer | 2 MB/sec per shard |
| Firehose buffer interval | 60-900 seconds |
| Firehose buffer size | 1-128 MB |
| Firehose max record size | 1 MB |

---

## CloudFront

| Attribute | Value |
|---|---|
| Edge locations | 400+ globally |
| Max file size (single object) | 30 GB (via single GET request) |
| Max TTL | 365 days |
| Default TTL | 24 hours |
| Origin failover | 2 origins per origin group |
| Custom SSL certificates | Unlimited |
| Cache behaviors per distribution | 25 (default) |

---

## EFS

| Attribute | Value |
|---|---|
| Max file system size | Petabytes (no practical limit) |
| Max throughput (General Purpose) | Up to 10+ GB/s |
| Max IOPS (General Purpose) | 35,000+ |
| Lifecycle policy IA transition | 1, 7, 14, 30, 60, or 90 days |
| Availability | Regional (Standard) or One Zone |

---

## API Gateway

| Attribute | Value |
|---|---|
| Max timeout | 29 seconds |
| Max payload size | 10 MB |
| Throttle (default) | 10,000 requests/sec (account level) |
| Burst limit | 5,000 requests |
| WebSocket message size | 128 KB |
| Cache capacity | 0.5 GB to 237 GB |

---

## Elastic Load Balancer

| Attribute | Value |
|---|---|
| ALB targets per target group | 1,000 |
| NLB targets per target group | 500 |
| ALB listeners | 50 per LB |
| NLB static IPs | 1 per AZ |
| Cross-zone LB (ALB) | Enabled by default |
| Cross-zone LB (NLB) | Disabled by default |
| Connection idle timeout (ALB) | 60 seconds (default) |
| Deregistration delay | 300 seconds (default) |
| Health check interval | 5-300 seconds |

---

## Direct Connect

| Attribute | Value |
|---|---|
| Dedicated connection speeds | 1 Gbps, 10 Gbps, 100 Gbps |
| Hosted connection speeds | 50 Mbps to 10 Gbps |
| Setup time | Weeks to months |
| Encryption | NOT encrypted by default (add VPN overlay) |
| LAG (Link Aggregation Group) | Up to 4 connections |

---

## Other Key Numbers

| Service | Attribute | Value |
|---|---|---|
| CloudTrail | Log delivery delay | ~15 minutes |
| AWS Config | Evaluation frequency | On change or periodic (1hr, 3hr, 6hr, 12hr, 24hr) |
| Step Functions Standard | Max duration | 1 year |
| Step Functions Express | Max duration | 5 minutes |
| Auto Scaling | Default cooldown | 300 seconds |
| Auto Scaling | Max instances | 200 (default, can increase) |
| Secrets Manager | Max secret size | 64 KB |
| Parameter Store Standard | Max parameter size | 4 KB |
| Parameter Store Advanced | Max parameter size | 8 KB |
| SNS/SQS max message | 256 KB |
| Cognito User Pool | Users per pool | 40,000,000 |
| Global Accelerator | Static IPs | 2 Anycast IPs |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- EC2 / EBS
- Lambda
- DynamoDB
- RDS / Aurora

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
