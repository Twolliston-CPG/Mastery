# Start Here

> Day one. Do these in order. It takes about two hours and everything afterwards depends on it.

---

## 1. Understand what you signed up for

Read, in this order:

1. **[`../ROADMAP.md`](../ROADMAP.md)** — the strategy. Especially §1 (honest framing) and §2 (the
   nine recommendations). Twenty minutes, and it decides how you spend the next six months.
2. **[`../CERTIFICATIONS.md`](../CERTIFICATIONS.md)** §4 — pick a track today. A, B, or C.
3. **[`../JOB-SEARCH.md`](../JOB-SEARCH.md)** §3 — the pipeline math. Read it **now**, before the
   rejections start, so you know 97-of-100 going nowhere is the expected outcome and not a verdict on
   you.

---

## 2. The week-1 market check (30 minutes, decides two things)

Open 30 job postings for your target titles, in your actual market. Then answer:

| Question | If yes |
|---|---|
| Is the market visibly **Azure**-dominant? | Swap AWS for Azure wholesale — AZ-104 instead of SAA. Do **not** attempt both. |
| Do many postings mention a **clearance**, "DoD 8570," or **Security+**? | Add Security+ around weeks 20–24. |
| Does **Backstage** appear repeatedly? | Use Backstage for Project Charlie in week 22 rather than building. |

**Decide once and don't revisit.** Re-litigating this in month 3 costs a month.

---

## 3. Set up the environment

```bash
cd curriculum/_setup
bash 00-toolchain.sh        # installs everything (macOS or Debian/Ubuntu)
# Fuller, self-contained alternatives with a --check mode:
#   bash macos-setup.sh      macOS
#   bash linux-setup.sh      Debian/Ubuntu (incl. WSL 2) or Arch
bash verify.sh              # confirms it
```

The labs in weeks 1–4 run on a Linux VM. Ubuntu is the documented default; there is also an Arch
path on a GCP VM. Pick one before Week 1 — [`_setup/DISTRO.md`](_setup/DISTRO.md).

Do **not** create any AWS resource before week 5, and when you do, run the guardrails script first:
```bash
EMAIL=you@example.com bash 01-aws-guardrails.sh
```
Budget alarms at $25/$50/$100, root MFA, no root keys. **Then put a recurring Monday calendar
reminder: "check AWS bill."** For 26 weeks. A surprise $400 bill in week 6 ends programs.

---

## 4. Create the three tracking artifacts

```bash
mkdir -p ~/mastery/progress && cd ~/mastery && git init
touch progress/progress.md progress/incident-journal.md progress/decisions.md
```

These are the program's instrumentation, and they double as interview material.

**`progress.md`** — one row per week: week, focus, deliverable shipped (y/n), gate status, hours
logged, and **"what surprised me."** That last column is the highest-value field in the whole system.

**`incident-journal.md`** — every break/fix. Symptom → hypothesis → confirmation → root cause → fix →
prevention → **surprised**. Target ~50 entries by week 26. This becomes your STAR story bank.

**`decisions.md`** — a lightweight ADR log for every non-obvious choice across the three projects.

---

## 5. Buy a domain (~$12/year)

Namecheap, Porkbun, or Cloudflare Registrar. You'll use it for TLS in week 3, Route 53 in week 7,
ALB certificates in week 13, and Ingress in weeks 16 and 23.

**It is the best $12 in the program.**

---

## 6. Import the Anki decks

```
Anki → File → Import → curriculum/_shared/anki/*.tsv
       separator: Tab   type: Basic   fields: Front, Back, Tags
```
Review daily from day one. **Missing days is what kills spaced repetition** — the backlog compounds
and then you quit.

---

## 7. The rules that make this work

### The 70/30 rule
**70% keyboard, 30% input.** Watch or read something once, then rebuild it from a blank file with
only the official docs. If you can't start from blank, you haven't learned it. This is the single
highest-leverage decision in the program.

### The daily blank page (20 minutes)
Write one idea on a blank page and explain it to a competent engineer who has never used the tool.
No notes, under five minutes, no jargon you can't define on the spot.

**The gap is not what you forgot — it's where you used a word instead of a mechanism.** "It handles
service discovery" is a gap. Go read *only* that, then rewrite from memory.

Full protocol, the three levels of knowing, and ten mechanism traces:
[`_reference/MASTERY.md`](_reference/MASTERY.md).

### Break/Fix Friday
Every Friday: break something deliberately, diagnose it under a timer, **narrate out loud** as if an
interviewer is listening. Log it. By week 26 you'll have done this ~50 times, and *"how would you
debug this?"* stops being scary.

### One rest day per week
Not a deviation from the plan — **part of it.** 26 weeks is won on sustainability. Week 15 is where
people burn out, and it's caused by weeks 1–4.

### Write one post a week
500–1,200 words on what you built or broke. 20+ by week 26. Cheapest credibility multiplier there is,
and it doubles as retrieval practice.

### Apply from week 14
Not week 26. The pipeline has a 6–10 week lag. **The instinct to wait until you "know Kubernetes" is
the single most common way this program fails.**

---

## 8. Your first week

**Read [`STEP-BY-STEP.md`](STEP-BY-STEP.md) now** — it is the operating manual for everything after
today: what an ordinary study day looks like block by block, how a week runs Monday to Sunday, how
the six gates work, and what to do when you fail one or fall behind. Fifteen minutes, and it is the
difference between having a plan and running one.

```bash
cd curriculum/week-01
cat README.md
```

Then start with [`week-01/labs/lab-01-environment.md`](week-01/labs/lab-01-environment.md).

---

## One last thing

Open the solutions only after a genuine attempt. **Reading a solution feels like learning and
isn't** — recognition is not retrieval, and only retrieval survives an interview.

Good luck. See you at Gate 1.
