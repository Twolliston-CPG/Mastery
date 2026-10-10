# Week 25 Solutions

Full model answers: [`../../_shared/interview-bank/`](../../_shared/interview-bank/)

---

## A worked STAR story — #8, the mistake

**Weak version (what most people say):**
> "I made a mistake with a Kubernetes policy once and it caused some problems, but I learned to be
> more careful about testing changes before applying them."

No specifics, no diagnosis, and the lesson is unactionable. This answer is forgotten in a minute.

**Strong version (90 seconds):**

> **S:** I was building the security layer for my Kubernetes delivery project and wanted to enforce
> that every pod declares resource limits, so one workload can't starve a node.
>
> **T:** Write and roll out a Kyverno admission policy.
>
> **A:** I wrote it, set `validationFailureAction: Enforce`, and applied it cluster-wide. Within a
> minute nothing could deploy — including `kube-system` DaemonSets, because the vendor manifests
> don't set limits. The CNI pods couldn't be recreated, so the cluster was one node restart away from
> having no networking at all.
>
> I found it with `kubectl get events -A --field-selector reason=PolicyViolation`, which showed
> system components being rejected. First I stopped the bleeding by patching the policy to `Audit`.
> Then I rewrote it excluding system namespaces and rolled it out in Audit mode for a day first, so I
> could see what it *would* have blocked before it blocked anything.
>
> **R:** It's been enforcing since with no false positives. And I have a rule now: every admission
> policy goes out in audit mode first, always excludes system namespaces, and I check the
> `failurePolicy` — because a webhook with `failurePolicy: Fail` that becomes unavailable blocks
> every write to the cluster. That's a total outage caused by a security control, which is worse than
> the risk it was mitigating.

**Why it works:** specific and technical, shows a diagnostic method (events, not guessing), shows
mitigation before root-causing, and the lesson is a **transferable rule** rather than "be careful."
The final sentence also demonstrates you think about second-order effects.

**It also answers three other prompts:** "something that broke," "a time you learned something," and
"a time you had to make a decision under pressure."

---

## System design — the failures to avoid

| Failure | Fix |
|---|---|
| **Drawing before clarifying** | Three minutes of questions first, every time. It is the most common failure. |
| Going deep on the part you know | Cover the whole system, then let *them* pick the deep dive |
| Presenting a design with no downsides | Say "the tradeoff is..." at least three times |
| Waiting to be asked about failure | Ask it yourself: *"what happens if the registry is down?"* |
| Silence while thinking | *"I'm going to start with the request path and come back to the data layer"* |
| Not scaling the answer | End with *"at 10x, the thing that breaks first is..."* |

### The clarifying questions that always apply

- What scale? Users, requests per second, data volume, number of teams?
- What are the constraints — budget, timeline, existing systems, team skills?
- Any compliance requirements?
- What does "done" mean? What's the success metric?
- What already exists that I should use rather than replace?

**That last one matters.** A design that ignores what the company already runs is a rewrite proposal,
and rewrite proposals lose.

---

## The live exercises — what's actually being measured

### They are not testing whether you memorized boto3

They're watching:
- **Do you clarify before coding?** ("Should this include volumes in all regions, or just the current
  one? Should it exclude volumes tagged as intentional spares?")
- **Do you handle errors and pagination**, or write the happy path and stop?
- **Do you narrate?** Silence for four minutes is indistinguishable from being stuck.
- **What do you do when you don't know an API name?** The right answer is *"I'd check the boto3 docs
  for the exact parameter — I know it's `describe_volumes` with a `Filters` argument"* and keep
  going. Freezing is the wrong answer.

```python
# What good looks like: paginated, filtered server-side, errors handled
import boto3

def orphaned_volumes(region: str) -> list[dict]:
    ec2 = boto3.client("ec2", region_name=region)
    paginator = ec2.get_paginator("describe_volumes")
    out = []
    for page in paginator.paginate(
        Filters=[{"Name": "status", "Values": ["available"]}]   # filter SERVER-side
    ):
        out.extend(page["Volumes"])
    return out
```

**Using a paginator rather than a bare call is the detail an interviewer notices** — it says you've
hit the 1,000-item truncation in real life.

---

## Mock interviews — what to fix, in order

Watch a recording and count these. Fix them top-down; the first two account for most of the damage.

1. **Silences over five seconds.** Narrate: *"I'm thinking about whether to put this in readiness or
   liveness..."* Thinking out loud is not weakness — it's the thing being measured.
2. **STAR stories running past two minutes.** You have not practiced the 90-second version. Write it
   down and time it.
3. **No numbers.** "I made the image smaller" vs "1.02 GB to 155 MB, and HIGH/CRITICAL CVEs from 45
   to 8."
4. **No trade-offs.** Say the words *"the tradeoff is"* in every design answer.
5. **Filler words.** A pause is better than "um." Slow down.
6. **Trailing off.** End deliberately: *"...so that's the approach I'd take."*

---

## The experience question — why the model answer works

Three moves, in order:

**1. Direct acknowledgment.** *"That's right — I don't have paid experience yet."* No hedging, no
reframing it as a strength. Trying to spin it reads as evasive, and they already know the answer.

**2. Concrete evidence, with a specific.** Not "I have projects" but *"a developer adds a config file
and gets a running service in ten minutes, and I watched three people who'd never seen it use only
the README."* The stranger test detail is what makes it credible.

**3. An honest ramp estimate.** *"Productive on well-defined work quickly; need support on production
incidents for the first few months."* This is the part candidates skip, and it's what makes the rest
believable — someone who claims they'll be fully productive on day one is either naive or
overselling.

**The two failure modes:** defensiveness ("well, I've done a lot of projects...") and denial
(pretending the gap doesn't exist). Both lose the room. Direct acknowledgment wins it surprisingly
often.
