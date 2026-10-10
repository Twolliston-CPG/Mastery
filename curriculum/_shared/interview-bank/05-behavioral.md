# Interview Bank: Behavioral

---

### The question you will definitely get: "You don't have professional experience in this."

**Answer it directly. No apology, no overclaiming.**

> "That's right — I don't have paid experience yet. What I do have is six months of full-time focused
> work and three systems I built and operate.
>
> The one I'd point at is [Charlie] — a developer adds a config file, opens a PR, and gets a running
> service with a pipeline, a dashboard, and alerts in under ten minutes. I can walk you through the
> architecture and the three things I got badly wrong building it.
>
> I learn fast and I document what I learn — that's the twenty blog posts. Realistically I'd expect to
> be productive on well-defined work quickly, and to need support on production incidents for the
> first few months."

**Why this works:** direct acknowledgment, concrete evidence, an honest read on your ramp. The two
answers that lose the room are defensiveness and pretending the gap doesn't exist.

---

### Q1. Tell me about a time something broke and what you did.

**Source: your incident journal.** Use STAR, 90 seconds.

**Model shape (from BF-52):**
> **S:** I was building the security layer for my Kubernetes delivery project and wanted to enforce
> that every pod declares resource limits.
> **T:** Write and roll out an admission policy.
> **A:** I wrote a Kyverno policy in Enforce mode and applied it cluster-wide. Within a minute
> nothing could deploy — including kube-system DaemonSets. The CNI pods couldn't be recreated. I'd
> effectively locked myself out of my own cluster. I found it through `kubectl get events` showing
> PolicyViolation on system components, patched the policy to Audit to stop the bleeding, then
> rewrote it with system namespaces excluded and rolled it out in Audit for a day first to see what
> it *would* have blocked.
> **R:** The policy has been enforcing since with no false positives. And I now have a rule: every
> admission policy goes out in audit mode first, always excludes system namespaces, and I check the
> `failurePolicy` — because a webhook with `failurePolicy: Fail` that becomes unavailable blocks
> every write to the cluster. That's a total outage caused by a security control.

**Why this story is good:** self-inflicted, technically interesting, clearly diagnosed, and the
lesson is specific and transferable. It works for "a time you made a mistake," "a time something
broke," and "a time you learned something."

---

### Q2. Tell me about a technical decision you made and the trade-off.

**Model shape (Project Charlie / Backstage):**
> For the platform project I had to decide how to build the service catalog. The obvious choice was
> Backstage — it's what the industry uses. I spent a day evaluating it and decided against it.
>
> Backstage is a substantial framework and I estimated two weeks to get a working portal. What I'd
> have demonstrated at the end is that I can follow Backstage's documentation. What I actually wanted
> to demonstrate is that I understand what a golden path *is*.
>
> So I built a Terraform module registry, a template repo, and PR-driven onboarding with a small CLI.
> Four days instead of two weeks, and I can explain every line of it.
>
> The trade-off is real: I don't get the plugin ecosystem, and at a company already running Backstage
> my thing is irrelevant. If I were doing this for an employer with 200 engineers, I'd use Backstage.
> For demonstrating understanding in a limited window, building it was the right call.

**Why this works:** it shows you evaluated rather than defaulted, and it names the conditions under
which you'd decide differently. That's what "judgment" means.

---

### Q3. How do you learn something new?

> I build something with it immediately. I've found that reading or watching a course gives me
> recognition — I can follow along and it feels like learning — but I can't produce anything from
> blank. So my rule is: watch or read it once, then rebuild it from an empty file with only the
> official docs, then deliberately break it and fix it.
>
> The breaking part is what actually teaches me. When I was learning Kubernetes I built a set of
> broken-cluster scenarios and worked through them under a timer. That's where I learned that
> `kubectl describe` events answer most problems and that I'd been reaching for `logs` first, which
> is useless when the container never started.
>
> And I write it up. Explaining something forces me to find the parts I only half understand.

---

### Q4. Why the career change?

**Be honest and be specific. Vagueness reads as running away from something.**

Structure: what you did before → what specifically pulled you toward this → what you've done about it
→ why now.

> "I spent [N] years in [field]. The part I consistently liked most was [the automation / the
> troubleshooting / making a broken process work], and I kept finding myself scripting things nobody
> asked me to script.
>
> I decided to do it properly rather than dabble — six months full time, AWS and Terraform
> certifications, three projects I built and operate. What confirmed it was [a specific moment —
> debugging something at 1am and enjoying it].
>
> What I bring that's not standard for someone at this stage is [transferable thing: incident
> handling under pressure, working a ticket queue, communicating with non-technical stakeholders]."

**Never criticize a previous employer.** It is the fastest way to lose a room.

---

### Q5. Tell me about a disagreement with a colleague.

If you don't have a work example, use a technical disagreement from a study group, an open-source PR
review, or a code review.

**Model shape:**
> **S:** In a study group we were designing the deployment for a shared project. Another person wanted
> a single shared cluster for all environments to save money.
> **T:** I thought that was wrong, but it was a reasonable position and cost genuinely mattered.
> **A:** Rather than arguing from principle I asked what would happen when we tested a cluster upgrade
> — because that's the scenario where sharing bites you. We walked through it and agreed the risk was
> real. Then I proposed the compromise: one cluster for dev and staging, separated by namespace and
> quota, and a separate production cluster. That got most of the cost saving and kept the blast
> radius bounded.
> **R:** That's what we built. What I took from it is that "you're wrong" doesn't move anyone, but
> "let's walk through what happens when X" usually does — and sometimes it turns out they're right.

**They're testing whether you can disagree without being difficult**, and whether you can change your
mind.

---

### Q6. Where do you want to be in three years?

> "Honestly, competent. I want to be the person on the team who gets handed the problem nobody can
> figure out, and I know that takes real production experience I don't have yet.
>
> Specifically I'd like to grow toward platform engineering — I've found I'm most interested in the
> developer-experience side, making the right thing the easy thing. But I'm aware that's a role you
> earn by having operated things first, so the next couple of years are about depth: on-call, real
> incidents, systems I didn't build."

**This is a good answer because it's specific, honest about the gap, and doesn't imply you'll leave
in a year.**

---

### Questions to ask them

Asking nothing is a red flag. Asking good questions is a genuine differentiator — and these are also
how you avoid taking a bad job.

**About the work**
- What does a typical week look like for this role?
- What's the biggest technical problem the team is fighting right now?
- What would you want me to have accomplished in the first 90 days?

**About reality (the ones that actually tell you something)**
- **How often do you deploy, and how long does a deploy take?** — the single most diagnostic question
  you can ask about engineering maturity
- **What does on-call look like? How often does someone get paged at night?**
- What happened in your last significant incident, and what changed afterward?
- How much of the team's time goes to unplanned work?

**About growth**
- How do people here learn things they don't know yet?
- Is there budget for certifications or conferences?
- What's the path from this role to the next one?

**About you as a junior**
- Who would I be learning from day to day?
- How does the team handle it when someone is stuck?

**Never ask in a first round:** salary (let them raise it), vacation policy, or "what does the
company do?" — that last one says you didn't prepare.
