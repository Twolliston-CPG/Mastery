# ★ GATE 2 — SAA Readiness

> This gate is **measured**, not self-assessed. The measurement is two practice exams.

## The gate

| Criterion | Threshold |
|---|---|
| Full-length practice exam A | **≥ 80%** |
| Full-length practice exam B (a *different* exam) | **≥ 80%** |
| Guessed-correct rate | **< 10%** — track it while you take them |
| Whiteboard the 3-tier architecture from memory, out loud | Complete, with justifications |
| Comparison drill, whole file, one sentence each | No misses |

**Two different exams matters.** One 80% can be a question set that happened to match your strengths.
Two is a signal.

---

## The self-check (do this Saturday, closed book, 30 min)

Write out from memory:

1. The **IAM policy evaluation order**, all seven steps
2. The **four DR strategies** with RTO, RPO, relative cost, and what's running
3. **SG vs NACL** — five differences
4. **Multi-AZ vs read replica** — one sentence each
5. **ALB vs NLB** — when each, four differentiators
6. **SQS vs SNS vs EventBridge** — one sentence each
7. **Gateway vs interface endpoint** — services, cost, mechanism
8. **GSI vs LSI** — four differences
9. **Savings Plan vs RI vs Spot vs On-Demand**
10. The **five AWS-reserved IPs** in every subnet and why usable = total − 5
11. The **storage class** decision table
12. What makes a **subnet public**
13. Why a **NAT gateway must be in a public subnet**
14. How an **EC2 instance gets credentials with no keys on disk**, and what IMDSv2 changed
15. Which **KMS permission** `GetObject` needs vs `PutObject`, and which two policies must grant it

Every one of these is in `_shared/drills/aws-comparisons.md` and in the weekly assessments for weeks
5–8. If any is shaky, that is your Sunday review.

---

## Gate result

| | |
|---|---|
| **PASS** — both exams ≥ 80%, guess rate < 10% | **Sit the exam in week 10 as planned.** |
| **NEAR** — one exam ≥ 80%, or 75–79% on both | Take a third exam Friday. If ≥ 80%, proceed. If not, **move the exam one week.** |
| **FAIL** — below 75% | **Move the exam to week 11.** Spend week 10 on targeted remediation *and* start Terraform in parallel — do not lose the whole week to exam prep. |

### If you move the exam

This is not a setback and it should not cost you momentum. **Start Terraform and Project Alpha in
week 10 anyway**, on the schedule in week 10's README, and fold ~10 hours/week of SAA remediation
alongside it. The week-14 milestone — two certs, Alpha shipped, applications begin — has a week of
slack built in precisely for this.

What you must **not** do is stop building to study. A candidate with a cert and no projects loses to
a candidate with projects and one fewer cert. See [`../../ROADMAP.md` R3](../../ROADMAP.md).

---

## After you pass the exam (week 10)

Same day:
- [ ] Update your résumé — certifications go **near the top**
- [ ] Update LinkedIn with a short post about what you actually learned, not just the badge
- [ ] Add it to your GitHub profile README
- [ ] Check for the AWS 50%-off voucher for your next exam — it usually arrives within a few days
      and applies to the Terraform-adjacent or specialty exams later

Then **take the rest of exam day off**, and start Terraform on Wednesday. Week 10's plan assumes
exactly that.
