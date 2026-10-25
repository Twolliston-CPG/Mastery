# Step by step, start to finish

[`START-HERE.md`](START-HERE.md) is day one. [`../ROADMAP.md`](../ROADMAP.md) is the strategy.
[`../WEEK-BY-WEEK.md`](../WEEK-BY-WEEK.md) is what each week contains.

**This file is the operating manual: what you actually do, on an ordinary Tuesday, and how that
compounds into 26 weeks.** Four loops, nested. Learn the daily one and the rest follows.

---

## Step 0 — before week 1 (about two hours, once)

Do all of [`START-HERE.md`](START-HERE.md). Summarised, so you can check it off:

- [ ] Every week README opens with **one figure and a spoken walkthrough** — read it before the day plan, say it out loud on Friday. Index: [`FIGURES.md`](FIGURES.md)
- [ ] Read [`../ROADMAP.md`](../ROADMAP.md) §1–2 — twenty minutes that decide the next six months
- [ ] **The market check** — 30 real job postings in *your* market. Azure-dominant? Swap the whole
      cloud track now. Decide once; re-litigating in month 3 costs a month
- [ ] Pick a cert track (A/B/C) from [`../CERTIFICATIONS.md`](../CERTIFICATIONS.md) §4
- [ ] `cd _setup && bash macos-setup.sh && bash verify.sh` (`linux-setup.sh` on Linux/WSL, `windows-setup.ps1` on Windows)
- [ ] Create `~/mastery/progress/` from the three templates in [`_shared/templates/`](_shared/templates/) (`progress`, `incident-journal`, `decisions`)
- [ ] Buy a domain (~$12). Best $12 in the program
- [ ] Import the Anki decks from [`_shared/anki/`](_shared/anki/)
- [ ] **Recurring Monday reminder: "check AWS bill."** For 26 weeks

> **Do not create an AWS resource before week 5**, and run `01-aws-guardrails.sh` before the first
> one. A surprise $400 bill in week 6 ends programs.

---

## Loop 1 — the day (4–8 hours)

Same five blocks every study day. The order is not arbitrary: retrieval comes **before** input.

| | Block | Time | What |
|---|---|---|---|
| **1** | Anki | 10 min | Every day. Skipping is what kills spaced repetition — the backlog compounds, then you quit |
| **2** | **Blank page** | 20 min | One idea, from memory, no notes. *Yesterday's vaguest thing.* See below |
| **3** | **The lab** | 2–5 h | The actual work. Keyboard, not video. This is the 70% |
| **4** | Drills | 45 min | From the week README — subnetting, `kubectl`, PromQL, bash |
| **5** | Log | 10 min | One line in `progress.md`. Fill in **"what surprised me"** |

### Block 2 in detail — the only block people skip

Write the name of one idea on a blank page. Explain it to a competent engineer who has never used the
tool. Under five minutes. No jargon you can't define on the spot.

**The gap is not what you forgot. It is where you used a word instead of a mechanism.** "It handles
service discovery" is a gap. Mark it, go read *only* that, close the file, rewrite from memory.

Full protocol and worked examples: [`_reference/MASTERY.md`](_reference/MASTERY.md).

### The rule that governs block 3

**Read a section once, then build from a blank file with only the official docs.** If you can't start
from blank, you haven't learned it — go back, but go back to *one named thing*, not the whole page.

**Open `solutions/` only after a genuine attempt.** Reading a solution feels like learning and isn't.
Recognition is not retrieval, and only retrieval survives an interview.

---

## Loop 2 — the week

Every `week-NN/` has the same shape: `README.md` · `labs/` · `solutions/` · `assessment.md`.

### Monday — orient (do not skip this hour)

```bash
cd curriculum/week-NN
cat README.md
```

Read, in this order:
1. **The thesis** at the top — it tells you why the week exists. If you can't restate it, the rest
   will feel arbitrary
2. **The deliverable** — know on Monday what ships on Friday
3. **Exit criteria** — this is the week's actual definition of done
4. **The reading map** — the specific `_reference/` files for this week. *You are never asked to go
   find something*

Then read the mapped files. **Each one ends with a Feynman check — do it.** Three or four targets
from that file's own headings, a ✗/✓ pair, and one trace. It takes five minutes and it is the only
part of reading that produces anything.

### Tuesday–Thursday — build

Labs, in order, one per day. Attempt fully before opening `solutions/`.

When you hit something you cannot explain:
1. Name the gap in one sentence
2. Reopen **only** the mapped reference section
3. Still stuck? → the domain's entry in [`SOURCES.md`](_reference/SOURCES.md) — primary sources, and
   every link goes to a specific page
4. Log it in `incident-journal.md`

### Friday — Break/Fix Friday, then ship

The highest-value four hours of the week.

- Run the week's scenarios from [`_shared/breakfix/`](_shared/breakfix/) (58 across seven domains)
- **Timed. Narrated out loud, as if an interviewer is listening.** Diagnose before you fix
- Log every one: symptom → hypothesis → confirmation → root cause → fix → prevention → surprised
- **Redraw this week's figure from memory**, close the file first, then check the badge order against
  `content/FIGURE.md`. The badge where the order slipped goes in `progress.md`
- **Then ship the week's deliverable.** Pushed, with a real README

By week 26 you'll have ~50 journal entries. That is your STAR story bank, and it is why *"how would
you debug this?"* stops being frightening.

### Saturday — consolidate

Push everything. Write the week's post (500–1,200 words on what you built or broke). It's the
cheapest credibility multiplier there is and it doubles as retrieval practice.

### Sunday — rest, or review

**One full rest day per week is part of the plan, not a deviation from it.** If you review instead:
re-explain *last* week's blank page **without looking at it**, and redraw the figure from **two weeks
ago** the same way. What survives is yours. Then skim next week's README and plan. The redraw schedule
is in [`FIGURES.md`](FIGURES.md#the-redraw-schedule).

### Weekly close-out

- [ ] Deliverable shipped and pushed
- [ ] Exit criteria met — each one *demonstrated*, not felt
- [ ] Break/fix logged
- [ ] This week's figure redrawn from memory, and the one from two weeks ago
- [ ] `progress.md` row complete, including "what surprised me"
- [ ] Anki current
- [ ] Post written

**Two or more unchecked? Do not start the next week.** Spend Monday closing them. Weeks compound; so
does debt.

---

## Loop 3 — the month, and the gates

Six gates, and a seventh if you take the CKA module. Each is **demonstrated, not self-assessed** — you
either did the thing under the timer or you didn't.

| Gate | Week | You must |
|---|---|---|
| **1** | [4](week-04/assessment.md) | Fresh VM → containerized app behind Nginx with TLS, systemd-managed. Explain the full packet path. CIDR math, no calculator |
| **2** | [9](week-09/assessment.md) | 80%+ on two *different* full-length SAA practice exams |
| **3** | [13](week-13/assessment.md) | `terraform apply` from a clean AWS account produces a working Alpha. **Zero static credentials** |
| **4** | [17](week-17/assessment.md) | Five broken clusters diagnosed unaided, under 15 min each, narrated |
| **5** | [21](week-21/assessment.md) | Pipeline blocks a critical CVE and refuses an unsigned image, live |
| **6** | [26](week-26/assessment.md) | A stranger deploys a service via PR in under 10 minutes |
| **7** | [30](week-30/assessment.md) | The second killer.sh session at the pass mark, inside two hours, no solutions (CKA module only) |

**Take the gate timed and cold.** An untimed gate you looked things up for tells you nothing, and the
only person it fools is you.

**The gate's Sunday also redraws every figure since the last gate**, cold, in badge order: four or five
figures, about twenty minutes. A figure you cannot redraw at the gate names the criterion you will
fail next, one level below where you are looking.

**From Gate 4 on, the gate's Sunday also scores the Kubernetes ladder**: twelve topics, five rungs, the
table in [`../KUBERNETES-MASTERY.md`](../KUBERNETES-MASTERY.md) §6 copied under the retrospective. The exam is
rung two; the ladder is how the rest is measured. After every lab, from week 1, read the lab's entry in
[`KUBERNETES-THREAD.md`](KUBERNETES-THREAD.md) and say its sentence; that is the five minutes that turn the
Linux, networking and AWS weeks into Kubernetes understanding instead of prerequisites.

### If you fail a gate — the important part

A failed gate is **information, not a verdict.** It has told you something no amount of reading
would have.

1. **Do not repeat the month.** Repeat the *specific failure*
2. Write down exactly which criterion failed, in one sentence
3. Two to four days on that one thing — labs and break/fix, not re-reading
4. **Retake the whole gate, timed**
5. Failed the same criterion twice? The gap is a level below where you're looking. Go one layer down
   — a Kubernetes networking failure is usually a Linux networking gap

Then write the month's retrospective (the format is at the bottom of each gate's `assessment.md`).

---

## Loop 4 — the program

| Month | Weeks | Focus | The one thing that matters |
|---|---|---|---|
| **1** | 1–4 | Linux · networking · Git · Docker | **Don't rush it.** Everything later is these three wearing a cloud costume. Skipping here is why people plateau at "I can follow a tutorial" |
| **2** | 5–9 | AWS core | Build it by hand before you automate it. Gate 2 is exam-shaped for a reason |
| **3** | 10–13 | Terraform + CI/CD → **Project ALPHA** | Sit the SAA (wk 10). Ship Alpha. First real portfolio piece |
| **4** | 14–17 | Kubernetes + EKS | **Apply for jobs from week 14.** Not week 26 — see below |
| **5** | 18–21 | DevSecOps → **Project BRAVO** | Supply chain, policy, runtime. The differentiator most candidates don't have |
| **6** | 22–26 | Platform + SRE → **Project CHARLIE** | Observability, IDP, interview reps. Pipeline should be converting |
| **7** | 27–30 | CKA module, beside the search | Optional, recommended. Book the exam on the Monday of week 27; the second simulator session is Gate 7 |

### Week 14 is not a typo

**Start applying at week 14.** The pipeline has a 6–10 week lag. Waiting until you "know Kubernetes"
is the single most common way this program fails — month 6 is meant to be when your pipeline is
*full and converting*, not when it starts. Read [`../JOB-SEARCH.md`](../JOB-SEARCH.md) §3 before the
rejections begin, so 97-of-100 going nowhere reads as arithmetic rather than a verdict.

### Honest expectation

~1,000–1,300 focused hours, three projects shipped, 2–4 certs → **an offer in month 6–10.** Plan
runway for nine months. A plan that assumes month 6 exactly will feel like failure in month 7, and
that feeling is what ends programs that were working.

---

## The three files you write in, forever

| File | One entry per | The field that matters |
|---|---|---|
| `progress.md` | week | **"What surprised me."** Highest-value field in the system — surprise is where your model was wrong |
| `incident-journal.md` | break/fix | **Prevention.** Anyone can fix; the hire is the person who stops it recurring |
| `decisions.md` | non-obvious choice | **Alternatives rejected, and why.** This is the staff-level signal |

These are the program's instrumentation *and* your interview material. Week 20 you will not remember
week 3 without them. Templates, with the format and the rules, are in
[`_shared/templates/`](_shared/templates/).

---

## When it goes wrong

Every one of these is normal. None is a reason to stop.

| Symptom | Do this |
|---|---|
| **Two weeks behind** | Don't compress — **cut**. Drop the optional cert, keep the projects. Projects convert, certs filter |
| **Week 15 burnout** | Caused by weeks 1–4, not week 15. Take three full days off, then resume at 4 hrs/day. Do not quit in the trough |
| **Tutorial paralysis** — reading feels safer than building | Close everything. Build the lab badly from blank. Badly-from-blank beats perfectly-from-tutorial, every time |
| **A concept won't land after two passes** | Weeks 1–3 have `alt/` readings — a second explanation of the same thing. Elsewhere, go to the domain's **Start here** in [`SOURCES.md`](_reference/SOURCES.md). Either way go one layer *down*, not sideways |
| **Same gate criterion failed twice** | The gap is a level below where you're looking. Kubernetes networking → Linux networking. Terraform state → the provider's API |
| **AWS bill spiked** | `bash _setup/03-teardown.sh` now, investigate after. Then fix the Monday reminder you stopped honouring |
| **No interview replies by week 20** | It is the résumé or the targeting, not your skill. [`../JOB-SEARCH.md`](../JOB-SEARCH.md) §résumé rules for career changers |
| **Lost motivation** | Re-read your week-3 blank page. The distance is the motivation, and it is invisible from the inside |

---

## What "done" looks like at week 26

- [ ] Six gates passed, each timed and cold
- [ ] Three projects shipped, each with a README a stranger can follow
- [ ] ~50 incident-journal entries
- [ ] 20+ posts
- [ ] 2–4 certifications
- [ ] A full application pipeline, running since week 14
- [ ] A folder of blank-page explanations from week 1 to week 26

That last one has no market value and is the most honest record of what you actually know. Re-reading
your week-3 page at week 26 is the fastest way to see how far you came.

---

## The card

Print this. Everything above compresses to it.

```text
DAILY     Anki 10' · blank page 20' · lab 2-5h · drills 45' · log 10'
WEEKLY    Mon orient · Tue-Thu build · Fri break/fix + redraw + ship · Sat post · Sun rest (or redraw N-2)
MONTHLY   Gate, timed and cold, then redraw every figure since the last gate.
          Fail = repeat the criterion, not the month.

RULES     70% keyboard, 30% input
          Solutions only after a genuine attempt
          Apply from week 14
          One rest day a week
          The gap is where you used a word instead of a mechanism
```
