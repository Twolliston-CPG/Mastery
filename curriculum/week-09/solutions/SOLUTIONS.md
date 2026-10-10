# Week 9 — Consolidation Notes

There are no lab solutions this week. Week 9 is exam consolidation, and the "solutions" are the
answer keys that already ship with the practice material.

## Where the answers live

| Activity | Answer key |
|---|---|
| Practice exams 1–3 | Answers and explanations are embedded in `_reference/aws/phase-6-practice-review-practice-exams-practice-exam-[123].md` |
| Comparison drill | `_shared/drills/aws-comparisons.md` — the right-hand column |
| Domain review | `_reference/aws/phase-6-practice-review-review-guides-domain-[1-4]-*.md` |
| The pairs people confuse | `_reference/aws/phase-6-practice-review-review-guides-commonly-confused-services.md` |
| Service limits and numbers | `_reference/aws/phase-6-practice-review-final-cheat-sheets-service-limits-and-numbers.md` |
| Gate 2 self-check | [`../assessment.md`](../assessment.md) |

---

## How to actually review a practice exam

Most people score an exam, feel bad about the misses, and move on. That wastes the exam — the score
is the least useful thing it produces.

For **every** question, right or wrong:

1. **Why is the correct answer correct?**
2. **Why is each wrong answer wrong?** This is where the learning is. Distractors are deliberately
   chosen to match a plausible misconception, so working out *which* misconception each one targets
   teaches you more than the correct answer does.
3. **Which qualifier decided it?** "Most cost-effective" · "least operational overhead" · "highest
   availability" select **different** answers from the same scenario. If you can't say which phrase
   drove the answer, you got it right by pattern-matching rather than reasoning.
4. **Did I guess?** Track guesses separately. **A 78% with 15% guessing is really a 63%**, and the
   gap is exactly what shows up on exam day when the wording is slightly different.

Then write an Anki card, in your own words, for every miss **and every lucky guess**. Same day.

---

## The remediation rule

Tuesday and Wednesday are for **your two weakest domains only**. Not all four.

And remediate by **building**, not re-reading. You already have the vocabulary; what's missing is the
connection between the vocabulary and the thing.

| Weak domain | Rebuild this |
|---|---|
| Domain 1 — Secure architectures | The week-5 IAM policies, plus a KMS key policy that denies a role which *has* S3 permissions |
| Domain 2 — Resilient architectures | The week-7 ASG recovery and RDS failover measurements |
| Domain 3 — High-performing | CloudFront with a cache policy; a DynamoDB GSI; compare a query's consumed capacity to a scan's |
| Domain 4 — Cost-optimized | An S3 lifecycle policy; a Spot ASG; a Cost Explorer view by tag; replace a NAT gateway with a gateway endpoint |

**Two hours of building beats six hours of re-reading at this stage.** Recognition is not retrieval,
and the exam tests retrieval.

---

## The one thing not to do

**Do not extend this week.** Exam preparation expands to fill whatever time it is given, and it
displaces building — which is the failure mode this whole program is designed against
([`../../ROADMAP.md`](../../../ROADMAP.md) R3).

If Gate 2 fails, **move the exam by a week and start Terraform anyway** in week 10, folding ~10 hours
of remediation alongside it. The week-14 milestone — two certs, Alpha shipped, applications begin —
has a week of slack built in for exactly this.

What you must not do is stop building to study. A candidate with a certification and no projects
loses to a candidate with projects and one fewer certification.
