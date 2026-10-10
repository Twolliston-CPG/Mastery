# Cheat Sheet: Migration & Disaster Recovery

Quick-reference for the SAA-C03 exam. Memorize the tables and decision rules.

---

## The 7 R's of Migration (Least to Most Change)

| # | Strategy | What | When | Key Service |
|---|---|---|---|---|
| 1 | **Retire** | Turn off | App no longer needed | Application Discovery |
| 2 | **Retain** | Keep as-is | Not ready to migrate | Migration Hub |
| 3 | **Rehost** | Lift and shift | Fastest path, minimal changes | **MGN** |
| 4 | **Relocate** | VMware to VMware Cloud on AWS | Keep VMware tooling | VMware Cloud on AWS |
| 5 | **Repurchase** | Drop and shop (SaaS) | Better SaaS alternative exists | AWS Marketplace |
| 6 | **Replatform** | Lift, tinker, shift | Small optimizations (e.g., DB to RDS) | **DMS** |
| 7 | **Refactor** | Re-architect (cloud-native) | Maximize agility, microservices | Lambda, ECS, API GW |

### Quick Decision

- "Migrate 500 servers quickly" = **Rehost (MGN)**
- "Move Oracle to Aurora PostgreSQL" = **Replatform (DMS + SCT)**
- "Same engine migration (MySQL to Aurora MySQL)" = **Replatform (DMS, no SCT)**
- "Replace Exchange with SaaS" = **Repurchase**
- "Break monolith into microservices" = **Refactor**

---

## DMS Key Facts

| Fact | Detail |
|---|---|
| Homogeneous migration | Same engine (MySQL -> MySQL). SCT NOT needed. |
| Heterogeneous migration | Different engines (Oracle -> PostgreSQL). **SCT required.** |
| CDC (Change Data Capture) | Captures ongoing changes for near-zero downtime migration. |
| Replication instance | EC2 instance managed by DMS. Must have network access to source and target. |
| Snowball Edge integration | For large databases (10+ TB). Ship data physically, then apply CDC changes. |
| S3 as target | DMS can write to S3 (for data lake migrations). |
| **MGN = servers. DMS = databases.** | Do NOT confuse them. |

---

## DR Strategies Comparison

| Strategy | RPO | RTO | Cost | Key Characteristic |
|---|---|---|---|---|
| **Backup & Restore** | Hours | Hours (up to 24h) | $ | No running infra in DR region |
| **Pilot Light** | 10s of minutes | 10s of minutes | $$ | Core data replicated; compute NOT running |
| **Warm Standby** | Minutes | Minutes | $$$ | Scaled-down but RUNNING environment |
| **Active/Active** | Near-zero | Near-zero | $$$$ | Full duplicate in both regions |

### Pilot Light vs Warm Standby (The Exam Loves This)

| | Pilot Light | Warm Standby |
|---|---|---|
| DB in DR region | Read replica (running) | Read replica (running) |
| EC2 in DR region | **NOT running** (AMI ready) | **Running** (minimum scale) |
| ALB in DR region | **NOT running** | **Running** |
| Can serve traffic now? | **No** (must start resources) | **Yes** (at reduced capacity) |

---

## DR AWS Service Mapping

| Service | DR Role |
|---|---|
| **Route 53** | Failover routing with health checks (DNS-level failover) |
| **Aurora Global DB** | < 1s cross-region replication, < 1 min promotion |
| **RDS Read Replica** | Cross-region async replication |
| **S3 CRR** | Cross-region replication for static assets |
| **AMI Copy** | Copy server images to DR region |
| **EBS Snapshot Copy** | Copy volume snapshots cross-region |
| **AWS Backup** | Centralized backup management, cross-region copy |
| **CloudFormation** | Infrastructure-as-code for rapid rebuild |

---

## RPO/RTO Quick Rules

```
RPO = "How much data can I LOSE?"
RTO = "How long can I be DOWN?"

Exam always asks: "Most cost-effective strategy that meets RPO/RTO."
Answer: Pick the CHEAPEST strategy that satisfies both numbers.

RPO/RTO both hours    --> Backup & Restore ($)
RPO/RTO both ~minutes --> Pilot Light ($$) or Warm Standby ($$$)
RPO/RTO near-zero     --> Active/Active ($$$$)
```

---

## Exam Keyword Cheat

| Keyword in Question | Likely Answer |
|---|---|
| "Minimize downtime during migration" | DMS with CDC |
| "Lift and shift 300 servers" | MGN (Rehost) |
| "Different database engines" | DMS + SCT |
| "Same database engine" | DMS (no SCT) |
| "Lowest cost DR" | Backup & Restore |
| "Near-zero RPO" | Active/Active with Aurora Global DB |
| "Core infrastructure always running" | Pilot Light |
| "Scaled-down full environment" | Warm Standby |
| "Track migration progress" | Migration Hub |
| "Discover server dependencies" | Application Discovery Service (agent) |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The 7 R's of Migration (Least to Most Change)
- DMS Key Facts
- DR Strategies Comparison
- DR AWS Service Mapping

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
