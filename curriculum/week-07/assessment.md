# Week 7 Assessment

> Closed book, 35 min + 40 SAA questions.

## Part A (15 min)
1. Multi-AZ vs read replica — one sentence each.
2. You measured the failover. What number did you get, and what must the **application** do?
3. Why doesn't the RDS endpoint change during a failover, and what breaks anyway?
4. ALB 502 vs 503 vs 504.
5. Why must the instance SG reference the ALB's **SG ID** rather than a CIDR?
6. What is `HealthCheckGracePeriod` and what happens if it's too short?
7. `EC2` vs `ELB` health check type on an ASG — which and why?
8. Why is ASG scale-in slower than scale-out by default?
9. DynamoDB query vs scan: what do you pay for in each?
10. GSI vs LSI — four differences.
11. Why does a VPC Lambda in a public subnet have no internet access?
12. Lambda at 1,000 concurrency against `db.t3.micro` — what breaks and what fixes it?

## Part B — Choose and justify (10 min)
13. Static IP required for a partner's firewall allow-list. ALB or NLB?
14. Need path-based routing and a WAF. ALB or NLB?
15. Read traffic is 10× write traffic and growing. What do you add?
16. Write traffic is the bottleneck. What are your options?
17. "Most cost-effective way to run a bursty containerized workload." What's the answer, and what
    word in the question decided it?

## Part C — Diagnose (10 min)
18. ASG instances launch and terminate in a loop. Three causes.
19. The ALB returns 503 for every request. First command, and three likely causes.
20. Users report "I updated my profile but it shows the old value." What is it and how do you fix it?

---

# Answer key

**A1.** *Multi-AZ:* synchronous standby in another AZ for **availability**; automatic failover; not
readable. *Read replica:* asynchronous copy for **read scaling**; readable; has lag; manual promotion.

**A2.** Typically 60–120 seconds. **The application must reconnect** — a connection pool holding dead
connections keeps failing after the database is healthy. Pools need connection validation or a short
max-lifetime.

**A3.** The endpoint is a CNAME that AWS repoints to the standby, so the connection string is stable.
What breaks anyway: clients that **cache DNS beyond the TTL** — the classic being a JVM with
`networkaddress.cache.ttl=-1` — keep resolving to the dead instance.

**A4.** **502** target returned a malformed response or closed the connection. **503** no healthy
targets at all. **504** target accepted but didn't respond within the idle timeout.

**A5.** The rule follows instances as they're replaced, survives IP changes, works across AZs
automatically, and is self-documenting. A CIDR rule breaks whenever the network changes — and it's
the standard cause of `Target.Timeout`.

**A6.** How long after launch the ASG ignores health checks. Too short and the ASG kills instances
before the app finishes booting — a permanent launch/terminate loop (BF-29).

**A7.** **ELB.** `EC2` only checks that the instance is running, so a crashed application still
counts as healthy. `ELB` checks the actual app — paired with an adequate grace period.

**A8.** Deliberate asymmetry. Scaling out too slowly causes an outage; scaling in too quickly causes
flapping, which costs both money and stability. Be aggressive out, conservative in.

**A9.** `query` — you pay for the items **matching the key condition**. `scan` — you pay for **every
item read**, because a `FilterExpression` is applied *after* the read. On a large table a scan is
catastrophically expensive.

**A10.** GSI: different partition key · addable anytime · own capacity · eventually consistent only ·
20 per table. LSI: same partition key · **table-creation only** · shares capacity · can be strongly
consistent · 10 GB per partition key limit · 5 per table.

**A11.** A VPC Lambda's ENI gets a private IP and **cannot have a public IP**. Internet access
therefore needs a route through a NAT gateway, which means it must be in a **private** subnet. A
public subnet gives it *less* connectivity, not more. Cheaper alternative: VPC endpoints.

**A12.** Connection exhaustion — `FATAL: too many connections`. Each concurrent invocation opens its
own connection; `db.t3.micro` maxes around 85. Fix with **RDS Proxy** (pooling/multiplexing),
reserved concurrency to cap fan-out, or a database built for it like DynamoDB.

---

**B13.** **NLB** — it provides a static Elastic IP per AZ. An ALB only gives a DNS name whose IPs
change.
**B14.** **ALB** — L7 routing and WAF integration; NLB has neither.
**B15.** **Read replicas**, plus a cache (ElastiCache) in front. Route reads to replicas, but be
ready for lag.
**B16.** Replicas don't help writes. Options: vertical scaling, sharding, moving the write-heavy
workload to something horizontally scalable (DynamoDB), or reducing writes via batching/caching.
**B17.** **Fargate Spot** (or Lambda if the work fits in 15 minutes). The deciding phrase is
**"most cost-effective"** — with "least operational overhead" you'd still say Fargate; with "lowest
latency, sustained load" you'd say EC2 with Savings Plans. Same scenario, different qualifier,
different answer.

---

**C18.** (1) `HealthCheckGracePeriod` shorter than app boot time with ELB health checks — the most
common. (2) User data exits non-zero. (3) Insufficient capacity for the instance type in that AZ, or
a spot interruption. Read `describe-scaling-activities` → `StatusMessage` and `Cause`.

**C19.** First: `aws elbv2 describe-target-health --target-group-arn ...` and read `Reason`.
Causes: (1) health check path doesn't exist on the app; (2) instance SG doesn't allow the ALB's SG —
shows as `Target.Timeout`; (3) no targets registered, or none in an AZ the ALB is attached to.

**C20.** **Read replica lag.** The write went to the primary; the immediate read hit a replica that
hadn't caught up. Fix by routing **reads-after-writes to the primary** (read-your-own-writes
consistency), or by using a session-sticky read preference. "Make replication faster" is not a fix.

## Scoring
| | |
|---|---|
| 17–20 | Move on. |
| 13–16 | Review the RDS and DynamoDB notes; redo Lab 3's measurement. |
| < 13 | Redo Labs 2 and 3. These appear heavily on SAA and in every system design round. |

Plus **≥ 72%** on the 40 SAA questions. You should be trending up week over week.
