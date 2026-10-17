# The Break/Fix Library

> 58 scenarios. Every Friday you break something, diagnose it under a timer, and log it.
> By week 26 you will have done this ~58 times, and "how would you debug X?" stops being scary.

## Why this exists

More junior candidates are rejected for freezing on *"how would you troubleshoot this?"* than for any
knowledge gap. Knowledge is easy to acquire and easy to demonstrate. **Diagnostic method under
pressure is neither** — and it is the thing the interviewer is actually measuring.

This library trains the method.

## How to use it

**Solo:** read only the `SYMPTOM` and `BREAK` sections. Run the break command. Close this file.
Diagnose. Open `DIAGNOSIS` only when you're done or stuck for 20 minutes.

**With a partner (better):** they run the break command without telling you which scenario it was.
This is much closer to real on-call and to an interview.

**Always:** narrate out loud while you work, as if an interviewer is listening. Silence is the
failure mode you are training away.

## The method (say this out loud, every time)

```
1. SYMPTOM     What exactly is broken? Who is affected? Since when?
2. CHANGE      What changed recently? (This resolves most real incidents.)
3. HYPOTHESIS  What do I think it is, and what is the CHEAPEST test that kills the idea?
4. LAYERS      app -> container -> pod -> node -> network -> cloud -> DNS
               Walk them in order. Don't skip to the exciting one.
5. CONFIRM     Prove the root cause. Don't stop at a correlation.
6. FIX         Smallest change that resolves it.
7. PREVENT     What makes this impossible, or at least loud, next time?
```

Saying *"I don't know, but here's how I'd find out"* is a **passing answer.** Silence is not.

## Logging (non-negotiable)

Every scenario gets an entry in `progress/incident-journal.md`:

```markdown
## BF-45 — Pod stuck Pending  (week 15, 11 min)
Symptom:    New deployment's pods never leave Pending.
Hypothesis: Resource pressure -- but nodes showed plenty free.
Confirmed:  `kubectl describe pod` -> "0/3 nodes available: 3 node(s) had untolerated taint"
Root cause: Node had a NoSchedule taint from an earlier lab; pod had no toleration.
Fix:        Added the toleration. (Alternative: remove the taint.)
Prevent:    Check `kubectl describe node | grep Taints` before blaming resources.
Surprised:  describe on the POD tells you about the NODE. Events are the whole game.
```

The **Surprised** line is the most valuable field in the whole program. It marks the edge of your
mental model, and by week 26 those lines are your best interview stories.

## Index

| File | Scenarios | Introduced |
|---|---|---|
| [01-linux.md](01-linux.md) | BF-01 – BF-10 | weeks 1–2 |
| [02-networking.md](02-networking.md) | BF-11 – BF-18 | weeks 2–3 |
| [03-containers.md](03-containers.md) | BF-19 – BF-24 | week 4 |
| [04-aws.md](04-aws.md) | BF-25 – BF-32 | weeks 5–9 |
| [05-terraform-cicd.md](05-terraform-cicd.md) | BF-33 – BF-40 | weeks 10–13 |
| [06-kubernetes.md](06-kubernetes.md) | BF-41 – BF-50 | weeks 14–17 |
| [07-security-observability.md](07-security-observability.md) | BF-51 – BF-58 | weeks 18–21 |

Scenarios are cumulative. Week 20's Friday should re-run two old scenarios plus two new ones —
spaced repetition applies to skills, not just facts.
