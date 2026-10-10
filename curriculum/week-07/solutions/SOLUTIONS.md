# Week 7 Solutions

---

## Lab 1 — ALB

### Reading target health (BF-28)

```bash
aws elbv2 describe-target-health --target-group-arn $TG \
  --query 'TargetHealthDescriptions[].{Id:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason,Desc:TargetHealth.Description}' \
  --output table
```

| Reason | Cause | Fix |
|---|---|---|
| `Target.FailedHealthChecks` | Health check path wrong, or app genuinely down | Fix the path, or the app |
| `Target.Timeout` | **SG doesn't allow the ALB**, or the app is too slow | Allow the ALB's SG on the app port |
| `Target.NotRegistered` | ASG never registered it | Check `--target-group-arns` on the ASG |
| `Target.ResponseCodeMismatch` | App returns 302 and the check expects 200 | Set `--matcher HttpCode=200-399` |
| `Elb.InternalError` | Subnet/AZ misconfiguration | Check the ALB has subnets in the target's AZ |

### The ALB error triple — know this cold

| Code | Meaning |
|---|---|
| **503** | **No healthy targets at all.** The ALB has nowhere to send the request. |
| **502** | A target responded with something malformed, or closed the connection mid-response |
| **504** | A target accepted but didn't respond within the idle timeout (default 60s) |

Same shape as nginx 502/504 in week 3, plus 503 for the "zero backends" case.

### ALB vs NLB — the decision

| | ALB | NLB |
|---|---|---|
| Layer | 7 (HTTP/HTTPS/gRPC) | 4 (TCP/UDP/TLS) |
| Routing | Path, host, header, method, query | Port only |
| Client IP | `X-Forwarded-For` header | **Preserved at the target** |
| Static IP | No (DNS name only) | **Yes, one Elastic IP per AZ** |
| TLS | Terminate or passthrough | Terminate or passthrough |
| WAF | Yes | No |
| Throughput | High | **Extreme; microsecond latency** |

**Pick NLB when:** you need a static IP (firewall allow-lists at a partner), non-HTTP protocols,
extreme throughput, or the true client IP without header parsing. **Pick ALB otherwise** — path
routing and WAF are usually worth more.

---

## Lab 2 — Auto Scaling

### Why BF-29 happens and how to read it

```bash
aws autoscaling describe-scaling-activities --auto-scaling-group-name lab-asg \
  --max-items 5 --query 'Activities[].{Time:StartTime,Status:StatusCode,Cause:Cause}' --output table
```

The loop: ASG launches → ELB health check starts immediately → app needs 3 minutes to boot →
health check fails → ASG terminates it as unhealthy → launches a replacement → repeat, forever,
burning money.

**Fix: `HealthCheckGracePeriod` longer than worst-case boot time.** Set it generously (300s) and
measure your real boot time before tightening it.

**`EC2` vs `ELB` health check type:** `EC2` only checks that the instance is running — an app that
has crashed still counts as healthy. `ELB` checks the actual application. **Use `ELB`**, and pair it
with an adequate grace period.

### Scaling policy choice

| Policy | Use |
|---|---|
| **Target tracking** | **Default choice.** Pick a metric and a target; AWS manages the alarms. |
| Step scaling | You need different responses to different breach magnitudes |
| Simple scaling | Legacy. Don't. |
| Scheduled | Known patterns — business hours, a known traffic event |

### Why scale-in is slower than scale-out — and why that's right

Default scale-in requires 15 consecutive minutes below target; scale-out reacts in ~3. **Asymmetry is
deliberate:** scaling out too slowly costs you an outage; scaling in too quickly causes flapping,
which costs you both money and stability. When in doubt, be aggressive out and conservative in.

Say that in an interview and you sound like someone who has operated an ASG.

---

## Lab 3 — RDS

### Multi-AZ vs read replica — the sentence for each

> **Multi-AZ is for availability.** A synchronous standby in another AZ, automatic failover by
> repointing the endpoint CNAME, **not readable** in the classic single-standby setup. It exists so
> you survive an AZ failure.

> **Read replicas are for scaling reads.** Asynchronous, so there's lag. Readable. Multiple allowed.
> Cross-region possible. Promotion is manual.

You often want both. Aurora blurs the line because its replicas serve reads *and* act as failover
targets.

### What the measured failover actually shows

Typical result: 60–120 seconds of connection errors, then recovery, **with the same endpoint DNS
name**.

Two things that matters for:
1. **Your application must reconnect.** A connection pool holding dead connections will keep failing
   after the database is healthy. Pools need validation queries or short max-lifetimes. This is a real
   production bug that surprises people.
2. **The DNS TTL matters.** RDS sets a short TTL on the endpoint CNAME, but a JVM caching DNS
   forever (the old `networkaddress.cache.ttl=-1` default) will keep resolving to the dead instance.
   That is a genuinely famous failure mode.

### Replication lag
```sql
-- on the replica
SELECT now() - pg_last_xact_replay_timestamp() AS lag;
```
Lag means a read-after-write can return stale data. If a user updates their profile and immediately
sees the old value, that's replica lag — and the fix is to route reads-after-writes to the primary,
not to "make replication faster."

### Why `--manage-master-user-password` is the right answer

It has RDS generate the password, store it in Secrets Manager, and rotate it automatically.
Terraform never receives the value, so it never lands in **plaintext state** (BF-36). Compare to the
alternatives:
- `random_password` in Terraform → the value is in state, plaintext, forever
- A variable → the value is in state *and* in your tfvars *and* possibly in CI logs

This is the cleanest pattern and worth naming explicitly when asked about secrets in IaC.

---

## Lab 4 — DynamoDB

### Query vs scan, with numbers

```python
r = t.query(KeyConditionExpression=Key("PK").eq("CUSTOMER#123"),
            ReturnConsumedCapacity="TOTAL")
print(r["ConsumedCapacity"])   # e.g. 0.5 RCU

r = t.scan(FilterExpression=Attr("PK").eq("CUSTOMER#123"),
           ReturnConsumedCapacity="TOTAL")
print(r["ConsumedCapacity"])   # e.g. 128 RCU on a small table -- grows with TABLE size
```

**A `FilterExpression` is applied *after* the read.** You pay for every item scanned, not every item
returned. On a large table a scan is catastrophically expensive and slow. This is the single most
important DynamoDB fact.

### GSI vs LSI

| | GSI | LSI |
|---|---|---|
| Partition key | **Different** from the table's | **Same** as the table's |
| Created | Anytime | **Only at table creation** |
| Capacity | Its own | Shared with the table |
| Consistency | **Eventually consistent only** | Can be strongly consistent |
| Size limit | None | 10 GB per partition key |
| Limit | 20 per table | 5 per table |

**In practice, use GSIs.** LSIs are rarely worth the "must decide at creation time" constraint.

### Hot partitions

All traffic hitting one partition key throttles that partition even if the table has plenty of
capacity. Classic cause: a partition key like `STATUS#ACTIVE` where 95% of rows are active. Fix by
adding a suffix (`STATUS#ACTIVE#<shard 0-9>`) and querying all shards — "write sharding."

Being able to name hot partitions as a DynamoDB failure mode is a strong signal.

---

## Lab 5 — Lambda and Fargate

### BF-30: why a Lambda in a public subnet has no internet

A VPC-attached Lambda gets an ENI in your subnet with **a private IP and no public IP** — and
Lambda ENIs cannot have one. Internet access therefore requires a route through a **NAT gateway**,
which means the Lambda must be in a **private** subnet whose route table points at a NAT in a public
subnet.

**Putting a Lambda in a "public" subnet gives it less connectivity, not more.** That inversion is
what makes this a good interview question.

The cheaper alternative: **VPC endpoints** for the specific services it needs (S3, DynamoDB via
gateway endpoints — free; Secrets Manager, KMS via interface endpoints).

### The timeout ordering bug

```
Lambda timeout:     3s
DB connect timeout: 10s
```
The Lambda is killed at 3s before the connection attempt gives up, so the log shows only "Task timed
out" with no cause. **Always make the outer timeout longer than the sum of inner timeouts**, or you
destroy your own diagnostics. This generalizes far beyond Lambda.

### Lambda + RDS: the connection problem

Each concurrent Lambda invocation opens its own database connection. A spike to 1,000 concurrent
invocations means 1,000 connections, and `db.t3.micro` maxes out around 85. The result is
`FATAL: too many connections` under exactly the load you wanted to handle.

**The answer is RDS Proxy** (connection pooling and multiplexing in front of RDS), or reserved
concurrency to cap the fan-out, or a database designed for it like DynamoDB.

**"Lambda and relational databases have a connection-count impedance mismatch, solved with RDS
Proxy"** is a senior-sounding answer to a common architecture question.

### Fargate target groups

Fargate tasks with `awsvpc` networking each get their **own ENI and private IP**, so the target group
must be `--target-type ip`, not `instance`. Using `instance` fails with a confusing registration
error. Same applies to EKS pods registered directly by the AWS Load Balancer Controller in IP mode.
