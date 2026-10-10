# ★ GATE 5 — Project Bravo

> **A gate, not a quiz.** Two things must be demonstrated live.

---

## The gate

### 1. The pipeline blocks a critical CVE — demonstrated live
```bash
echo "requests==2.19.1" >> app/requirements.txt
git commit -am "test: introduce CVE-2018-18074" && git push
```
- [ ] CI fails at the scan step
- [ ] The CVE ID appears in the output
- [ ] Screenshot in `evidence/cve-blocked-build.png`

### 2. An unsigned image is refused — demonstrated live
```bash
kubectl -n shop run test --image=$REGISTRY/bravo-app:unsigned
```
- [ ] Admission denies it with "no matching signatures"
- [ ] Screenshot in `evidence/unsigned-image-rejected.png`

### 3. Written from scratch, no reference
- [ ] A PromQL query computing p99 latency correctly aggregated across instances
- [ ] An SLO with its error budget computed by hand, and a burn-rate alert

### 4. Project Bravo acceptance criteria
- [ ] A privileged pod is rejected by Pod Security Standards
- [ ] A NetworkPolicy-blocked connection demonstrated (**on a CNI that enforces them**)
- [ ] SBOM generated, attached, and queryable
- [ ] Images signed; verification **enforced**, not advisory
- [ ] A Git manifest change syncs to the cluster within 3 minutes
- [ ] A manual cluster change is reverted by ArgoCD
- [ ] Image CVE count documented before and after hardening
- [ ] STRIDE threat model written up
- [ ] **Control narrative table: threat → control → evidence**
- [ ] Falco alerts on a shell spawned in a container
- [ ] Three postmortems written
- [ ] Demo video recorded

---

## Part A — Written (20 min, closed book)

1. Name the four incident roles. Why does the Incident Commander not debug?
2. Mitigate first or diagnose first? Give the reason and the one exception.
3. What two numbers do you actually improve in incident response?
4. What does "blameless" mean, and give the **engineering** argument for it — not the moral one.
5. Name the postmortem section most people skip, and why it matters.
6. What three things must every action item have, and why?
7. What does classifying actions as Prevent/Detect/Mitigate reveal?
8. What is a chaos experiment, and what distinguishes it from "breaking things randomly"?
9. Name the four DORA metrics. Why are your personal-project numbers easy?
10. Why is gradual degradation harder to detect than a hard failure, and which golden signal
    addresses it?
11. What makes a runbook useful rather than decorative?
12. Your app restarts every time the database blips. What's wrong?

---

# Answer key

**A1.** **Incident Commander** (coordination and decisions), **Operations lead** (makes changes),
**Communications lead** (stakeholders, status page), **Scribe** (timeline). The IC doesn't debug
because if the coordinator is head-down in a terminal, nobody is tracking who's doing what, nobody is
talking to stakeholders, and two people make conflicting changes. **Separating coordination from
execution is the core insight.**

**A2.** **Mitigate first.** A clean rollback beats a clever fix during an incident; the postmortem is
where you understand it. **The exception:** if you don't understand the failure, rolling back can
make it worse — a forward-incompatible migration means old code against a new schema.

**A3.** **Detection time** (incident start → you knew) and **time to mitigate** (you knew → user
impact ended). Root-cause time matters less, because mitigation ends the impact.

**A4.** Describe systems and decisions, never individual competence. **The engineering argument:**
blame teaches people to hide information, and hidden information makes the next incident worse. It's
not about being nice — it's that a culture of blame destroys your incident data.

**A5.** **"Where we got lucky."** *"It happened at 2pm, not 2am." "Only one AZ was affected."* Luck is
a finding: it means the same event could be far worse next time, and it converts directly into action
items.

**A6.** An **owner**, a **due date**, and a **ticket**. Without all three they do not happen — an
action item with no owner is nobody's problem and one with no date is never overdue.

**A7.** Whether you have a plan for **unknown** failures. If every action is "Prevent," you're only
defending against this specific bug recurring. Detect and Mitigate actions improve how you handle the
next failure you haven't imagined.

**A8.** A **hypothesis about resilience, tested** — "if I kill a pod, the PDB and remaining replicas
absorb it and error rate stays under 0.1%." Random breakage has no hypothesis, so it teaches nothing
and can't fail informatively. **If you're never surprised, you're testing what you already know.**

**A9.** Deployment frequency · lead time for changes · change failure rate · time to restore.
**Your numbers are easy** because a one-engineer project deploys on demand with a short lead time
almost by construction. The hard problem at real scale is keeping change failure rate low *as*
deployment frequency rises — which is what test gates and progressive delivery are for. Saying that
is more impressive than the numbers.

**A10.** Because error-rate thresholds are crossed **late** — the rate climbs gradually and only
trips the alert near the end. **Saturation** is the golden signal that catches it: pool utilization,
disk free, queue depth all trend long before anything fails. `predict_linear` on a saturation metric
alerts hours ahead.

**A11.** It's written for **someone woken at 3am who has never seen the system**: exact commands,
explicit decision points with defaults, an escalation path, and — critically — **it has been
executed**. A runbook that has never been run during a game day is fiction.

**A12.** **The liveness probe is checking the database.** Dependency checks belong in **readiness**,
where failing removes the pod from rotation without restarting it — so it recovers the moment the
database does. In liveness, a blip restarts every replica at once and the reconnection storm extends
the outage. (BF-44.)

---

## ★ Gate 5 result

| | |
|---|---|
| **PASS** — both demonstrations live, Bravo criteria met, Part A 10+/12 | **Ship it. Move to week 22.** |
| **NEAR** — demonstrations work, docs incomplete | Finish the docs this weekend. **Do not delay week 22** — Charlie needs all four weeks. |
| **FAIL** — a demonstration doesn't work | Fix it before week 22. **The demonstrations are the project**; the documentation is presentation of it. |

---

## Month 5 retrospective (Sunday)

1. **Applications sent in weeks 18–21.** Cumulative since week 14 — target was 80–120.
2. **Screens and interviews.** At 2–5% cold conversion, 2–5 screens from 100 applications is
   *expected*. Zero after 120 means the problem is upstream: résumé, targeting, or no referrals.
3. **What did any rejections tell you?** Track the reasons. After ten interviews the pattern is
   unmistakable and it should be driving your study.
4. Top 3 "Surprised" lines from the incident journal.
5. **Is Bravo genuinely shippable, or 80% done?** Be honest. 80% done in week 21 becomes 80% done in
   week 26.
6. **Rest days.** You are 21 weeks in. This is where it matters most.

## Looking ahead — week 22 is a shift

Month 6 changes character. The technical work becomes **Project Charlie**, and the second half of the
month is **conversion** — interviewing becomes the primary activity at ~20 hrs/week.

Read [`../../JOB-SEARCH.md`](../../JOB-SEARCH.md) §6 this weekend. If your pipeline is thin, week 22
is the last comfortable moment to fix targeting or go hard at referrals.
