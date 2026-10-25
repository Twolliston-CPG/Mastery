# Week 30 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (30.2 to 30.6). Read a lab's figure
> before you start it; redraw it after.

> **Exam facts used in this file are planning estimates.** Two hours, about 15 to 20 weighted tasks,
> pass mark 66 %, results within 24 hours, one free retake, a certificate valid two years. Confirm
> every one of them in the candidate handbook at registration.

---

# Lab 1 — killer.sh Session 2: the Gate 7 Attempt (Mon, 3h)

The second session is the predictor. The first one, in week 29, was a diagnosis; this one is a
rehearsal under the exact rules of the gate.

## The rules of the gate

1. Start when you can give it two uninterrupted hours and come back the next day for the solutions.
2. Exam conditions: the ritual from figure 29.2, the triage order from figure 29.6, no notes, no
   shell history, the docs only.
3. **The solutions stay closed until the timer stops.** Opening them during the attempt voids the
   gate, whatever the score.
4. Score it. Log the score, the minutes left, and the missed tasks by family in the journal.

## The gate

| Result | Means |
|---|---|
| At or above the pass mark, inside two hours, solutions closed | **Gate 7 passed.** Sit the exam as booked |
| Below the pass mark by a few points | Sit the exam as booked. The simulator is harder than the exam by design; a near miss here is the usual story of a pass there. Tuesday and Thursday work the two families that cost the points |
| Well below, or more than a third of the tasks untouched | Move the exam one week, today, while the booking window still allows it; run weeks 27 and 28's labs for the two weakest domains again; retake this gate next Monday |

The third row is not failure. A fail on the real exam during an active job search costs more than a
week; the free retake is for a surprise, not for a predicted miss.

## The remaining access window

The same discipline as week 29: every missed or guessed task from the solution, reset, redone from
the task text, twice for the ones that surprised you. Write down which docs page each one needed.
Those pages are Thursday evening's reading.

---

# Lab 2 — Weak-Domain Drills (Tue and Thu, 3h each)

[`MOCK-EXAM-2.md`](MOCK-EXAM-2.md) is three sets of eight tasks, forty minutes each, one set per
family group:

| Set | Family | For the candidate whose misses were |
|---|---|---|
| A | Troubleshooting: application, control plane, node, networking | the thirty-percent domain |
| B | Cluster architecture and storage: kubeadm, etcd, certificates, upgrades, RBAC, PV and PVC, StorageClass | the install-and-configure and storage domains |
| C | Services, networking and workloads: Service types, Ingress, Gateway API, NetworkPolicy, DNS, rollouts, scheduling, Jobs, Helm, Kustomize | the three remaining domains |

Tuesday is your weakest family's set, run **three times**: once cold, once after reading the
solutions, once the next morning before anything else. Thursday is the second family, same three
runs. The number that matters is the third run's time, not the first run's score.

Each set needs the kubeadm cluster with the week-29 `shop` namespace seeded
(`week-29/solutions/SOLUTIONS.md`, `seed.sh`). `solutions/mock-exam-2-setup.sh A` plants Set A's
breaks; `B` and `C` create the two objects those sets assume. A partner runs it.

**Between runs:** redraw the lab figure for the family (29.3 for Set A, 27.2 to 27.5 for Set B,
28.2 to 28.6 for Set C). The figure is the retrieval; the set is the application.

---

# Lab 3 — The Exam Checklist (Thu evening, 1h)

Run this once on Thursday as a rehearsal, then again on exam morning. Every item is something a
candidate has lost an attempt to. Confirm the current rules in the candidate handbook and the
technical requirements page; they change, and the handbook wins over this list.

## The week before (already done, check it)

- [ ] Exam booked for Friday or Saturday of this week, confirmation email found, time zone checked twice
- [ ] The PSI secure browser installed and its system check passed on **the machine you will use**, on **the network you will use**
- [ ] Government ID whose name matches the registration exactly, not expired
- [ ] killer.sh session 2 done (Lab 1)

## The room and the desk

- [ ] A room with a door that closes. Nobody enters for two and a half hours; tell them
- [ ] The desk cleared: no papers, no second monitor unless the handbook allows it, no phone within reach
- [ ] The walls and the desk surface visible for the room scan; the proctor will ask for a 360° view
- [ ] A clear glass of water is usually allowed; check. Nothing else to eat or drink
- [ ] Headphones off, notifications off, every other application closed, the laptop on power

## The check-in

- [ ] Log in thirty minutes early. Check-in involves ID photos, the room scan, and a wait
- [ ] The proctor communicates by chat. Keep the chat visible
- [ ] Once the exam starts, the clock runs even if you are still arranging windows

## The first five minutes, inside the exam

- [ ] Aliases, `$do`, the `.vimrc`: figure 29.2, badges ③ and ④, from memory
- [ ] Read every task once with the weights; mark each: know it, maybe, no idea (figure 29.6, badge ①)
- [ ] The order written in the notes pane

## Every task

- [ ] The context line, `use-context`, `current-context` out loud
- [ ] The end state written as a command before the first edit
- [ ] Two minutes with no progress: flag and move on
- [ ] Verify by command, one line in the notes

## 1:50

- [ ] Nothing new. Flags, then every end-state command rerun

## If something breaks

- [ ] The remote desktop freezes or the terminal dies: tell the proctor in the chat **immediately**, with the time. Do not reboot, do not close the browser; the proctor can pause and restore the session, and the chat log is the record
- [ ] Your network drops: reconnect, reopen the secure browser; the session usually resumes. Note the time lost and tell the proctor
- [ ] The proctor asks you to do something (show the desk again, move the camera): do it at once; arguing costs time and can end the session

## The day before

- [ ] No new material. One run of Tier 4 of the speed drill, one read of figures 29.2 and 29.6, and stop by early evening
- [ ] Sleep. The literature on this is not subtle: a short night costs more points than a day of study buys

---

# Lab 4 — Exam Day (Fri or Sat)

## Morning

- Eat. Water on the desk. Thirty minutes early at the laptop with the checklist from Lab 3 open.
- Say the ritual once, out loud, before the check-in: context, end state, generate, edit, apply,
  verify, note.
- Say the triage rules once: bank, two minutes, long ones in the middle, nothing new after 1:50.

## In the exam

Everything is figures 29.2 and 29.6. There is nothing else to think about, which is the point of
having drilled them.

## Within an hour afterwards

Before the result, while it is fresh, write the note to self in the journal:

- Which tasks felt like the simulator, which did not
- The task you spent longest on, and whether the two-minute rule would have saved it
- The docs lookups that took over thirty seconds
- Any wrong-context moment, caught or not
- One line: what you would tell yourself on Thursday evening

Then close the laptop. The result arrives within about 24 hours (confirm in the handbook); refreshing
the page does not shorten that.

---

# Lab 5 — After (Sun, 2h)

## The result

**Pass.** The same day: the certificate's verification link into the résumé's certifications line
and the LinkedIn certifications section, with a short post that says what the preparation actually
was (the kubeadm cluster, the twelve breaks, two simulator sessions), not just the badge. Update the
tracker; every open application with a Kubernetes mention gets a one-line follow-up.

**Fail.** The same day: book the free retake for two weeks out, before the disappointment turns into
avoidance. Read the score report's domain breakdown. Name the two weakest domains and the week that
rebuilds each (27 for cluster architecture and node troubleshooting, 28 for workloads, networking and
storage, 29 for speed). Those two weeks' labs, done again from the lab text with the figures closed,
are the next two weeks' lab hours; Mock Exam 2's sets are the check before the retake. Nothing else
changes: the cadence continues, the applications go out, and the retake is a date on the calendar,
not a verdict.

## The retrospective, either way

Three questions, in the journal:

1. **What did the simulator predict correctly?** The families, the pace, the docs lookups.
2. **What did it not predict?** The remote desktop's lag, the check-in, the thing you froze on.
3. **Which figure saved the most time?** That figure is the one to keep redrawing monthly; the
   rest can rest.

## The CKS decision

`ROADMAP.md` §8 puts CKS in year two: it assumes CKA and operating experience, and the hours it
would take belong to interviewing and building now. Two things override that. A target employer's
postings naming CKS by name, or the first job turning out to be security-platform work. Otherwise
write "CKS: revisit at month 12" in the plan and move on.

## Week 31

Monday is the week-26 cadence again: twenty hours interviewing, ten building, ten on preparation and
people. The kubeadm nodes: `terraform apply -var kubeadm_nodes=0` in `_setup/gcp-lab/` unless the
retake needs them. The figures from weeks 27 to 30 join the monthly redraw rotation; the exam, passed
or booked, becomes a line in the STAR story about learning something hard on a deadline.
