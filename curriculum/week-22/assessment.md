# Week 22 Assessment

> Closed book, 25 min. **The first question is the one that matters.**

## Part A (15 min)
1. **Explain a golden path in 60 seconds.** Say it out loud and time it. Do not list tools.
2. What is the *Team Topologies* argument for a platform? What's the test for whether a platform
   feature is worth building?
3. Infrastructure team vs platform team — name four differences.
4. Why is **adoption** the load-bearing metric, and what happens to adoption you mandate?
5. Name six developer-experience metrics. Which is the single best proxy for platform quality?
6. Why are **non-goals** the hardest section of a product brief?
7. Should going off the paved road be forbidden? Why?
8. Why is `tier: critical` better than twelve individual knobs? Give three reasons.
9. What must **never** be configurable in the contract, and why?
10. Why are validation error messages the most-read documentation in a platform?
11. Why never `?ref=main` on a module source?
12. Give the Backstage build/buy answer, including the condition that would change it.

## Part B — Produce (10 min)
13. Write the product brief's "who is the user / explicitly not the user" section for Charlie
14. Write a JSON schema fragment validating a DNS-1123 service name with a useful description
15. Write the "GOOD" version of an error message for an invalid `tier` value

---

# Answer key

**A1.** *"A golden path is the opinionated, supported, well-lit route to production. It isn't the only
way — you can go off it — but it's the paved way: it comes with a pipeline, monitoring, alerting, and
security controls, and someone supports it. The goal is that the easiest thing to do is also the
right thing, so nobody has to choose between shipping fast and doing it properly."*
**Volunteer the follow-up:** the hard part is adoption, not construction.

**A2.** A team's effectiveness is bounded by **cognitive load** — how much they can hold in their
heads. Every technology a product team must learn to ship is load taken from the product.
**The test for a platform feature: does this reduce what a product engineer must know, or add to it?**
A platform requiring developers to learn Backstage *and* Kubernetes *and* Terraform has increased
cognitive load and called it a platform.

**A3.** Infrastructure team: takes tickets · success = uptime · gatekeeps · "you can't do that" ·
measured by incidents. Platform team: has **users** · success = **adoption** · paves · "here's the
easy way" · measured by time-to-first-deploy, DORA, adoption %.

**A4.** A platform nobody uses is a failed product regardless of engineering quality. **Adoption you
mandate gets routed around** — people build their own, and now you maintain two platforms with no
consistency. Adoption you earn survives, which is why the paved road must genuinely be the fastest
option.

**A5.** Time to first deploy · time to provision a new service · lead time for changes · platform
adoption % · support ticket volume · developer satisfaction. **Time to first deploy for a new
engineer on day one** is the best single proxy.

**A6.** Because a platform supporting everything is Kubernetes with extra steps. **The value comes
from constraint** — because the path only covers stateless HTTP services with optional Postgres, the
platform can make strong guarantees and evolve them centrally. Saying no to scope is what makes it
shippable.

**A7.** **No.** A team needing Kafka should talk to you and get a bespoke setup — that's a *supported
outcome*, not a failure. Forbidding exceptions creates shadow infrastructure, which is worse than a
documented exception because you don't know it exists.

**A8.** (1) The developer makes a decision they're **qualified** to make ("how important is this?")
instead of twelve they aren't. (2) The platform can **change what `critical` means in one place** and
every critical service inherits it. (3) Tiers become the language of a real conversation a product
manager can join.

**A9.** **Security controls** — `runAsNonRoot`, resource limits, NetworkPolicy. If a security control
is a knob, it gets turned off at 6pm by someone debugging, with a comment saying "temporary."
Controls belong in the **generated output**, not the input.

**A10.** They arrive at the exact moment someone needs them, and they are the **only documentation a
developer is guaranteed to see**. An hour spent on error messages returns more than a day on the docs
site. A good one names the file and line, explains the valid options *with their meaning*, and
suggests a correction.

**A11.** Consumers' plans change when you merge, **with no commit in their repository** — an
unreproducible build, and a nasty surprise when it lands during someone else's unrelated deploy.
Tagged releases also give you a migration path, since v1 and v2 can coexist.

**A12.** *"I evaluated it and built my own, because two weeks with Backstage would demonstrate that I
can follow its documentation, whereas I wanted to demonstrate that I understand what a golden path
is — and I can explain every line of what I built. The condition that changes it: if the employer
already runs Backstage, relevance beats elegance and I'd use it."*

---

**B13–B15:** see [`solutions/SOLUTIONS.md`](solutions/SOLUTIONS.md) Labs 2 and 3, and
[`../projects/charlie-platform/`](../projects/charlie-platform/).

## Scoring
| | |
|---|---|
| 10–12 | Move on. Charlie's design is sound. |
| 7–9 | Rewrite the product brief. The brief is what makes the build coherent. |
| < 7 | **Do not start building yet.** A platform built without a product brief becomes a pile of scripts. Spend another day on Labs 1 and 2. |
