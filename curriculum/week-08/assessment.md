# Week 8 Assessment

> Closed book, 35 min + 50 SAA questions. **Week 9 is exam prep — you should be near ready.**

## Part A (20 min)
1. SQS vs SNS vs EventBridge — one sentence each.
2. A message is processed twice. What happened and what are the three fixes, in order?
3. What does "at-least-once delivery" imply about the consumer?
4. What is `maxReceiveCount` and what must you also do with a DLQ?
5. Explain envelope encryption. Why is `kms:Encrypt` limited to 4 KB?
6. Which KMS permission does `GetObject` need? Which does `PutObject`? Which two policies must grant it?
7. Secrets Manager vs Parameter Store — three differences.
8. Why does KMS key deletion have a mandatory waiting period?
9. Five reasons a CloudWatch alarm never fires.
10. Why is `TreatMissingData: notBreaching` dangerous?
11. Why can't you answer "who read this S3 object?" by default?
12. Why use CloudFront + OAC instead of a public bucket? Name three benefits.
13. Do SCPs grant permissions? What is the effective-permission formula?
14. The four DR strategies with RTO, RPO, and what's running.
15. Savings Plans vs Reserved Instances.

## Part B — Scenarios (15 min)
16. Bursty traffic overwhelms a downstream service. What do you put between them and why?
17. One event must trigger three independent systems. What do you use?
18. Routing depends on a field inside the event payload. What do you use?
19. "Lowest RTO regardless of cost." Which DR strategy?
20. "We can lose up to 4 hours of data and be down for a day." Which DR strategy, and why is it the
    right answer rather than a cheap one?

---

# Answer key

**A1.** **SQS** — a queue; one consumer group pulls; decouples and buffers. **SNS** — pub/sub push
fan-out to many subscribers at once. **EventBridge** — pub/sub with content-based routing rules,
schemas, SaaS sources, and scheduling.

**A2.** The `VisibilityTimeout` was shorter than the processing time, so the message became visible
again mid-processing and a second consumer took it. Fixes: (1) **make the consumer idempotent**,
(2) set the visibility timeout ≥ 6× the function timeout, (3) extend the lease with
`ChangeMessageVisibility`.

**A3.** That the consumer **must be idempotent**. Duplicates are a designed property of SQS standard
queues, not a defect.

**A4.** The number of unsuccessful receives before a message is moved to the DLQ. You must also
**alarm on the DLQ depth** — an unmonitored DLQ is a silent data-loss mechanism.

**A5.** KMS returns a data key in two forms: plaintext and encrypted-under-the-CMK. You encrypt data
locally with the plaintext key, discard it, and store the encrypted key alongside the ciphertext.
**KMS never sees your data**, which is why direct `kms:Encrypt` is capped at 4 KB — it's for keys and
small secrets.

**A6.** `GetObject` → `kms:Decrypt`. `PutObject` → `kms:GenerateDataKey`. Both the **IAM policy** and
the **key policy** must grant it; the key policy is a separate gate IAM cannot override.

**A7.** Rotation (built in vs none) · cost (paid per secret vs free standard tier) · size (64 KB vs
4 KB) · cross-region replication (yes vs no) · native RDS integration. Any three.

**A8.** Because deleting a CMK makes every object ever encrypted with it **permanently unreadable**,
with no recovery. The 7–30 day window is the last defense against an irreversible mistake.

**A9.** Dimension mismatch (`INSUFFICIENT_DATA`) · period shorter than the publishing interval ·
`TreatMissingData` masking it · evaluation window longer than the event · custom metric never
published · **SNS subscription never confirmed**.

**A10.** If the metric is published *by the thing that died*, no data is published during the
outage — and "no data" is then interpreted as healthy. The alarm is silent during exactly the event
it exists to catch.

**A11.** `s3:GetObject` is a **data event**, and CloudTrail data events are **off by default**
because of volume and cost. Only management (control-plane) events are recorded by default. You must
enable data events **in advance** for sensitive buckets.

**A12.** The bucket stays private with Block Public Access on · edge caching and lower latency · TLS
on your own domain · WAF integration · no risk of accidental bucket listing. Any three.

**A13.** **No — SCPs only cap.** Effective = **SCP ∩ identity policy ∩ permission boundary ∩ session
policy**, with any explicit Deny winning outright.

**A14.** Backup & Restore (RTO hours–days, RPO hours, cheapest, nothing running) · Pilot Light (RTO
tens of minutes, RPO minutes, data replicated + core off) · Warm Standby (RTO minutes, RPO seconds,
scaled-down live copy) · Multi-Site Active/Active (RTO/RPO ≈ 0, most expensive, full capacity both
regions).

**A15.** An **RI** commits to specific instance attributes (family, region, sometimes AZ). A
**Savings Plan** commits to a **dollar-per-hour of compute spend** and applies flexibly across
families, sizes, regions, and even Fargate and Lambda. Compute Savings Plans are the usual right
answer.

---

**B16.** **SQS.** It buffers the burst so the downstream service consumes at its own rate instead of
being overwhelmed — backpressure without failure. (Add a DLQ and alarm on its depth.)

**B17.** **SNS** fan-out — one publish, three subscribers. Better still: SNS → three SQS queues, so
each consumer also gets buffering and independent retry.

**B18.** **EventBridge** — content-based rules match on the payload, keeping routing logic in
infrastructure rather than application code.

**B19.** **Multi-Site Active/Active.**

**B20.** **Backup & Restore.** RPO of 4 hours and RTO of a day are entirely satisfied by it. **It is
the right answer, not merely a cheap one** — spending on Warm Standby to beat requirements nobody
asked for is a failure of engineering judgment, not a success. Matching the architecture to the
stated RTO/RPO *is* the skill.

## Scoring
| | |
|---|---|
| 17–20 | On track for the week-10 exam. |
| 13–16 | Review the security and monitoring notes this weekend. |
| < 13 | **Consider moving the exam to week 11.** Better a one-week delay than a retake. |

Plus **≥ 75%** on the 50 questions. Week 9's gate is 80% on two full-length practice exams.
