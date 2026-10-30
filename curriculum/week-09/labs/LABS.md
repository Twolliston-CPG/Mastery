# Week 9 — Consolidation Activities

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (9.2 to 9.6). Read a lab's figure
> before you start it; redraw it after.

There are no new labs this week. These are consolidation exercises.

---

## Activity 1 — The whiteboard drill (do this three times this week)

Blank paper. No notes. 20 minutes. Draw and **narrate out loud**:

> A highly available, secure, cost-conscious three-tier web application on AWS, serving a global
> audience, storing relational data, with an RTO of 15 minutes and an RPO of 5 minutes.

Must include and **justify**: VPC CIDR and subnet layout across AZs · IGW, NAT, route tables · ALB
and target groups · ASG with a scaling policy · RDS Multi-AZ · S3 with lifecycle · CloudFront + OAC ·
Route 53 alias · KMS · Secrets Manager · CloudWatch alarms · the DR strategy that meets 15min/5min.

**Then answer, unprompted:**
- What happens when an AZ fails?
- What happens when the database fails over, and what must the app do?
- Where does it cost the most, and what would you change if the budget were halved?
- What's the single biggest risk in this design?

Record yourself once. You will hear the gaps.

---

## Activity 2 — The comparison sprint

`_shared/drills/aws-comparisons.md`, cover the right column, **say each distinction out loud in one
sentence**. Target: the whole file in 15 minutes with no misses.

Do it Tuesday, Thursday, and Saturday.

---

## Activity 3 — Rebuild your two weakest domains by hand

Whatever Monday's exam showed as weakest, **build it again in the console**. Not read about —
build. Two hours per domain.

If the weak domain was:
| Domain | Rebuild |
|---|---|
| Secure architectures | The week-5 IAM policies, plus a KMS key policy that denies an S3-permitted role |
| Resilient architectures | The week-7 ASG + RDS failover measurement |
| High-performing | CloudFront + a cache policy; a DynamoDB GSI; an ElastiCache node |
| Cost-optimized | An S3 lifecycle policy; a Spot ASG; a Cost Explorer view by tag; replace a NAT with an endpoint |

**Building beats re-reading by a wide margin at this stage.** You already have the vocabulary; what
you're missing is the connection between the vocabulary and the thing.

---

## Activity 4 — Service limits and numbers

From `_reference/aws/phase-6-practice-review-final-cheat-sheets-service-limits-and-numbers.md`,
memorize the numbers that actually appear on the exam:

- S3: 5 TB max object, 5 GB max single PUT, 100 buckets soft limit, **11 nines durability**
- VPC: 5 VPCs per region (soft), **/16 to /28** CIDR range, **5 reserved IPs per subnet**
- EBS: gp3 3,000 IOPS / 125 MB/s baseline, io2 Block Express up to 256,000 IOPS
- Lambda: **15 min max**, 10 GB memory, 512 MB–10 GB ephemeral storage, 1,000 default concurrency
- SQS: 256 KB message, **14 day max retention**, 12 hour max visibility timeout
- DynamoDB: 400 KB item, **20 GSIs / 5 LSIs**, 10 GB per LSI partition
- RDS: 5 read replicas (most engines), 15 for Aurora
- ELB: ALB idle timeout **60s** default
- KMS: **4 KB** direct encrypt limit, 7–30 day deletion window

---

## Activity 5 — Book it, and plan week 10

If the exam isn't booked, book it now. Then read week 10's README — **Project Alpha starts the day
after the exam**, and knowing that keeps the exam in proportion. It is a milestone, not a
destination.
