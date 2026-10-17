# Week 9 — SAA Consolidation ★ GATE 2

> **The only week where exam prep dominates — and it is capped at one week by design.**
> Certification study that displaces building is the failure mode of this whole program. One week,
> then back to building.

| | |
|---|---|
| **Hours** | 35–40 (and **not more** — see the Sunday rule) |
| **Deliverable** | Two full-length practice exams at 80%+ |
| **★ GATE 2** | 80%+ on two *different* full-length practice exams, and whiteboard the month-2 architecture from memory |

## The week in one figure

**Figure 9.1 — The consolidation loop that produces an 80 percent.** One week of exam prep, capped by design. The figure is the loop: take an exam cold, find the two weakest domains, rebuild them by hand, and test again. The gate is the number at the end.

![Figure 9.1 — The consolidation loop that produces an 80 percent](content/figure-9.1-the-consolidation-loop-that-produces-an.png)

**Say it, badge by badge:** [`content/FIGURE.md`](content/FIGURE.md) — the spoken script for each of the 11 badges, about three minutes; [`content/figure-9.1-numbered-spoken.pdf`](content/figure-9.1-numbered-spoken.pdf) is the printable two-page version. Read the figure before the day plan; say the script on Friday.

---

## The week's shape

| Day | Activity | Hours |
|---|---|---|
| **Mon** | Full practice exam #1, **cold**. Score it. Categorize every miss by domain. | 4 |
| **Tue** | Targeted remediation: **the two weakest domains only**. Rebuild those services by hand. | 6 |
| **Wed** | Continue remediation. Re-read the notes for those domains. Write Anki cards for every miss. | 6 |
| **Thu** | Full practice exam #2. Review **every** question — including ones you got right by guessing. | 5 |
| **Fri** | Practice exam #3 + flashcard sweep of the comparison pairs and service limits | 5 |
| **Sat** | Whiteboard the full 3-tier architecture from memory, out loud, justifying every choice. Book the exam if you haven't. | 3 |
| **Sun** | **Rest.** Light review only. No cramming. | 1 |

## The Sunday rule

**Do not cram the day before the exam.** It measurably lowers scores — you arrive tired, your recall
is worse, and anything genuinely new learned in the last 24 hours won't be retrievable under time
pressure anyway. Light review, sleep, exercise, and go in fresh.

## Materials

**Practice exams** (in the reference library, already written):
- `_reference/aws/phase-6-practice-review-practice-exams-practice-exam-1.md`
- `-practice-exam-2.md`
- `-practice-exam-3.md`

**Review guides by exam domain:**
- `-review-guides-domain-1-secure-architectures.md`
- `-review-guides-domain-2-resilient-architectures.md`
- `-review-guides-domain-3-high-performing-architectures.md`
- `-review-guides-domain-4-cost-optimized-architectures.md`
- **`-review-guides-commonly-confused-services.md`** ← read this twice

**Final cheat sheets:**
- `-final-cheat-sheets-ultimate-cheat-sheet.md`
- `-final-cheat-sheets-service-limits-and-numbers.md`
- `-final-cheat-sheets-port-numbers-protocols.md`

**Exam strategy:**
- `-exam-strategies-exam-day-guide.md`
- `-exam-strategies-keyword-decision-matrix.md`
- `-exam-strategies-last-minute-review.md`

**Drills:** `_shared/drills/aws-comparisons.md` — the whole file, twice. It is ~40% of the exam.

## How to review a practice exam properly

Most people score an exam, feel bad about the misses, and move on. That wastes the exam.

For **every** question — right or wrong:

1. **Why is the correct answer correct?**
2. **Why is each wrong answer wrong?** (This is where the learning is. Distractors are chosen to
   match a plausible misconception.)
3. **Which qualifier decided it?** "Most cost-effective" vs "least operational overhead" vs "highest
   availability" select different answers from the same scenario.
4. **Did I get it right for the right reason, or did I guess?** Track guesses separately. A 78% with
   15% guessing is really a 63%.

Then write an Anki card, in your own words, for every miss and every lucky guess. Same day.

## The exam-day heuristic

Read the **last sentence first**. The qualifier picks the answer:

| Qualifier | Bias toward |
|---|---|
| "most cost-effective" | Spot, S3 lifecycle, Savings Plans, serverless, gateway endpoints |
| "least operational overhead" | Managed — Fargate, Aurora, Lambda, RDS over self-managed |
| "highest availability" | Multi-AZ, multi-region, ASG across AZs |
| "most secure" | IAM roles over keys, KMS, private subnets, VPC endpoints, least privilege |
| "real-time / sub-second" | Kinesis, DynamoDB, ElastiCache, NLB |
| "decouple" | SQS |
| "fan-out" | SNS |
| "existing on-premises" | Direct Connect, Site-to-Site VPN, Storage Gateway, Outposts |

Then eliminate. AWS questions typically have two obviously wrong options and two plausible ones, and
the difference between the final two is almost always **cost** or **operational overhead**.

## Booking

**Book the exam now if you haven't.** An unbooked exam slips forever; a booked one creates the
deadline that makes the studying happen. Morning slot, test center over online proctoring if you can
— online proctoring adds avoidable failure modes (room scans, connection drops) on the one day they
are most expensive.

Non-native English speakers: request the **additional 30 minutes** from AWS in advance. It's granted
routinely and is not noted on the result.

See [`../../CERTIFICATIONS.md`](../../CERTIFICATIONS.md) §7 for full exam tactics.

## ★ GATE 2

- [ ] **80%+ on two different full-length practice exams**
- [ ] Whiteboard the month-2 architecture from memory, out loud, justifying every choice
- [ ] Recite the IAM policy evaluation order
- [ ] Recite the four DR strategies with RTO/RPO
- [ ] All comparison pairs in `_shared/drills/aws-comparisons.md` answerable in one sentence each

**If you fail the gate, move the exam by a week.** A retake costs more time, more money, and more
morale than a one-week delay. This is a genuinely rational choice, not a concession.

See [assessment.md](assessment.md) for the gate itself.
