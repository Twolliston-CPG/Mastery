# Week 30 Solutions

Mock exam 2: [`MOCK-EXAM-2-SOLUTIONS.md`](MOCK-EXAM-2-SOLUTIONS.md) and its setup script
[`mock-exam-2-setup.sh`](mock-exam-2-setup.sh) (`A`, `B` or `C`).

---

## Lab 1 — Scoring the gate

The simulator reports a score and shows, per task, which checks passed. The gate's three numbers:

| Number | Where | Why it is logged |
|---|---|---|
| score | the simulator's result page | at or above the pass mark is the gate |
| minutes left | your timer, not the simulator's | under five minutes left with tasks unflagged means the triage order needs work more than the knowledge does |
| misses by family | your tally against figure 29.3's four families and the five domains | the two highest counts are Tuesday and Thursday |

The honest-read table from the lab: a near miss sits the exam; a wide miss moves it a week. The
booking window for moving an exam is in the handbook; it is usually possible up to a day before, but
some windows close earlier, which is why the decision is made on Monday and not Thursday.

## Lab 2 — What the third run should look like

| Set | First run, typical | Third run, target |
|---|---|---|
| A, troubleshooting | 5 to 6 of 8 in 40 min, one task abandoned | 8 of 8 in under 30 min |
| B, architecture and storage | 5 to 7 of 8, the etcd or certificate task slowest | 8 of 8 in under 32 min, the slow task under 8 |
| C, services and workloads | 6 to 7 of 8, the Gateway or Kustomize task slowest | 8 of 8 in under 30 min |

These are targets from the shape of the sets, not measurements of anyone; replace them with your own
first-run numbers and aim for the third run to beat them by a third.

## Lab 3 — The checklist, annotated

Three items account for most lost attempts, in the stories candidates tell afterwards:

1. **The system check was done on a different machine or network** than the one used on the day.
   The secure browser is particular about virtual machines, some corporate VPNs, and second monitors.
   Run the check on the exact setup, the exact network, the week before.
2. **The ID name did not match the registration.** A middle name present on one and absent on the
   other has ended sessions. Check at booking.
3. **Arriving at the start time rather than thirty minutes before.** Check-in eats the thirty
   minutes; arriving late eats the exam.

Everything else on the list is a minute saved rather than an attempt saved. Those three are the
attempt.

## Lab 4 — The note to self, an example

Written within the hour, before the result:

```
Tasks felt like the simulator: the node ones, the netpol, the storage.
Did not: the task pane layout took five minutes to get used to; the docs tab was slower than at home.
Longest: a Gateway task I did not flag at two minutes; eleven minutes. The rule would have saved eight.
Docs over 30 s: CronJob fields, the kubeadm upgrade page (used the search box instead of the term).
Wrong context: once, caught by current-context before applying.
To Thursday-me: the first five minutes matter more than you think. Read everything. Then bank.
```

## Lab 5 — The retake plan, if needed

| Score report says weakest | Rebuild with | Check with |
|---|---|---|
| Cluster Architecture, Installation and Configuration | week 27, Labs 1 to 4, figures 27.2 to 27.5 closed | Mock Exam 2, Set B, three runs |
| Troubleshooting | week 27 Lab 5 and week 29 Lab 2, all twelve breaks, timed | Mock Exam 2, Set A, three runs |
| Services and Networking · Workloads and Scheduling | week 28, Labs 1 to 4 | Mock Exam 2, Set C, three runs |
| Storage | week 15 Lab 3 and week 28 Lab 5 | Set B's storage tasks, plus Mock Exam 1 Tasks 17 and 18 |

Two weeks: the first on the two domains, the second on a full Mock Exam 1 rerun and killer.sh's
solutions (the access windows are spent, but the task text and solutions remain readable after a
session ends; confirm on the site). The retake date was booked on the day of the result; it stays.
