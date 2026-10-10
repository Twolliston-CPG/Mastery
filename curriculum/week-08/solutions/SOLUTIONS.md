# Week 8 Solutions

---

## Lab 1 — Decoupling

### BF-31, precisely

```bash
aws sqs get-queue-attributes --queue-url $Q --attribute-names All \
  --query 'Attributes.{VT:VisibilityTimeout,InFlight:ApproximateNumberOfMessagesNotVisible,Redrive:RedrivePolicy}'
```

The message becomes visible again while your consumer is still working on it, so a second consumer
picks it up. You get duplicate processing — double charges, double emails, double writes.

**Three fixes, in order of correctness:**
1. **Make the consumer idempotent.** SQS standard is **at-least-once by design**. Duplicates are a
   property to handle, not a bug to eliminate. Use an idempotency key and a conditional write.
2. Set `VisibilityTimeout` ≥ **6× the Lambda timeout** (AWS's own recommendation).
3. Extend the lease during long work with `ChangeMessageVisibility`.

**The sentence for an interview:** *"At-least-once delivery means idempotency is the consumer's
responsibility."* That answers a whole family of distributed-systems questions.

### The `maxReceiveCount` / DLQ math

`maxReceiveCount: 3` means: after 3 unsuccessful receives (each one ending in the visibility timeout
elapsing without a delete), the message moves to the DLQ. So a poison message costs you
`3 × VisibilityTimeout` before it stops consuming capacity.

**A DLQ with nothing monitoring it is a silent data-loss mechanism.** Always alarm on
`ApproximateNumberOfMessagesVisible > 0` on the DLQ.

### SQS vs SNS vs EventBridge — the decision

| | Model | Use |
|---|---|---|
| **SQS** | Queue, consumer **pulls** | Decouple and **buffer**; absorb bursts; one logical consumer |
| **SNS** | Pub/sub, **push** fan-out | One event, many subscribers, simultaneously |
| **EventBridge** | Pub/sub with **content-based rules** | Routing logic belongs in infrastructure, not code; SaaS sources; scheduling |

**The classic combined pattern** is SNS → multiple SQS queues: broadcast *plus* per-consumer
buffering and independent retry. Being able to draw that is a good system-design answer.

### FIFO throughput

Ordering is per `MessageGroupId`. One group = strictly serial for the whole queue. Many groups =
parallelism up to the number of groups. **So the group ID choice is a throughput decision** — use the
narrowest thing that genuinely requires ordering (e.g. per-customer, not global).

---

## Lab 2 — KMS

### Envelope encryption, and why the 4 KB limit exists

```bash
aws kms generate-data-key --key-id alias/lab --key-spec AES_256
# returns: Plaintext (the data key) + CiphertextBlob (that key, encrypted by the CMK)
```

You encrypt your data locally with the plaintext data key, then **discard the plaintext key** and
store the encrypted copy next to the ciphertext. To decrypt, you send the encrypted data key to KMS,
get the plaintext key back, and decrypt locally.

**KMS never sees your data.** That is why `kms:Encrypt` is limited to 4 KB — it's meant for keys and
small secrets, not files. S3, EBS, and RDS all use envelope encryption under the hood.

### The BF-26 mechanism, stated exactly

| Operation | KMS permission required |
|---|---|
| `s3:GetObject` on an SSE-KMS object | `kms:Decrypt` |
| `s3:PutObject` to an SSE-KMS bucket | `kms:GenerateDataKey` |

And each must be granted by **both** the IAM policy **and** the **key policy**. The key policy is a
separate gate that IAM cannot override — `kms:*` on `*` in IAM does nothing if the key policy omits
the principal.

**The asymmetry is the diagnostic:** uploads working while downloads fail points straight at KMS.

### Encryption context

```bash
aws kms encrypt --key-id alias/lab --plaintext ... \
  --encryption-context Purpose=lab,Owner=team-a
# Decrypt with a different context -> InvalidCiphertextException
```
It's additional authenticated data: it doesn't change the key, but it must match exactly on decrypt,
and it appears in CloudTrail — so you get auditability and a binding between ciphertext and intended
use.

### Secrets Manager vs Parameter Store

| | Secrets Manager | Parameter Store |
|---|---|---|
| Rotation | **Built in**, with Lambda | None |
| Cost | ~$0.40/secret/month + API calls | **Free** (standard tier) |
| Size | 64 KB | 4 KB standard / 8 KB advanced |
| Cross-region replication | Yes | No |
| Native RDS integration | **Yes** (`manage_master_user_password`) | No |

**Rule of thumb:** database credentials and anything needing rotation → Secrets Manager. Config
values and non-rotating API keys → Parameter Store SecureString. Cost matters at scale — 500 secrets
is $200/month.

### Why key deletion has a mandatory waiting period

Deleting a CMK makes **every object ever encrypted with it permanently unreadable** — there is no
recovery, by design. The 7–30 day window is a last line of defense against an irreversible mistake.
`kms:ScheduleKeyDeletion` should be denied by SCP in production.

---

## Lab 3 — CloudWatch and CloudTrail

### BF-32: why alarms don't fire

| Cause | Symptom | Check |
|---|---|---|
| **Dimension mismatch** | `INSUFFICIENT_DATA` | Does `get-metric-statistics` with those exact dimensions return anything? |
| Period < publishing interval | `INSUFFICIENT_DATA` | EC2 basic monitoring is **5 min**, not 1 |
| `TreatMissingData: notBreaching` | Stays `OK` during an outage | If the source dies, no data is published — and "no data" is being read as healthy |
| Evaluation window too long | Never fires | `EvaluationPeriods × Period` > event duration |
| **SNS subscription unconfirmed** | Alarm goes to ALARM, no email | `aws sns list-subscriptions-by-topic` → look for `PendingConfirmation` |

**The `TreatMissingData` trap is the dangerous one.** If your metric is published *by the thing that
died*, treating missing data as "not breaching" means your alarm is silent during exactly the outage
it exists to catch. For liveness-style metrics use `breaching`, or add a separate `absent()`-style
check.

### Test every alarm

```bash
aws cloudwatch set-alarm-state --alarm-name X --state-value ALARM --state-reason "test"
aws sns list-subscriptions-by-topic --topic-arn $SNS_TOPIC \
  --query 'Subscriptions[].{Endpoint:Endpoint,Arn:SubscriptionArn}'
# SubscriptionArn == "PendingConfirmation" means nobody is receiving anything
```

**An alarm that has never been observed to fire is not monitoring.** This principle recurs in week 20
and is worth saying out loud in an SRE interview.

### CloudTrail management vs data events

Management events (control plane — `RunInstances`, `CreateBucket`, `AssumeRole`) are recorded by
default and free for the first copy. **Data events** (`s3:GetObject`, `lambda:Invoke`,
`dynamodb:GetItem`) are **off by default** because the volume and cost are enormous.

**Consequence:** "who read this file?" is unanswerable after the fact unless S3 data events were
already enabled. In an incident that's the question you most want answered, so for sensitive buckets
enable them **in advance**.

---

## Lab 4 — CloudFront, Route 53, Organizations

### Why OAC instead of a public bucket

```json
{
  "Effect": "Allow",
  "Principal": {"Service": "cloudfront.amazonaws.com"},
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::BUCKET/*",
  "Condition": {"StringEquals": {"AWS:SourceArn": "arn:aws:cloudfront::ACCT:distribution/EDFDVBD6"}}
}
```
The bucket stays private with Block Public Access on; only that specific distribution can read it.
You also get edge caching, TLS with your own domain, WAF, and no risk of someone listing the bucket.

**OAC replaced OAI** (Origin Access Identity), which is legacy — OAC supports SSE-KMS and all
regions. Naming OAC rather than OAI is a small currency signal.

### The alias record, again

A CNAME cannot exist at the zone apex (week 3). A Route 53 **alias** can, resolves directly to the
target's IP with no second lookup, and is free to query. Alias targets include CloudFront, ALB/NLB,
S3 website endpoints, and API Gateway.

### SCPs cap, they never grant

An SCP allowing `s3:*` gives nobody any access — it only means IAM within those accounts is
*permitted* to grant S3. Effective permission = **SCP ∩ IAM identity policy ∩ permission boundary**.

The SCP everyone should have:
```json
{
  "Effect": "Deny",
  "Action": ["organizations:LeaveOrganization", "cloudtrail:StopLogging",
             "cloudtrail:DeleteTrail", "kms:ScheduleKeyDeletion"],
  "Resource": "*"
}
```
Region restriction with `aws:RequestedRegion` is the other common one — it caps blast radius and
stops shadow resources appearing in regions nobody monitors.

---

## Lab 5 — DR and cost

### The four strategies, filled in

| Strategy | RTO | RPO | Cost | What's running in DR |
|---|---|---|---|---|
| **Backup & Restore** | Hours–days | Hours | $ | Nothing. Just backups. |
| **Pilot Light** | 10s of minutes | Minutes | $$ | Data replicated; core services off; AMIs ready |
| **Warm Standby** | Minutes | Seconds | $$$ | A scaled-down but **live** copy; scale up on failover |
| **Multi-Site Active/Active** | Near zero | Near zero | $$$$ | Full capacity in both regions, both serving |

**RTO = how long to get back up. RPO = how much data you can afford to lose.** Both are *business*
decisions that drive the architecture, not the other way round — and stating it that way is the
answer interviewers want.

The trap: **untested DR is not DR.** A restore procedure nobody has executed has an unknown RTO, and
the honest answer is "infinity until proven otherwise."

### Cost optimization, ranked by typical impact

1. **Turn off what isn't used.** Non-production on a schedule. Usually the single biggest win.
2. **Rightsize.** Compute Optimizer finds over-provisioned instances.
3. **Savings Plans** for steady baseline; **Spot** for anything interruption-tolerant.
4. **Storage lifecycle.** S3 tiering, delete orphaned EBS volumes and old snapshots.
5. **Data transfer.** Cross-AZ and NAT gateway processing charges are large and invisible.
   VPC endpoints remove much of it (week 6).

**Savings Plans vs Reserved Instances:** an RI commits to instance attributes; a Savings Plan commits
to **$/hour of spend** and applies across instance families, regions, and even Fargate/Lambda.
Compute Savings Plans are more flexible and are the usual right answer.

### Tagging

```bash
aws ce get-cost-and-usage --group-by Type=TAG,Key=Environment ...
```
Untagged resources are unattributable, and unattributable cost is cost nobody owns. Enforce tags with
an SCP condition on `aws:RequestTag`, and backfill with AWS Config rules. This is the FinOps
foundation for week 23's platform cost reporting.
