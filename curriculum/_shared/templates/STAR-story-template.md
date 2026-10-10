# STAR Story: <Two-word label, e.g. "Cluster Lockout">

**Use for:** "tell me about a time you made a mistake" / "a hard bug" / "a security find"
**Source:** incident-journal BF-<NN> · project <alpha|bravo|charlie>
**Length target:** 90 seconds spoken. Time yourself.

## Situation (15 sec)
Where, what system, what was at stake. **One or two sentences.** Most people spend 3 minutes here
and lose the room before reaching the point.

## Task (10 sec)
What specifically was yours to solve.

## Action (45 sec — the heart of it)
What **you** did, in order, with the reasoning visible.
- Say "I" not "we." Interviewers need to know your contribution.
- Include the **decision points**: what you considered and rejected.
- Name real tools and real commands. Specificity is what makes it believable.

## Result (20 sec)
- **A number.** Deploy time, CVE count, minutes of downtime, cost saved.
- What you'd do differently now. (This is what separates a good answer from a great one.)

---

## The three-depth rule

| Depth | When | Content |
|---|---|---|
| **30 sec** | First pass, or a phone screen | Situation + result only |
| **90 sec** | The standard answer | Full STAR |
| **5 min** | They asked a follow-up | Add the architecture, the alternatives, the second-order effects |

Practice all three. The most common failure is someone who built something real and cannot describe
it in under four minutes.

## Stories to have ready by week 25

1. A hard bug you found and fixed
2. A technical trade-off you made, and what you gave up
3. A security issue you caught
4. A performance problem you measured and improved
5. Something that broke in production-like conditions
6. Learning something unfamiliar, fast
7. Working with someone / handling disagreement
8. **A mistake you made and what changed as a result**

#8 is asked in nearly every loop. BF-52 (locking yourself out of your own cluster with an admission
policy) is a genuinely good source for it: self-inflicted, technically interesting, and the lesson —
audit mode first, exclude system namespaces — is concrete.
