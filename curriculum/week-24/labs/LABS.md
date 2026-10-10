# Week 24 Labs

---

# Lab 1 — The Documentation Set (Mon–Tue, 6h)

## `docs/getting-started.md` — the five-minute path

Written for a developer on their first day. **No platform concepts, no Kubernetes, no Terraform.**

````markdown
# Ship your first service

1. Fork this repo and create a branch.
2. Create `services/my-first-api/service.yaml`:

   ```yaml
   apiVersion: platform.internal/v1
   kind: Service
   metadata:
     name: my-first-api
     owner: team-payments
   spec:
     language: python
     port: 8080
     tier: experimental
   ```

3. Open a pull request. A bot will comment with what will be created and what it costs.
4. Get one approval and merge.
5. In about 8 minutes you will get a comment with your URLs:
   - Repository: github.com/org/my-first-api  (already has working code)
   - Dashboard: grafana.internal/d/my-first-api
   - URL: my-first-api.internal

That's it. Your service is running, monitored, and has a pipeline.

**Next:** [add a database](adding-a-database.md) · [choose a tier](tiers.md) ·
[go off the paved road](escape-hatches.md)
````

**The test: can someone follow this without asking a question?**

## `docs/contract-reference.md`
Every field: what it does, whether it's required, what it defaults to, what it affects downstream,
and an example. Generate as much as you can from the JSON schema so it cannot drift.

## `docs/tiers.md`
The three tiers as a table: replicas, PDB, SLO, alerting, backup retention, **cost**, and when to
choose each. Written so a product manager can read it.

## `docs/escape-hatches.md` — the one people don't write

> **Going off the paved road is supported, not forbidden.**
>
> If you need Kafka, a GPU, a StatefulSet, or a custom networking topology, the platform doesn't
> support it — and that's fine. Talk to us in `#platform` and we'll help you build it directly.
> You'll own more of it, and you won't get the automatic dashboard, alerts, and pipeline updates.
>
> If several teams need the same thing, that's a signal we should pave it. Tell us.

**This document does more for adoption than any feature.** A platform that forbids exceptions creates
shadow infrastructure you don't know about; one that documents the exit makes exceptions visible and
tells you what to build next.

## `docs/adr/` — at minimum
- `0001-build-vs-backstage.md` (week 22)
- `0002-service-yaml-contract-design.md` — why tiers, why these required fields
- `0003-actions-terraform-not-crossplane.md`
- `0004-observability-is-not-optional.md`
- `0005-escape-hatches-are-supported.md`

## `docs/runbooks/`
Per generated alert, plus platform-specific ones: *provisioning failed halfway*, *a service is stuck
OutOfSync*, *how to manually deprovision*.

---

# Lab 2 — The Stranger Test (Wed, 4h) ★ This is Gate 6

> **Find someone who has never seen the repo.** A friend, a study partner, someone from a Discord
> server. Ideally a developer who is *not* an infrastructure person — that's your actual user.

## The protocol
1. Give them the repo URL and nothing else
2. **Start a timer**
3. **Say nothing.** Do not help. Do not explain. Do not answer questions — write them down.
4. Watch where they hesitate, re-read, scroll back, or open the wrong file
5. Stop at 15 minutes whether or not they finished

## What you are recording

| Observation | What it means |
|---|---|
| Re-read a section | Ambiguous wording |
| Scrolled back up | Poor information order |
| Opened a file the README didn't mention | Missing step |
| Asked a question | Missing documentation |
| Guessed a value | Missing example or a bad default |
| Got an error they couldn't act on | **A bad error message** |

**Every single one is a bug.** Fix all of them before Thursday.

## Then do it again

A second person, after the fixes. The second run should be faster and quieter. If it isn't, you fixed
the symptoms rather than the cause.

**This exercise is the entire difference between a repo and a platform.** It is also the thing that
lets you answer developer-experience questions from experience rather than from a blog post — and
that distinction is audible in an interview.

---

# Lab 3 — The Demo Video and README (Thu, 4h)

## The 5-minute video

```
0:00  THE PROBLEM. "At a company I've worked with, shipping a new service took
      3-5 days and two tickets. Here's what it looks like when it takes 8 minutes."
0:30  The developer's view: one YAML file, one PR. Show the file.
1:00  The PR comment: what will be created, and what it costs per month.
1:30  Merge. Then SPEED UP and narrate what's happening.
2:30  The result: repo scaffolded, service running, dashboard live, alert armed.
      Click through each. Show the dashboard with real data.
3:30  Architecture: how it works, in one diagram.
4:00  WHAT I GOT WRONG. The Kyverno lockout, or the orphaned load balancers.
      What I do differently now.
4:30  What I'd do next, and what I deliberately didn't build.
```

**Section 4:00 is not optional.** A flawless demo reads as either trivial or rehearsed. Thirty
seconds of "here's what I broke and what I learned" is the most memorable part of the video and the
thing an interviewer will ask about.

Record with OBS or Loom. **One take is fine** — polish is less convincing than fluency.

## The README

`_shared/templates/PROJECT-README-template.md`. Non-negotiable:

- [ ] Opens with **the problem**, not the tech list
- [ ] Demo video linked at the top
- [ ] Architecture diagram
- [ ] Quick start that actually works
- [ ] **Measured results:**

| Metric | Value |
|---|---|
| Time: PR merged → service running | |
| Time: `platform new-service` → PR open | |
| Manual steps required | **0** |
| Services with a dashboard and alerts | **100%** |
| Time for a stranger to deploy their first service | |

- [ ] Cost table per tier
- [ ] **"What broke"** — three genuine entries
- [ ] Key decisions table linking to ADRs

## Portfolio consolidation

- [ ] Alpha, Bravo, Charlie pinned on your GitHub profile
- [ ] Profile README with a one-line positioning statement and all three
- [ ] Each repo's README opens with its problem statement
- [ ] All three CI badges green
- [ ] Contribution graph shows all 24 weeks

---

# Lab 4 — KCSA Prep (Fri–Sun, if taking it)

The four domains and where you already covered them:

| Domain | Weeks | Reference |
|---|---|---|
| Overview of Cloud Native Security (the 4Cs) | 18, 19 | `_reference/devsecops/content-module-01`, `-03` |
| Kubernetes Cluster Component Security | 15, 16, 19 | `content-module-04-kubernetes-security.md` |
| Kubernetes Security Fundamentals (PSS, RBAC, secrets, NetworkPolicy) | 15, 19 | `_reference/kubernetes/03-production/02-security-rbac-*` |
| Platform Security (supply chain, admission, image security) | 18, 19 | `content-module-06`, `content-module-12` |
| Compliance and Security Frameworks | 19 | `content-module-08-compliance-frameworks.md` |

**Read the actual CNCF curriculum document**, not a course summary — it's the contract for what's
examinable, it's short, and people skip it.

**Two practice exams. Target 80%+.** It's multiple choice and lighter than SAA.

**The exam is Monday of week 25.** If you're not at 80% by Sunday, **move it** — week 25 is for
interview preparation, and a cert you scramble for is worth less than a week of mock interviews.
