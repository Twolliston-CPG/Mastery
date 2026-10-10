# Week 24 Solutions

---

## Lab 1 — Documentation

### The getting-started test

> **Can someone follow this without asking a question?**

Common failures, all of which the stranger test surfaces:

| Failure | Fix |
|---|---|
| Assumes they know what a "tier" is | Link to `tiers.md` at first mention, or inline the one-line version |
| Assumes they have the repo cloned and tools installed | State prerequisites explicitly, or remove the need for them |
| Uses platform vocabulary ("reconcile", "paved road") | Write in the user's vocabulary, not yours |
| Shows the YAML without saying **where the file goes** | `services/<name>/service.yaml` — the path is a step |
| Doesn't say what success looks like | "In ~8 minutes you'll get a comment with your URLs" |

**The last one is the most common.** A guide that ends at "merge the PR" leaves the reader unsure
whether it worked. Tell them what they will see.

### Why `escape-hatches.md` matters more than it looks

Platform teams don't write this document because it feels like admitting failure. It is the opposite.

**A platform that forbids exceptions creates shadow infrastructure** — teams build what they need
anyway, outside your visibility, without your security controls, and you find out during an incident.
A platform that documents the exit gets told about exceptions, which means you know they exist, and
**several teams needing the same escape hatch is your roadmap.**

> *"Going off the paved road is a supported outcome. If several teams need the same thing, that's a
> signal we should pave it."*

That framing turns exceptions from a governance problem into product research, and it's a strong
thing to say in a platform interview.

---

## Lab 2 — The stranger test

### Why you must stay silent

The instinct is to help — *"oh, that's in the other file"* — and that single sentence destroys the
data. You now know they got past that step; you don't know they wouldn't have.

**Write every question down instead of answering it.** Each one is a documentation gap.

### What the observations map to

| They did this | The actual bug |
|---|---|
| Re-read a paragraph | Ambiguous wording |
| Scrolled back up | Information in the wrong order |
| Opened a file the README didn't mention | A missing step |
| Asked a question | Missing documentation |
| Guessed a value | Missing example, or a bad default |
| Hit an error they couldn't act on | **A bad error message** — the highest-value fix |

### The second run

After fixing, run it with a different person. **It should be faster and quieter.** If it isn't, you
fixed the specific things that person tripped on rather than the underlying cause — usually
information architecture rather than wording.

### Why this is Gate 6

> *"A stranger deploys a service via pull request in under 10 minutes, unaided."*

Everything else about Charlie is claims. This is the demonstration. If someone who has never seen it
can self-serve, **you built a platform** — and you can say so in an interview without qualification.

It also gives you a genuine developer-experience story: *"I watched three people use it and fixed
eleven things, and the biggest one was that my error messages said what was wrong without saying what
to do."* That is worth more than any feature list.

---

## Lab 3 — The video

### Why the "what I got wrong" section works

A flawless demo reads as one of two things: trivial (the problem was easy) or rehearsed (you're
showing the happy path). Neither builds confidence.

Thirty seconds of *"I enforced a Kyverno policy cluster-wide with no exclusions and locked myself out
of my own cluster — here's the three-step rollout I use now"* does three things:
1. Proves it's real — tutorial output has no scars
2. Demonstrates you learn from failure, which is the actual question behind most behavioral questions
3. **Hands the interviewer a question you're prepared for**

It is reliably the most memorable thirty seconds in the video.

### One take is fine

Fluency beats polish. A slightly rough video where you clearly know the system is more convincing
than a rehearsed one. Do not spend a day editing — spend it on the stranger test.

---

## Portfolio consolidation

### What a hiring manager sees in 90 seconds

1. Your **profile README** — one line: what you do and what you've built
2. Three **pinned repos** — each README's first line is a problem statement
3. **Green CI badges**
4. The **contribution graph** — 24 weeks of consistency

**Consistency beats intensity.** A steady graph reads as discipline; three bursts read as bootcamp
assignments. You have 24 weeks of real commits — that's the asset.

### The three-project story

| Project | The claim |
|---|---|
| **Alpha** | "I can build production-shaped cloud infrastructure entirely in code, with no long-lived credentials." |
| **Bravo** | "I can make shipping something insecure structurally difficult — and here's it blocking a real CVE." |
| **Charlie** | "I understand that a platform is a product, and here's one where a stranger self-serves in 8 minutes." |

Three claims, escalating in scope, each with evidence. **Be able to say each in one sentence** — that
is your 30-second answer to "tell me about your projects," and the version an interviewer remembers.
