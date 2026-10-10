# Week 24 Assessment ★ GATE 6 (first attempt)

> **Gate 6 is the stranger test.** Everything else this week supports it.

## ★ The gate

> **A person who has never seen the repo follows the README and deploys a new service via pull
> request in under 10 minutes, unaided.**

| Attempt | Person | Time | Finished? | Questions asked | Hesitations |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 (after fixes) | | | | | |

**Pass:** attempt 2 completes in under 10 minutes with zero questions answered by you.

**If nobody is available:** record yourself doing it on a fresh machine with a fresh clone, following
only the README, narrating every moment of uncertainty. It's a weaker test — you know the answers —
but the uncertainty moments are still real data.

## Deliverables checklist
- [ ] `docs/getting-started.md` — the five-minute path
- [ ] `docs/contract-reference.md` — every field
- [ ] `docs/tiers.md` — readable by a product manager
- [ ] `docs/escape-hatches.md`
- [ ] 5+ ADRs
- [ ] Runbooks per alert plus platform-specific ones
- [ ] Architecture diagram
- [ ] 5-minute demo video, including "what I got wrong"
- [ ] README: problem first, measured numbers, cost table, "what broke"
- [ ] Alpha, Bravo, Charlie pinned; profile README written; all badges green

## Part A — Written (15 min)
1. Why write `escape-hatches.md`? What does forbidding exceptions actually produce?
2. During the stranger test, why must you stay silent?
3. Map each observation to its bug: re-read a section · scrolled back · asked a question · guessed a
   value · hit an error they couldn't act on.
4. Why does the second stranger run matter?
5. Why include "what I got wrong" in the demo video? Name three things it accomplishes.
6. Why is one take fine?
7. What does a hiring manager actually see in 90 seconds on your GitHub profile?
8. State each project's claim in one sentence.

---

# Answer key

**A1.** It feels like admitting failure and is the opposite. **Forbidding exceptions produces shadow
infrastructure** — teams build what they need outside your visibility, without your security
controls, and you discover it during an incident. Documenting the exit makes exceptions visible, and
**several teams needing the same escape hatch is your roadmap.**

**A2.** Because helping destroys the data. *"Oh, that's in the other file"* means you now know they
got past that step — not that they would have. **Write every question down instead of answering it;
each one is a documentation gap.**

**A3.** Re-read → ambiguous wording · scrolled back → information in the wrong order · asked a
question → missing documentation · guessed a value → missing example or a bad default · hit an
unactionable error → **a bad error message** (the highest-value fix, because errors are the
most-read docs).

**A4.** To check you fixed the **cause** rather than the symptoms. If the second run isn't faster and
quieter, you patched the specific things one person tripped on rather than the underlying
information-architecture problem.

**A5.** (1) It **proves the project is real** — tutorial output has no scars. (2) It demonstrates
learning from failure, which is the real question behind most behavioral questions. (3) It **hands
the interviewer a question you're prepared for**. A flawless demo reads as trivial or rehearsed.

**A6.** **Fluency beats polish.** A slightly rough video where you clearly know the system is more
convincing than a rehearsed one — and the editing time is better spent on the stranger test.

**A7.** The profile README's one-line positioning · three pinned repos whose first lines are problem
statements · green CI badges · **the contribution graph**. Consistency beats intensity — a steady
24-week graph reads as discipline; three bursts read as bootcamp assignments.

**A8.** **Alpha:** *"I can build production-shaped cloud infrastructure entirely in code with no
long-lived credentials."* **Bravo:** *"I can make shipping something insecure structurally difficult —
here it is blocking a real CVE."* **Charlie:** *"I understand that a platform is a product; here's one
where a stranger self-serves in 8 minutes."*

## Scoring
| | |
|---|---|
| Gate 6 passed + deliverables complete | **Ship it. Week 25 is interviewing.** |
| Gate 6 near (12–15 min, 1–2 questions) | Fix those specific things and re-run once. Don't gold-plate. |
| Gate 6 failed (didn't finish, or many questions) | **Fix the docs before week 25.** But time-box it to two days — the interview kit matters more from here than a better README. |
