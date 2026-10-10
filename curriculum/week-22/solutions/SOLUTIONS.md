# Week 22 Solutions

Working platform code: [`../projects/charlie-platform/`](../../projects/charlie-platform/)

---

## Lab 1 — The golden path

### Why the tool-list answer fails

Asked "what is platform engineering?", most candidates answer with a tool list: *"Backstage,
Crossplane, ArgoCD, Terraform."* That answer says you've read the landscape diagram.

The answer that lands describes a **problem and a product**:

> *"A golden path is the opinionated, supported, well-lit route to production. It isn't the only way —
> you can go off it — but it's the paved way: it comes with a pipeline, monitoring, alerting, and
> security controls, and someone supports it. The goal is that the easiest thing to do is also the
> right thing, so nobody has to choose between shipping fast and doing it properly."*

**Then the follow-up you should volunteer:** *"and the hard part isn't building it, it's adoption —
a platform nobody uses is a failed product, and adoption you mandate gets routed around."*

### Cognitive load is the actual argument

From *Team Topologies*: a team's effectiveness is bounded by how much they can hold in their heads.
Every technology a product team must learn to ship is load taken from the product.

**The platform's job is to reduce that load, not to add a tool.** A "platform" that requires
developers to learn Backstage *and* Kubernetes *and* Terraform has increased cognitive load and
called it a platform.

That framing is also the test for a platform feature: *does this reduce what a product engineer must
know, or does it add to it?*

### Adoption over uptime

An infrastructure team optimizes for uptime and says no. A platform team optimizes for **adoption**
and says "here's the easy way."

The distinction matters practically: if the golden path is slower or more annoying than doing it by
hand, developers will do it by hand — and now you have two platforms to maintain and no consistency.
**The paved road has to genuinely be the fastest option.** That's a product constraint, not an
engineering one.

---

## Lab 2 — The product brief

### Why non-goals are the hardest and most important section

A platform that supports everything is Kubernetes with extra steps. The value comes from
**constraint**: because the path only supports stateless HTTP services with optional Postgres, the
platform can make strong guarantees, generate correct manifests, and evolve them centrally.

**And going off the path must be possible, not forbidden.** A team needing Kafka talks to you and
gets a bespoke setup — that's a *supported outcome*, not a failure. A platform that forbids exceptions
creates shadow infrastructure, which is worse than a documented exception.

### Naming the riskiest assumption

> *"The riskiest assumption is that developers will accept the constraints rather than demanding
> exceptions. Mitigation: make the path genuinely faster, and make going off it possible."*

This is what separates a product brief from a technical design. The riskiest assumption in most
platform projects is **human**, not technical — and a candidate who says so has thought about it
properly.

---

## Lab 3 — The contract

### Why `tier` is the key design move

Compare:
```yaml
# Twelve technical decisions a product engineer should not have to make
replicas: 3
pdbMinAvailable: 2
topologySpreadMaxSkew: 1
sloAvailability: 99.9
alertSeverity: page
backupRetentionDays: 14
multiAz: true
...
```
```yaml
# One meaningful decision
tier: critical
```

**Three things this buys you:**
1. The developer makes a decision they're qualified to make ("how important is this service?")
   instead of twelve they aren't.
2. The platform can **change what `critical` means** in one place — raise the SLO, add a
   topology constraint — and every critical service inherits it.
3. Tiers become the language of a real conversation: *"is this critical or standard?"* is a
   discussion a product manager can join.

### Error messages are the most-read documentation

This is the highest-value insight in the week and worth stating plainly in an interview:

> *"A validation error is the most-read documentation in a platform. It arrives at the exact moment
> someone needs it, and it's the only docs a developer is guaranteed to see. I spent an hour on error
> messages and it returned more than a day on the docs site would have."*

The "GOOD" example does four things: names the file and line, states what was wrong, **explains the
valid options with their meaning** (not just their names), and suggests a correction. The
Levenshtein "did you mean" is twenty lines of code and it's the part people remember.

### What must never be configurable

```yaml
# NOT in service.yaml, ever:
securityContext.runAsNonRoot: false
resources.limits: <unset>
networkPolicy.enabled: false
```
**If a security control is a knob, it will be turned off** — at 6pm, by someone debugging, with a
comment saying "temporary." Controls belong in the generated output, not the input.

Same principle as Kyverno mutation (week 19) and the hardened template Dockerfile (Lab 4): the
platform decides, the developer doesn't have to.

---

## Lab 4 — Modules and templates

### Never `?ref=main`

```hcl
source = "git::https://github.com/org/platform-modules.git//service-runtime?ref=v1.4.0"
```
With `?ref=main`, your consumers' plans change when you merge — **with no commit in their
repository**. That's an unreproducible build and a genuinely nasty incident when the change lands
during someone else's unrelated deploy.

Tagged releases also give you a **migration path**: v1 and v2 can coexist while teams upgrade, and a
CHANGELOG tells them what breaks.

### The template ships hardened

The generated `Dockerfile` is non-root, distroless, read-only. The generated CI includes the security
gates from week 18. The generated manifests include probes, resources, and a NetworkPolicy.

**A developer who has never heard of `runAsNonRoot` gets it anyway.** That's the whole thesis: the
platform makes the secure thing the default rather than the thing you're rejected for forgetting.

### Measure the scaffolding

Time `platform new-service` → PR open. If it takes 5 minutes, nobody uses it. Under 2 minutes and it
becomes the obvious choice.

**Every second of friction on the paved road is an argument for going around it.**

---

## Lab 5 — The Backstage decision

### The decision as an interview answer

> *"I evaluated Backstage and decided against it. It's what the industry uses and I spent a day with
> it, but I estimated two weeks to a working portal — and what that would demonstrate is that I can
> follow Backstage's documentation. What I actually wanted to demonstrate is that I understand what a
> golden path is. So I built a module registry, a template repo, and PR-driven onboarding in four
> days, and I can explain every line of it.*
>
> *The tradeoff is real: I don't get the plugin ecosystem, and at a company already running Backstage
> my thing is irrelevant. If I were doing this for an employer with 200 engineers, I'd use
> Backstage."*

**That answer demonstrates evaluation rather than defaulting**, and it names the conditions under
which you'd decide differently — which is what "judgment" means.

### The market check that makes it a real decision

Check 20 postings from your week-14 target list. If Backstage appears in several, **learn it** —
relevance beats elegance, and being able to say "I've built a Backstage plugin" for an employer
running Backstage is worth more than an elegant custom alternative.

Write the ADR either way. The decision record is worth more than the tool.
