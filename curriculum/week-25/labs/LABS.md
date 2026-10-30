# Week 25 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (25.2 to 25.5). Read a lab's figure
> before you start it; redraw it after.

---

# Lab 1 — The Eight STAR Stories (Tue, 6h)

Template: `_shared/templates/STAR-story-template.md`. **90 seconds each. Time yourself.**

## The eight, and where yours come from

| # | Prompt | Your source |
|---|---|---|
| 1 | A hard bug you found and fixed | BF-51 (unfixable CVE triage), BF-56 (Prometheus OOM), any long incident-journal entry |
| 2 | A technical trade-off, and what you gave up | Backstage vs build · directories vs workspaces · Actions vs Crossplane |
| 3 | A security issue you caught | The CVE that blocked the Bravo pipeline · a leaked secret gitleaks found |
| 4 | A performance problem you measured and fixed | Image 1.02 GB → 155 MB · build 62s → 4s via layer ordering |
| 5 | Something that broke in production-like conditions | The three week-21 incidents |
| 6 | Learning something unfamiliar, fast | Rego · IRSA · OPA · whatever genuinely took three attempts |
| 7 | Working with someone / a disagreement | Code review, the stranger test, a study-group design argument |
| 8 | **A mistake you made and what changed** | **BF-52 — the Kyverno lockout.** Use this one. |

## Why #8 should be the Kyverno lockout

It's asked in nearly every loop, and this story is unusually good for it:
- **Self-inflicted** — no blaming circumstances
- **Technically interesting** — admission webhooks, failure policies, system namespaces
- **Clearly diagnosed** — you found it through events, not guessing
- **The lesson is concrete and transferable** — audit mode first, exclude system namespaces, know
  your `failurePolicy`
- **It generalizes** — the same rollout discipline applies to NetworkPolicies, PSS, and Conftest

## The three depths — practice all of them

| Depth | When | Content |
|---|---|---|
| **30 sec** | Phone screen, or a first pass | Situation + result only |
| **90 sec** | The standard answer | Full STAR |
| **5 min** | They asked a follow-up | Architecture, alternatives, second-order effects |

**The most common failure is someone who built something real and cannot describe it in under four
minutes.** Practice the transitions, not just the content.

## The numbers to have memorized

Interviewers respond to specifics, and every one of these is measurable from your projects:

- Image size before and after hardening
- CVE count before and after
- Deploy time; PR-open → production
- ASG recovery time after termination
- RDS failover duration
- Monthly cost, dev and prod
- Time for a new service on Charlie: PR → live
- Your four DORA metrics
- Stranger-test time

**"My deploy takes 4 minutes 20 and the bottleneck is the AMI package install, which I'd fix with a
pre-baked image"** is a completely different answer from "it deploys automatically."

---

# Lab 2 — System Design (Wed, 6h)

Full worked answers: [`../../_shared/interview-bank/04-system-design.md`](../../_shared/interview-bank/04-system-design.md)

## The method — use it every time

```
1. CLARIFY      (3 min)  Scale? Users? Constraints? Compliance? What does done mean?
                         NEVER start drawing first. That's the #1 failure.
2. REQUIREMENTS (2 min)  Functional + non-functional. Write them where they can see.
3. HIGH LEVEL   (10 min) Boxes and arrows. Happy path, end to end.
4. DEEP DIVE    (15 min) Let them pick, or pick the riskiest part yourself.
5. FAILURE      (5 min)  "What happens when X dies?" Ask it about your OWN design first.
6. TRADE-OFFS   (5 min)  What you chose, what you gave up, what changes at 10x.
```

## The three scenarios — 45 minutes each, out loud, recorded

1. **Design a CI/CD platform for 50 engineers**
2. **Design a multi-account AWS landing zone**
3. **Design a Kubernetes platform for 20 teams**

You have built versions of all three. **Use your own designs as the backbone** and say so — *"I built
something like this; here's what I'd do differently at that scale"* is a strong frame.

## Two rules

**Say the trade-off out loud.** *"I'm choosing X, which costs more but gives us Y — if budget were the
binding constraint I'd go the other way."* Interviewers are listening for whether you know a
trade-off exists. A design presented as having no downsides reads as inexperience.

**Ask the failure question before they do.** *"What happens if the registry is unavailable?"* asked by
you is worth far more than the same question asked by them.

## Record and review

Watch one back. Count: silences over five seconds · times you said "um" · times you drew before
clarifying · times you asserted without naming the trade-off.

---

# Lab 3 — Live Exercises (Thu, 5h)

## Bash under time pressure (45 min)
From `_shared/drills/bash-oneliners.md`. Have someone give you five tasks; 5 minutes each; narrate.

## Python + boto3 (60 min)
```
"Write a script that finds all EBS volumes not attached to an instance,
 across all regions, and reports their total monthly cost."
```
30 minutes. **Narrate.** They're watching how you handle pagination, errors, and not knowing an API
name — not whether you memorized boto3.

## Terraform from blank (60 min)
```
"Write a module that creates an S3 bucket with versioning, encryption,
 public access blocked, and a lifecycle policy. Include variables with
 validation and outputs."
```
30 minutes, no reference. `_shared/drills/terraform-recall.md` is the practice.

## Broken Kubernetes (90 min)
Run `break.sh` from week 15 five more times. **Under 15 minutes each, narrating.** This is the most
likely live technical exercise for a DevOps role and you have rehearsed it since week 17.

## The meta-skill

**Narrate constantly. Say what you expect before you run it.** *"I'm going to check the endpoints
first, because if there are none it's a selector problem and that bisects the search space."*

**"I don't know, but here's how I'd find out" is a passing answer. Silence is not.** Practice saying
it without apology — it's a normal engineering sentence, not a confession.

---

# Lab 4 — Mock Interviews (Fri–Sat, 8h)

## Six mocks, at least three with real engineers

**Where to find people:** Pramp and interviewing.io (free peer mocks) · a study partner · someone
from a Discord or Slack community · anyone from your week-14 networking who offered to help ·
r/cscareerquestions mock threads.

## The six

| # | Type | Focus |
|---|---|---|
| 1 | Recruiter screen | 20 min. Motivation, the experience question, salary. |
| 2 | Technical screen | 45 min. Fundamentals + a project deep dive. |
| 3 | Troubleshooting | 45 min. Broken cluster, narrated. |
| 4 | System design | 45 min. One of the three. |
| 5 | Behavioral | 45 min. STAR, all eight prompts. |
| 6 | Full loop simulation | 90 min. All of it, back to back. |

**Record every one.** Watch them back. It is uncomfortable and it is the highest-return three hours
of the week.

## What to fix, in priority order
1. **Silences over five seconds** → narrate
2. **Rambling past 2 minutes** on a STAR story → you haven't practiced the 90-second version
3. **No numbers** → memorize the nine from Lab 1
4. **No trade-offs named** → say "the tradeoff is" out loud in every design answer
5. Filler words → slow down; a pause is better than "um"
6. Trailing off → end your answers deliberately: *"...so that's the approach I'd take."*

## The experience question — rehearse it until it's easy

> *"You don't have professional experience in this."*

```
"That's right -- I don't have paid experience yet. What I do have is six months
 of full-time focused work and three systems I built and operate.

 The one I'd point at is [Charlie] -- a developer adds a config file, opens a PR,
 and gets a running service with a pipeline, a dashboard, and alerts in under ten
 minutes. I watched three people who'd never seen it deploy a service using only
 the README, and fixed eleven things based on where they got stuck.

 I learn fast and I document what I learn -- that's the twelve blog posts.
 Realistically I'd expect to be productive on well-defined work quickly, and to
 need support on production incidents for the first few months."
```

Direct acknowledgment, concrete evidence, an honest read on your ramp. **The two answers that lose
the room are defensiveness and pretending the gap isn't there.**

Full bank: [`../../_shared/interview-bank/05-behavioral.md`](../../_shared/interview-bank/05-behavioral.md)
