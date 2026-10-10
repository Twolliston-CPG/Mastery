# The Job Search

> Starts week 14, not week 26. This is the half of the program that produces the outcome.

---

## 1. Why week 14

**The pipeline has a lag.** Application → recruiter screen → technical screen → onsite loop → offer → start date is **6–10 weeks** when everything goes well, and junior pipelines typically need **100–200 quality applications** to produce a small number of offers. A student who starts applying in week 26 receives their first offer around month 9 — with three extra months of no income and declining morale.

**Week 14 is when the résumé becomes true.** SAA and Terraform Associate are both passed. Project Alpha is shipped and public. There is a real, verifiable thing to point at. Before week 14 the applications are weak; after week 14 they are honest.

**Early interviews are the best diagnostic available.** No self-assessment finds gaps as fast as a technical screen. A rejection in week 16 that reveals shaky Linux troubleshooting is worth more than any practice exam — and there are still ten weeks to fix it. A rejection in week 27 is just a rejection.

**The cost is fixed and small.** Four hours per week from week 14 to week 25, rising to full-time in week 26. It comes out of the week's slack, not out of study blocks.

---

## 2. Target roles

### Primary — 80% of application volume

`DevOps Engineer` · `Cloud Engineer` · `Cloud Infrastructure Engineer` · `Infrastructure Engineer` · `Site Reliability Engineer I` · `Systems Engineer (cloud)` · `Build & Release Engineer` · `Automation Engineer`

Modifiers that indicate a real entry point: *Junior, Associate, I, Entry-level, Early Career, New Grad.*

### Secondary — 20%

`Associate Platform Engineer` (only at companies that already have a platform team — a junior platform role at a company with no platform function is usually a mislabeled sysadmin job) · `Cloud Security Engineer I` · `DevSecOps Engineer` at companies large enough to have junior tiers.

### The high-volume door most candidates ignore

**Cloud support engineer roles.** AWS Support, Azure/GCP support orgs, managed service providers, and the support engineering teams at infrastructure vendors — Datadog, HashiCorp, GitLab, Grafana, Elastic.

These hire at exactly this skill level, in volume, with a real technical bar. The work is genuine troubleshooting against real customer systems across an enormous surface area, which builds diagnostic skill faster than most junior DevOps roles do. They convert internally to DevOps/SRE/solutions roles in 12–24 months, and the internal transfer bar is far lower than the external hiring bar.

Treat these as a legitimate primary outcome, not a fallback. "Got hired at AWS Support and moved to an infrastructure team 18 months later" is one of the most reliable paths into this field that exists.

### Where the junior roles actually are

Weight applications toward employers who genuinely hire and train juniors:

| Type | Why they hire juniors |
|---|---|
| **Consultancies and MSPs** | Volume hiring, structured training, and enormous exposure breadth. Often the fastest skill growth available. |
| **Government contractors** | Pipeline hiring, clearance sponsorship, stable. *(This is where Security+ can matter — see [CERTIFICATIONS.md §5](CERTIFICATIONS.md#5-the-wildcard-security).)* |
| **Mid-market, 200–2000 employees** | Have real infrastructure and real problems but cannot outbid big tech for seniors, so they hire and grow people. **The sweet spot.** |
| **Non-tech companies with tech teams** | Hospitals, universities, insurers, logistics, manufacturing, local government. Less competition per opening, more willingness to train. |
| **Regional and local employers** | Far less competition than remote-first postings, which draw hundreds of applicants each. |

Deprioritize: startups under 50 people (they need someone who already knows), and FAANG-tier new-grad programs (almost entirely CS-degree pipelines).

### On job description requirements

A posting asking for "3–5 years" will interview a candidate with 0 who has three shipped projects, two certifications, and a referral. Postings are wish lists. **Apply at 60% match.** The only genuinely hard filters are clearance, legal work authorization, and location.

---

## 3. The numbers

| Metric | Realistic expectation at junior level |
|---|---|
| Cold application → recruiter screen | **2–5%** |
| Referred application → recruiter screen | **20–40%** |
| Recruiter screen → technical screen | 40–60% |
| Technical screen → onsite loop | 30–50% |
| Onsite → offer | 20–40% |
| **Applications per offer (cold)** | **~100–200** |
| **Applications per offer (referred)** | **~20–40** |

Two things follow from this table.

**One: referrals are worth roughly 5–10× a cold application.** Everything in §5 follows from that single number. An hour spent on a genuine connection outperforms an hour spent on ten more cold applications.

**Two: rejection volume is structural, not personal.** At 3% cold conversion, 97 of 100 applications going nowhere is the *expected* outcome, not evidence of failure. Set the expectation in week 14, before the rejections start, because the week-18 morale dip is the most common point of program abandonment.

### Weekly targets

| Weeks | Applications/wk | Networking | Time |
|---|---|---|---|
| 14–21 | 10–15 quality | 3 genuine conversations | ~4 hrs |
| 22–25 | 15–20 | 5 conversations + 2 events | ~8 hrs |
| 26+ | 20–25 | 5+ conversations | ~20 hrs |

"Quality" means the résumé was tailored to that posting's keywords and a human being was identified and contacted where possible. Fifteen tailored applications beat a hundred one-click ones — and the one-click flood is what most candidates do instead of the work that converts.

---

## 4. The résumé

### Structure for a career changer with no industry experience

```
NAME · City, State · email · phone · linkedin.com/in/… · github.com/…

SUMMARY (3 lines, specific, no adjectives)
  Cloud and DevOps engineer with AWS SAA and HashiCorp Terraform
  certifications. Built and operate three production-shaped platforms:
  fully-automated AWS infrastructure, a Kubernetes delivery pipeline with
  supply-chain security controls, and a self-service developer platform
  that provisions a new service from a pull request in under 10 minutes.

CERTIFICATIONS  (near the top — this is what the ATS and the 8-second scan look for)
  AWS Certified Solutions Architect – Associate (2026)
  HashiCorp Certified: Terraform Associate (2026)

TECHNICAL PROJECTS  (the main section — before work history)
  Three flagship projects. 3–4 bullets each. Every bullet has a number.

SKILLS  (grouped, honest, keyword-dense for the ATS)
  Cloud: AWS (EC2, VPC, IAM, S3, RDS, EKS, Lambda, CloudWatch)
  IaC: Terraform, CloudFormation basics
  Containers: Docker, Kubernetes, Helm, ArgoCD
  CI/CD: GitHub Actions, OIDC federation, GitOps
  Security: Trivy, Semgrep, cosign, SBOM, OPA/Kyverno, Falco
  Observability: Prometheus, Grafana, OpenTelemetry, SLOs
  Languages: Python, Bash, SQL
  Linux: Ubuntu/RHEL administration, systemd, networking

PROFESSIONAL EXPERIENCE  (whatever it is — reframed toward transferable skill)

EDUCATION
```

### Rules

**Put projects above work history.** The projects are the qualification. A reverse-chronological résumé leading with unrelated jobs buries the only relevant content.

**Every project bullet carries a number.** Not "implemented CI/CD pipeline" but "built a GitHub Actions pipeline deploying to AWS via OIDC federation with zero long-lived credentials; plan-to-production in 4 minutes."

**Mirror the posting's language.** If it says "infrastructure as code," the résumé says "infrastructure as code," not just "Terraform." ATS keyword matching is literal.

**One page.** No exceptions at this level.

**Reframe prior work honestly.** Retail, military, healthcare, teaching, trades — all contain transferable material: incident handling under pressure, process improvement, documentation, customer communication, working a queue. Name it in that vocabulary. Do not pad it into fake technical experience.

**Never fabricate.** Beyond the ethics, it is self-defeating: invented experience collapses in the first technical round, and the collapse is worse than the gap would have been. Everything claimed must map to a repo or an incident-journal entry.

### LinkedIn

Headline: `Cloud / DevOps Engineer | AWS SAA, Terraform Associate | Kubernetes, IaC, CI/CD` — keyword-dense, because recruiter search is keyword-driven.

"Open to work" on, with recruiter-only visibility if there's a current employer to consider. About section: the summary, expanded to a short paragraph with a link to the GitHub. Featured section: the three flagship projects.

**Post the weekly blog posts to LinkedIn as well.** Twenty weeks of visible learning-in-public creates inbound recruiter contact that no amount of outbound applying does. This is the single most-skipped high-return activity in a junior job search.

---

## 5. Networking, without it being awkward

Referrals convert 5–10× cold applications, so this is where the highest-leverage hours are. The framing that makes it tractable: **you are not asking for a job, you are asking for information.** People decline job requests from strangers and accept 15-minute conversations about their work.

### Three conversations per week, from week 14

**Where:** local meetups (AWS User Groups, Kubernetes/CNCF community days, DevOps Days — these exist in most metros and are attended largely by people who hire) · community Slack and Discord servers, answering questions rather than asking · LinkedIn, engaging genuinely with posts before ever sending a message · alumni networks · open source, where a small merged PR earns a real relationship.

### The outreach message that works

```
Hi [name] — I'm making a career change into cloud infrastructure and
I noticed you work on [specific thing] at [company]. I just finished
building [one-line project description] and ran into [specific real
question about their domain].

Would you be open to a 15-minute call? I'm trying to understand what
the work actually looks like day to day, not asking for a referral.
```

Why it works: it is specific, it demonstrates that work has already been done, it asks for something small and bounded, and it explicitly removes the pressure. Response rates on this run far higher than on generic outreach.

### After the conversation

Thank-you note within 24 hours, referencing something specific they said. Then **stay in touch** — send them a relevant article a month later, tell them when you ship the thing you discussed. Most candidates have one conversation and vanish; the ones who maintain three or four warm relationships get told about roles before they are posted.

### Asking for the referral

Only after a real relationship exists, and never in the first conversation:

```
Hi [name] — I saw [company] posted a [role]. Based on our conversation
about [topic], it looks like a strong fit for what I've been building.
Would you be comfortable referring me? Totally fine if not — I know
referrals carry your name. Résumé attached either way.
```

The explicit permission to decline is what makes it askable. It protects the relationship whichever way they answer.

---

## 6. The interview loop

### What to expect

| Stage | Format | What they're testing |
|---|---|---|
| **Recruiter screen** | 20–30 min | Communication, motivation, salary alignment, basic fit |
| **Technical screen** | 45–60 min | Fundamentals, one or two hands-on tasks, project discussion |
| **Technical deep dive** | 60–90 min | Troubleshooting out loud, system design, project deep dive |
| **Practical / take-home** | 2–4 hrs | Write Terraform, debug a cluster, script something |
| **Behavioral** | 45 min | Collaboration, handling failure, learning, ownership |
| **Hiring manager** | 30–45 min | Team fit, trajectory, growth potential |

### What junior candidates get asked, by frequency

**Linux and networking (very high):** "walk me through what happens when you type a URL and hit enter" · "a server is slow, how do you diagnose it?" · "explain DNS resolution" · "what's in `/proc`?" · permissions · "how do you find what's using a port?"

**Cloud (very high):** public vs private subnet · SG vs NACL · IAM roles vs users · "how does an EC2 instance get credentials without keys on disk?" · Multi-AZ vs read replica · how would you architect [scenario].

**IaC (high):** what's in Terraform state and why it matters · `count` vs `for_each` · how to handle secrets · how to import existing infrastructure · how to structure modules for multiple environments.

**Containers and Kubernetes (high):** what a container actually is · a pod is in CrashLoopBackOff, what now? · Deployment vs StatefulSet · how a Service routes traffic · requests vs limits.

**CI/CD (medium-high):** describe your pipeline · how do you handle secrets in CI · blue/green vs canary vs rolling · how do you roll back.

**Behavioral (always):** a time something broke and what you did · a time you were wrong · how you learn something new · a disagreement with a colleague · why this career change.

### The thing that decides junior loops

**Troubleshooting out loud.** More junior candidates are rejected for freezing on "how would you debug this?" than for any knowledge gap.

What interviewers want to hear is a *method*, not an answer:

1. What is the symptom, precisely? Who is affected, and since when?
2. What changed recently? *(This resolves the majority of real incidents.)*
3. What's my first hypothesis, and what's the cheapest test that confirms or kills it?
4. Walk the layers — application → container → node → network → cloud → DNS.
5. What would I check next if that's clean?

Saying "I don't know, but here's how I'd find out" is a **passing answer.** Silence is not. This is what [ROADMAP.md R6](ROADMAP.md#r6--train-troubleshooting-as-a-first-class-subject) and fifty entries in the incident journal are for — by week 26 the student has genuinely done this fifty times and it sounds like it.

### Handling the experience question

It will come: *"You don't have professional experience in this."*

Answer it directly, without apology or over-explanation:

> "That's right — I don't have paid experience yet. What I do have is six months of full-time focused work and three systems I built and operate. [Project Charlie] provisions a new service from a pull request in under ten minutes; I can walk you through the architecture and the three things I got wrong building it. I learn fast and I document what I learn — that's the twenty blog posts. I'd expect to be productive on well-defined work quickly and to need support on production incidents for the first few months."

Direct acknowledgment, concrete evidence, an honest read on the ramp. Defensiveness or overclaiming both lose the room; this answer often wins it.

### Salary

Research the local range for junior cloud/DevOps roles (levels.fyi, Glassdoor, Robert Half's annual tech salary guide, and the local meetup grapevine). Give a range, not a number, with the bottom of your range at your actual target. In jurisdictions with pay transparency laws, ask the recruiter for the posted band — they must provide it.

Do not negotiate hard on a first role in a career change. Get in, get 12–18 months of experience, and the second job is where the compensation step happens. The first offer's real value is the experience it unlocks, not its number.

---

## 7. After week 26 — the cadence that carries you to the offer

Week 26 is not the end of the program. It is the point where the pipeline is full and converting. The most likely offer window is **month 6–10**.

**The weekly cadence from week 27 until hired:**

| Activity | Hours/wk |
|---|---|
| Applications and follow-up (20–25 quality apps) | 8 |
| Networking — 5 conversations, 1 event | 4 |
| Interview prep, tailored per company | 6 |
| **Continued building** — iterate the projects, add features | 10 |
| One blog post | 3 |
| CKA prep, if not already done | 8 |

**Keep building.** A candidate still shipping during their search interviews differently from one who is waiting — they have new material, momentum, and no desperation in their voice. It is also the best available defense against the morale erosion of a long search.

**Let the interviews drive the studying.** Every rejection carries information. Failed on Linux troubleshooting? That's next week's focus. Couldn't answer a networking question? Drill it. Track the rejection reasons in a spreadsheet; after ten interviews the pattern is unmistakable and the fix is obvious.

**Re-evaluate the targeting at week 34.** If 100+ quality applications have produced no technical screens, the problem is upstream of skill — it is the résumé, the targeting, or the lack of referrals. Change one variable at a time: rewrite the résumé, or shift to a different role category, or go all-in on referrals for a month. Do not respond to no-response by sending more of the same application.

**If month 9 arrives with no offer,** the highest-value moves in order: (1) go hard at cloud support engineering roles, which have the highest volume and lowest bar for this exact profile, (2) take contract or contract-to-hire work, which converts frequently and has a much faster process, (3) approach consultancies and MSPs directly rather than through job boards, and (4) consider a lateral move into an internal IT or NOC role at a company with a real platform team, then transfer internally within a year. Every one of those is a genuine win. The goal is the first professional infrastructure role — the title on it matters much less than the eighteen months of experience it produces.
