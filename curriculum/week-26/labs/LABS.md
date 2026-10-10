# Week 26 Activities

---

# 1 — The Application Engine (Mon, 8h)

## The weekly numbers, from here on

| Activity | Hours |
|---|---|
| Applications + follow-up (20–25 quality) | 8 |
| Networking — 5 conversations, 1 event | 4 |
| Interview prep, tailored per company | 6 |
| **Continued building** | 10 |
| One blog post | 3 |
| CKA prep, if not already done | 8 |

## "Quality" means

- [ ] The résumé is tailored to **that posting's keywords** (ATS matching is literal)
- [ ] You identified a **human** at the company and contacted them where possible
- [ ] Your cover note, if any, names something specific about the company
- [ ] Logged in the tracker with the source and date

**15 tailored applications beat 100 one-click ones.** The one-click flood is what most candidates do
instead of the work that converts.

## Follow-up discipline

| When | Action |
|---|---|
| No response after 7 days | A short, polite follow-up to the recruiter or hiring manager |
| After any interview | Thank-you within 24 hours, referencing something specific |
| After a rejection | **Ask what would have made you a stronger candidate.** Some answer, and the answer is worth more than the application. |
| 30 days after a rejection | Reconnect if a new role opens — you're a known quantity now |

## Reading the funnel

```
Applications sent:        ____
Recruiter screens:        ____   (expect 2-5% cold, 20-40% referred)
Technical screens:        ____   (40-60% of screens)
Onsites:                  ____   (30-50% of technicals)
Offers:                   ____   (20-40% of onsites)
```

**Diagnose by where it stops:**

| Stalls at | The problem is | The fix |
|---|---|---|
| **Applications → screens** | Résumé or targeting, **not skill** | Rewrite the résumé; shift target roles; go hard at referrals |
| Screens → technical | Communication, or the experience question | The week-25 answer, rehearsed |
| Technical → onsite | A specific knowledge gap | The rejection reasons tell you which |
| Onsite → offer | Depth, or fit | More mocks; ask for feedback |

**100+ applications with zero screens is an upstream problem.** More studying will not fix it, and
it's the single most common way people waste month 7.

---

# 2 — Interview Execution (Tue, Thu)

## Per-company prep — 45 minutes each, non-negotiable

- [ ] What they do, and who their customers are
- [ ] Their engineering blog — read two posts
- [ ] Their stack (job posting, blog, their GitHub, StackShare)
- [ ] Their recent news — funding, launches, layoffs
- [ ] **Three specific questions** you could only ask having done this
- [ ] Which of your projects is most relevant, and why

**A candidate who read the engineering blog is instantly distinguishable.** It takes 20 minutes and
almost nobody does it.

## The questions that tell YOU something

Ask these — they're how you avoid a bad job:

- **"How often do you deploy, and how long does a deploy take?"** — the single most diagnostic
  question about engineering maturity
- **"What does on-call look like? How often does someone get paged at night?"**
- "What happened in your last significant incident, and what changed afterward?"
- "How much of the team's time goes to unplanned work?"
- "Who would I be learning from day to day?"

## After every interview, within an hour

Write down: every question asked · your answer · what you'd say differently · anything you couldn't
answer.

**That document is your study plan.** After ten interviews the pattern is unmistakable.

---

# 3 — Networking (Fri, 4h)

**Referrals convert 5–10× cold applications.** This is where the highest-leverage hours are.

- 5 genuine conversations
- 1 event — meetup, community day, or an online one
- Follow up with everyone from previous weeks
- Ask for a referral **only** where a real relationship exists

```
Hi [name] -- I saw [company] posted a [role]. Based on our conversation about
[specific thing], it looks like a strong fit for what I've been building.

Would you be comfortable referring me? Totally fine if not -- I know referrals
carry your name. Résumé attached either way.
```

**The explicit permission to decline is what makes it askable.** It protects the relationship
whichever way they answer.

## Where to find people
Local AWS User Groups, Kubernetes/CNCF community days, DevOps Days · community Slack and Discord
servers (answer questions rather than asking) · LinkedIn, engaging genuinely before ever messaging ·
alumni networks · open source — a small merged PR earns a real relationship.

---

# 4 — Keep Building (Sat)

**Pick the thing your interviews exposed.** Ideas, roughly ordered by interview value:

| Add | Why |
|---|---|
| Progressive delivery to Charlie (Argo Rollouts canary) | The #1 follow-up question after "how do you deploy?" |
| A FinOps dashboard — cost per service, per team | Almost no junior candidate has anything on cost |
| Multi-cluster ArgoCD | Comes up whenever you mention GitOps |
| A Backstage plugin | If your target companies run it |
| A Crossplane version of Charlie's provisioning | Shows you evaluated the alternative |
| Chaos experiments as scheduled jobs | Resilience thinking, demonstrated |
| A Go rewrite of the platform CLI | If platform roles keep asking about Go |

**Every commit during your job search is visible on your profile**, and a project that gained features
while you were interviewing reads better than one static since week 24.

---

# 5 — The Retrospective and the Plan (Sun)

See [assessment.md](../assessment.md). **Write the weeks 27+ plan down.** A search without a written
cadence drifts, and drift is what turns a three-month search into a nine-month one.
