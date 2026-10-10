# Phase 6: Practice & Review (Weeks 11-12)

## The Final Push — Putting It All Together

This is where everything you have learned in Phases 1 through 5 comes together. Phase 6 is not about learning new services. It is about reinforcing what you know, identifying your weak spots, and building the exam-taking muscle memory that separates a passing score from a confident one.

Your target: **Score 800+ on practice exams** (passing is 720 out of 1000).

---

## Phase Overview

| Attribute | Detail |
|---|---|
| **Duration** | 2 weeks (Weeks 11-12) |
| **Daily Study Time** | 2-3 hours minimum |
| **Total Estimated Hours** | 28-42 hours |
| **Goal** | Consistently score 80%+ on full practice exams |
| **Focus** | Practice exams, targeted review, exam strategy |

---

## Learning Objectives

By the end of this phase, you will be able to:

1. **Complete a full 65-question practice exam in under 130 minutes** with at least 80% accuracy
2. **Identify the correct AWS service from scenario keywords** without hesitation
3. **Distinguish between commonly confused services** (SQS vs Kinesis, SG vs NACL, etc.)
4. **Apply elimination strategy** to narrow answers from 4 to 2 in under 30 seconds
5. **Recognize distractor answers** that sound correct but violate AWS best practices
6. **Articulate WHY an answer is wrong**, not just which answer is right
7. **Map exam keywords to services**: "cost-effective" means Spot/Reserved, "decouple" means SQS, "real-time" means Kinesis, etc.
8. **Handle multi-service architecture questions** that span compute, storage, networking, and security

---

## Two-Week Strategy

### Week 11: Diagnose and Strengthen

| Day | Activity | Time |
|---|---|---|
| Day 1 | Take Practice Exam 1 (untimed, open book) | 3 hours |
| Day 2 | Review every wrong answer from Exam 1. Read explanations. Note weak domains. | 2 hours |
| Day 3 | Study Domain 1 (Secure Architectures) review guide + commonly confused services | 2.5 hours |
| Day 4 | Study Domain 2 (Resilient Architectures) review guide | 2.5 hours |
| Day 5 | Study Domain 3 (High-Performing Architectures) review guide | 2.5 hours |
| Day 6 | Study Domain 4 (Cost-Optimized Architectures) review guide | 2.5 hours |
| Day 7 | Take Practice Exam 2 (timed — 130 minutes, closed book) | 3 hours |

### Week 12: Sharpen and Execute

| Day | Activity | Time |
|---|---|---|
| Day 8 | Review every wrong answer from Exam 2. Compare with Exam 1 mistakes. | 2 hours |
| Day 9 | Deep-dive into your weakest domain. Redo questions you got wrong. | 2.5 hours |
| Day 10 | Study the ultimate cheat sheet + service limits + keyword matrix | 2.5 hours |
| Day 11 | Take Practice Exam 3 (timed, closed book — this is your hardest exam) | 3 hours |
| Day 12 | Review Exam 3 wrong answers. Study port numbers and protocols. | 2 hours |
| Day 13 | Light review: skim cheat sheet, keyword matrix, commonly confused services | 1.5 hours |
| Day 14 (Exam Day) | Read the last-minute review (30 min). Take the exam. | 0.5 hours + exam |

---

## Score Tracking

Use this table to track your progress across practice exams:

| Exam | Date | Score | Domain 1 | Domain 2 | Domain 3 | Domain 4 | Weakest Area |
|---|---|---|---|---|---|---|---|
| Practice Exam 1 | _____ | ___/65 | ___/20 | ___/17 | ___/16 | ___/12 | ____________ |
| Practice Exam 2 | _____ | ___/65 | ___/20 | ___/17 | ___/16 | ___/12 | ____________ |
| Practice Exam 3 | _____ | ___/65 | ___/20 | ___/17 | ___/16 | ___/12 | ____________ |

**Interpreting your scores:**
- **Below 60% (< 39/65):** You need more foundational study. Go back to the review guides for your weakest domains.
- **60-70% (39-45/65):** You are close but have gaps. Focus on commonly confused services and the keyword matrix.
- **70-80% (46-52/65):** You are in the passing range but need to sharpen up. Focus on elimination strategy and tricky scenarios.
- **80%+ (53+/65):** You are ready. Do a light review and take the real exam with confidence.

---

## What Is in This Phase

### Practice Exams (`practice-exams/`)
- **Practice Exam 1** — Balanced coverage, moderate difficulty. Take open-book first.
- **Practice Exam 2** — Focus on commonly confused topics. Take timed.
- **Practice Exam 3** — Hardest exam. Multi-service scenarios and tricky wording. Take timed.

### Review Guides (`review-guides/`)
- Domain 1: Secure Architectures (30% of exam)
- Domain 2: Resilient Architectures (26% of exam)
- Domain 3: High-Performing Architectures (24% of exam)
- Domain 4: Cost-Optimized Architectures (20% of exam)
- Commonly Confused Services — side-by-side comparisons

### Final Cheat Sheets (`final-cheat-sheets/`)
- Ultimate Cheat Sheet — the "night before the exam" document
- Service Limits and Numbers — critical numbers to memorize
- Port Numbers and Protocols — for security group / NACL questions

### Exam Strategies (`exam-strategies/`)
- Exam Day Guide — logistics, time management, elimination techniques
- Keyword Decision Matrix — exam keywords mapped to correct services
- Last-Minute Review — 30-minute rapid review of the top 50 facts

---

## Rules for This Phase

1. **Do NOT look at answers until you have attempted every question.** The struggle is where learning happens.
2. **Review EVERY wrong answer.** Do not just check if you passed — understand why each wrong answer is wrong.
3. **Track patterns in your mistakes.** If you keep confusing SQS and Kinesis, that is a signal to study the comparison deeply.
4. **Simulate exam conditions.** For Exams 2 and 3, set a timer for 130 minutes. No notes. No phone. No breaks.
5. **Trust the process.** If you have worked through Phases 1-5 and followed this review plan, you are ready.

---

## After the Exam

When you pass (and you will), consider:
- Sharing your experience to help others
- Moving on to AWS Solutions Architect Professional (SAP-C02)
- Getting hands-on with real AWS projects to reinforce what you learned
- Exploring other AWS certifications: Developer Associate, SysOps Administrator

Good luck. You have put in the work. Now go prove it.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The Final Push — Putting It All Together
- Two-Week Strategy
- Score Tracking
- What Is in This Phase

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
