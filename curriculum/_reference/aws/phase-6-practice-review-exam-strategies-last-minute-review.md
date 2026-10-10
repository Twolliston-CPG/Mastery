# Last-Minute Review — Top 50 Facts for SAA-C03

**Read this 30 minutes before walking into the exam. Nothing else.**

---

## Compute (1-10)

**1.** Lambda max timeout is 15 minutes. If the task takes longer, use ECS Fargate or EC2.

**2.** Lambda in a VPC needs a NAT Gateway (in a public subnet) to access the internet. Use VPC endpoints for AWS services without internet.

**3.** Lambda overwhelms database connections at high concurrency. Fix it with Amazon RDS Proxy.

**4.** EC2 Instance Store provides the highest IOPS but data is lost when the instance stops or terminates. It is ephemeral.

**5.** Use IAM Roles (instance profiles) for EC2, never hardcoded access keys. Same for Lambda (execution role).

**6.** Spot Instances save up to 90% but can be interrupted with 2 minutes notice. Use for fault-tolerant batch jobs only.

**7.** Cluster placement groups provide lowest network latency (same rack, same AZ). Spread placement groups provide highest availability (different hardware, max 7 per AZ).

**8.** Fargate is serverless containers. No instance management. Scales to zero with no cost when idle.

**9.** Savings Plans: Compute Savings Plans are the most flexible (across families, regions, OS, Lambda, Fargate). EC2 Instance Savings Plans lock you to a family and region but save more.

**10.** For 24/7 steady workloads with a 3-year commitment, All Upfront Reserved Instances give the maximum discount (up to 72%).

---

## Storage (11-20)

**11.** S3 max object size is 5 TB. Use multipart upload for anything over 100 MB (required over 5 GB).

**12.** S3 has 11 nines of durability (99.999999999%) across all storage classes.

**13.** S3 Intelligent-Tiering automatically moves objects between tiers based on access patterns. No retrieval fees. Use when access patterns are unknown.

**14.** S3 Object Lock Compliance mode prevents anyone (including root) from deleting objects during the retention period. Governance mode allows override with special permissions.

**15.** S3 Cross-Region Replication only replicates NEW objects. Existing objects are NOT replicated when you enable it. Requires versioning on both buckets.

**16.** EBS gp3 is the go-to general purpose volume: 3,000 IOPS baseline, up to 16,000 IOPS, decoupled IOPS/throughput from size. Cheaper than gp2 in most cases.

**17.** EBS io2 Block Express supports up to 256,000 IOPS. Use for the highest-performance database workloads.

**18.** You CANNOT encrypt an existing unencrypted EBS volume in place. Create snapshot, copy snapshot with encryption, create new volume from encrypted snapshot.

**19.** EFS is NFS (Linux only), automatically spans AZs, auto-scales. Use lifecycle policy to move to Infrequent Access tier for up to 92% savings.

**20.** FSx for Windows = SMB + Active Directory. FSx for Lustre = high-performance Linux HPC workloads with S3 integration.

---

## Databases (21-30)

**21.** You CANNOT enable encryption on an existing unencrypted RDS instance. You must: snapshot → copy snapshot with encryption → restore to new instance.

**22.** RDS Multi-AZ provides high availability (automatic failover, 1-2 min) but the standby CANNOT serve read traffic. Use Read Replicas for read scaling.

**23.** Aurora stores 6 copies of data across 3 AZs. Supports up to 15 read replicas. Failover in ~30 seconds. Auto-scales storage to 128 TB.

**24.** Aurora Global Database replicates to up to 5 secondary regions with typically less than 1-second lag. Use for global applications.

**25.** DynamoDB is automatically distributed across 3 AZs. No Multi-AZ configuration needed.

**26.** DynamoDB max item size is 400 KB. For larger objects, store in S3 and put the S3 URL in DynamoDB.

**27.** DAX provides microsecond read latency for DynamoDB. It is a drop-in replacement (same API). It ONLY works with DynamoDB.

**28.** ElastiCache for Redis supports persistence, replication, Multi-AZ, and sorted sets (leaderboards). Memcached does not support any of these.

**29.** DynamoDB Streams + Lambda is the pattern for event-driven processing on table changes.

**30.** Redshift is for OLAP (data warehousing). Do NOT confuse it with RDS/Aurora (OLTP). Athena is for ad-hoc queries on S3 data.

---

## Networking (31-38)

**31.** Security Groups: allow rules ONLY, stateful (return traffic automatic), instance level, can reference other SGs.

**32.** NACLs: allow AND deny rules, stateless (must allow both directions explicitly), subnet level, rules evaluated in order.

**33.** To block a specific IP address: use a NACL deny rule. Security groups CANNOT deny.

**34.** NACLs are stateless — if you allow inbound port 80, you must also allow outbound on ephemeral ports (1024-65535).

**35.** VPC Gateway Endpoints: S3 and DynamoDB ONLY. Free. Route table entry. Use these to avoid NAT Gateway costs.

**36.** VPC Interface Endpoints (PrivateLink): most other AWS services. Creates an ENI. Costs per hour + per GB.

**37.** NAT Gateway: managed, up to 100 Gbps, $0.045/hr + $0.045/GB. Deploy one per AZ for high availability. Cannot be used as bastion host.

**38.** Direct Connect takes weeks to months to set up. Site-to-Site VPN takes hours. Use VPN first, then migrate to Direct Connect. Direct Connect is NOT encrypted by default — add a VPN overlay for encryption.

---

## Security (39-44)

**39.** Secrets Manager supports automatic rotation of database credentials (built-in for RDS). Parameter Store does NOT have native automatic rotation.

**40.** ACM provides free SSL/TLS certificates that auto-renew. Works with ALB, CloudFront, API Gateway. For auto-renewal, DNS validation CNAME record must remain in place.

**41.** CloudTrail logs API calls. For tamper-proof storage: send to S3 with Object Lock (Compliance mode). Enable in all regions with a multi-region trail.

**42.** GuardDuty detects threats (compromised instances, unusual API calls, cryptocurrency mining). It does NOT block — it only detects and alerts.

**43.** WAF protects against SQL injection, XSS, and bad bots. Works with ALB, CloudFront, and API Gateway. Shield Standard is free DDoS protection. Shield Advanced ($3K/month) adds DDoS Response Team and cost protection.

**44.** SCPs restrict permissions for all accounts in the organization EXCEPT the management account. SCPs do not grant permissions — they only set guardrails.

---

## Architecture Patterns (45-50)

**45.** To decouple application tiers: put an SQS queue between them. The producer writes to the queue, the consumer reads at its own pace. Auto Scaling the consumer based on queue depth.

**46.** SNS fan-out pattern: SNS topic with multiple SQS queue subscriptions. Each queue gets every message independently. Use this when multiple services need to process the same event.

**47.** DR strategies from cheapest to fastest: Backup & Restore (hours) → Pilot Light (tens of minutes) → Warm Standby (minutes) → Multi-Site Active-Active (near zero).

**48.** CloudFront is for HTTP/HTTPS content delivery (caching). Global Accelerator is for TCP/UDP with static Anycast IPs (no caching). If the question mentions static IPs or non-HTTP protocols, choose Global Accelerator.

**49.** For cross-account S3 access where the user needs to KEEP their existing permissions: use a resource-based policy (bucket policy). If assuming a role, the user GIVES UP their original permissions.

**50.** The serverless trifecta for unpredictable/low traffic: API Gateway + Lambda + DynamoDB (on-demand). Near-zero cost at zero traffic. This is almost always the answer when the question says "unpredictable traffic" AND "minimize cost."

---

## Final Reminders

- There is NO penalty for wrong answers. NEVER leave a question blank.
- Read the last sentence of the question first — it tells you what they are really asking.
- "Least operational overhead" almost always means managed service or serverless.
- "Most cost-effective" does NOT always mean cheapest — it means the cheapest option that meets ALL requirements.
- When stuck between two answers, ask: "What would AWS recommend?" AWS always favors managed services.
- Trust your preparation. You have done the work. Go pass this exam.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Compute (1-10)
- Storage (11-20)
- Databases (21-30)
- Networking (31-38)

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
