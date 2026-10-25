# Week 21 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (21.2 to 21.5). Read a lab's figure
> before you start it; redraw it after.

---

# Lab 1 — Incident Response (2h)

## The roles — know them even if you're one person

| Role | Owns |
|---|---|
| **Incident Commander** | Coordination and decisions. **Does not debug.** Their job is to keep the response organized. |
| **Operations lead** | Actually making changes to the system |
| **Communications lead** | Status page, stakeholders, the incident channel |
| **Scribe** | The timeline — timestamps of every action and finding |

**The IC not debugging is the counter-intuitive part.** The instinct in a crisis is for the most
senior person to dive into the terminal. That leaves nobody tracking who's doing what, nobody talking
to stakeholders, and two people making conflicting changes. Separating coordination from execution is
the single most valuable thing incident management teaches.

## Severity levels

| Sev | Meaning | Response |
|---|---|---|
| **SEV1** | Complete outage, or data loss | Page immediately, all hands, exec comms |
| **SEV2** | Major degradation, significant user impact | Page, dedicated responder |
| **SEV3** | Minor degradation, workaround exists | Business hours |
| **SEV4** | No user impact; needs attention | Ticket |

**Declare early and downgrade.** Under-declaring wastes the time when action is cheapest;
over-declaring costs one apologetic message.

## Mitigate first, diagnose second

**Stop the bleeding before finding the cause.** A clean rollback beats a clever fix during an
incident. The postmortem is where you understand it; the incident is where you end it.

```bash
kubectl rollout undo deploy/app -n shop        # 30 seconds
# vs
# "let me just check the logs..."              # 40 minutes of user impact
```

The exception: if you don't understand the failure, a rollback might make it worse (a forward-
incompatible migration). Knowing *when* rollback is unsafe is the nuance.

## The on-call model
- **Primary** and **secondary**, with explicit escalation timing
- A **handoff** document at shift change — what's ongoing, what's fragile
- Follow-the-sun beats night shifts where headcount allows
- **Compensation for being on call.** If it's unpaid, the rota quietly becomes "whoever is most
  conscientious," and that person burns out.

---

# Lab 2 — Run Three Real Incidents (4h) — the point of the week

**Get a partner if at all possible.** They break something without telling you. Failing that, write
five break scripts, shuffle them, and run one after a 30-minute gap.

## The protocol, for each incident

```
1. DETECT     Note the time you found out. Was it an ALERT or a user?
              (If it was a user, that's finding #1 in the postmortem.)
2. DECLARE    Severity. Open a channel. Start the timeline.
3. MITIGATE   Stop the bleeding. Note the time.
4. DIAGNOSE   Root cause. Note the time.
5. RESOLVE    Confirm recovery with a metric, not a feeling.
6. POSTMORTEM Within 24 hours, while it's fresh.
```

**Time every phase.** Detection time and time-to-mitigate are the two numbers you actually improve,
and they're the numbers to quote in an interview.

## Three incidents to run

| # | Inject | Expected detection |
|---|---|---|
| 1 | Deploy an image with a deliberate 500 on 30% of requests | The fast-burn alert from week 20 |
| 2 | `kubectl scale deploy/db --replicas=0` | The no-healthy-hosts alert, then readiness failures |
| 3 | Fill the database disk, or exhaust its connection pool | Slow, then failing — the hardest to detect |

**#3 is the valuable one.** Gradual degradation is much harder to detect than a hard failure, and
"our alerting only catches binary failures" is a genuine finding.

## Write three postmortems

`_shared/templates/POSTMORTEM-template.md`. Every section, including the two people skip:

**"What went well"** — genuinely. Morale is part of reliability, and a postmortem that is only
criticism trains people to avoid writing them.

**"Where we got lucky"** — the most under-used section in the industry. *"It happened at 2pm, not
2am." "Only one AZ was affected." "The engineer who knew this system happened to be online."* **Luck
is a finding.** It means the same event could be much worse next time, and it converts directly into
action items.

## Blameless means blameless

> **Describe systems and decisions, never individual competence.**

| Not this | This |
|---|---|
| "Alex deployed without testing" | "The pipeline allowed a deploy without an integration test, and the test suite takes 40 minutes, so people skip it" |
| "We should be more careful" | "Add a required status check; cut the suite to 8 minutes so skipping isn't tempting" |

**Blame is not a moral position — it's an engineering one.** Blame teaches people to hide
information, and hidden information makes the next incident worse. That framing is the right answer
when asked about postmortem culture.

## Every action item needs three things

| # | Action | Type | Owner | Due | Ticket |
|---|---|---|---|---|---|
| 1 | Alert on connection-pool saturation | Detect | | | #123 |
| 2 | Load-test the release candidate in CI | Prevent | | | #124 |
| 3 | Update the rollback runbook | Mitigate | | | #125 |

**Owner, due date, ticket.** Actions without all three do not happen. And classify each as
**Prevent / Detect / Mitigate** — if every action is "Prevent," you have no plan for the next unknown
failure, which is a real gap.

---

# Lab 3 — Runbooks, Chaos, DORA (3h)

## Runbooks

One per alert. `_shared/templates/RUNBOOK-template.md`. Written for **someone woken at 3am who has
never seen the system**.

```bash
kubectl get prometheusrule -A -o json | \
  jq -r '.items[].spec.groups[].rules[] | select(.alert) |
         select(.annotations.runbook_url == null) | .alert'
```
**Any alert without a runbook is either not important enough to page on, or a gap.** That one query
is a useful audit.

**A runbook that has never been executed is fiction.** Run each one during a game day, and fix every
step that was wrong.

## Chaos engineering

Start small, in non-production, with a **hypothesis**:

> *"If I kill one app pod, the PodDisruptionBudget and the remaining replicas absorb it and error
> rate stays under 0.1%."*

Then test it.

```bash
kubectl -n shop delete pod -l app=app --field-selector status.phase=Running \
  --wait=false -o name | head -1
kubectl drain "$(kubectl get nodes -o name | tail -1 | cut -d/ -f2)" \
  --ignore-daemonsets --delete-emptydir-data   # then uncordon it when the experiment is over
kubectl -n shop exec deploy/app -- sh -c 'kill 1'
```

| Experiment | Hypothesis to test |
|---|---|
| Kill a pod | PDB + replicas absorb it; error rate stays flat |
| Drain a node | PDB prevents simultaneous eviction |
| Kill the database | Readiness fails, pods leave rotation, **no restart storm** (tests BF-44's lesson) |
| Add 200ms latency to the DB | p99 degrades gracefully, no timeouts cascade |
| Fill the disk | The `predict_linear` alert fires **before** it's full |

**Chaos engineering is not "break things randomly."** It is: state a hypothesis about resilience, test
it, and be surprised. If you aren't occasionally surprised, you're testing things you already know.

## DORA metrics — measure your own

| Metric | Your Alpha/Bravo pipelines |
|---|---|
| **Deployment frequency** | commits to main per week |
| **Lead time for changes** | commit → running in production |
| **Change failure rate** | % of deploys requiring a rollback or hotfix |
| **Mean time to restore** | from your three incidents |

```bash
gh run list --workflow=deploy.yml --json createdAt,conclusion,updatedAt --limit 50 | \
  jq -r '.[] | [.createdAt, .conclusion,
                ((.updatedAt|fromdate) - (.createdAt|fromdate))] | @tsv'
```

**Measure them for real and put the numbers in your README.** "My lead time is 6 minutes and my MTTR
across three simulated incidents averaged 11 minutes" is concrete and memorable. The DORA elite
thresholds (multiple deploys per day, <1 hour lead time, <15% change failure, <1 hour MTTR) give you
context for what the numbers mean.

---

# Lab 4 — ⚑ Project Bravo to Acceptance (Thu–Sat)

Full criteria: [`../../../PROJECTS.md`](../../../PROJECTS.md) §3.

## The demonstrations that matter

Everything else is presentation; these two **are** the project:

```bash
# 1. A CRITICAL CVE BLOCKS THE PIPELINE
echo "requests==2.19.1" >> app/requirements.txt
git commit -am "test: introduce CVE-2018-18074" && git push
#    -> CI fails at the Trivy step, naming the CVE
#    -> SCREENSHOT -> evidence/cve-blocked-build.png

# 2. AN UNSIGNED IMAGE IS REFUSED BY ADMISSION
docker pull nginx:alpine
docker tag nginx:alpine $REGISTRY/bravo-app:unsigned
docker push $REGISTRY/bravo-app:unsigned
kubectl -n shop run test --image=$REGISTRY/bravo-app:unsigned
#    -> admission webhook denies: "no matching signatures"
#    -> SCREENSHOT -> evidence/unsigned-image-rejected.png
```

## The rest of the evidence

- [ ] `evidence/gitleaks-blocked-commit.png`
- [ ] `evidence/privileged-pod-rejected.png` (Pod Security Standards)
- [ ] `evidence/netpol-blocked.txt` (a demonstrably blocked connection)
- [ ] `evidence/falco-shell-alert.json`
- [ ] `evidence/image-hardening.md` (before/after size and CVE table)
- [ ] `evidence/sbom-query.txt`
- [ ] `evidence/argocd-selfheal.png` (a manual change reverted)

## The documents

- [ ] `docs/threat-model.md` — STRIDE, per component
- [ ] `docs/control-narrative.md` — **threat → control → evidence**, the table from week 17
- [ ] `docs/compliance-mapping.md` — control → CIS / NIST / SOC 2 reference
- [ ] `docs/adr/` — at least four decisions
- [ ] `docs/runbooks/` — one per alert
- [ ] 3 postmortems from Lab 2
- [ ] README from the template, with **measured** numbers
- [ ] A 5-minute demo video

## The demo video script (5 minutes)

```
0:00  The problem. "Shipping a container to production involves trusting a lot
      of things. Here's how I made that trust verifiable."
0:30  Architecture diagram. The pipeline, left to right.
1:30  LIVE: introduce a vulnerable dependency, push, watch CI block it.
2:30  LIVE: try to deploy an unsigned image, watch admission refuse it.
3:30  LIVE: kubectl scale by hand, watch ArgoCD revert it.
4:00  The thing I got wrong: the Kyverno lockout. What I do differently now.
4:30  What I'd do next: policy exceptions as code, and tail-based trace sampling.
```

**Section 4:00 is not optional.** A demo with no mistakes reads as either trivial or rehearsed. The
lockout story is the most memorable thirty seconds in the video.
