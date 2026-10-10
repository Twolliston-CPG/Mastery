# Lab 5 — Break/Fix Friday #1

**Time:** 2 hours · **Scenarios:** BF-01 through BF-04

> **Snapshot your VM first.** `multipass stop lab && multipass snapshot lab --name pre-bf1`
>
> **Arch path:** `gcloud compute disks snapshot lab --zone=$ZONE --snapshot-names=pre-bf1` —
> see [`_setup/DISTRO.md`](../../_setup/DISTRO.md#snapshot-stop-destroy).

## The rules

1. Read **only** the `SYMPTOM` and `BREAK` sections in `_shared/breakfix/01-linux.md`
2. Run the break command
3. **Close the file**
4. Start a timer
5. Diagnose out loud, as if an interviewer is listening
6. Open `DIAGNOSIS` only when you've solved it or you've been stuck for 20 minutes
7. Log it

## Today's four

| # | Scenario | Target time |
|---|---|---|
| BF-01 | Disk full | 15 min |
| BF-02 | Runaway CPU | 10 min |
| BF-03 | Permission denied on an executable | 10 min |
| BF-04 | Broken PATH | 5 min |

## Narrate this out loud, every time

```
1. SYMPTOM     What exactly is broken? Since when?
2. CHANGE      What changed? (resolves most real incidents)
3. HYPOTHESIS  What do I think it is, and what's the CHEAPEST test?
4. LAYERS      app -> process -> filesystem -> kernel -> network
5. CONFIRM     Prove the cause. Don't stop at correlation.
6. FIX         Smallest change that resolves it.
7. PREVENT     What makes this impossible, or at least loud, next time?
```

## Log each one

Append to `~/mastery/progress/incident-journal.md`:

```markdown
## BF-01 - Disk full  (week 1, __ min)
Symptom:
Hypothesis:
Confirmed:
Root cause:
Fix:
Prevent:
Surprised:      <-- the most valuable line. What did you not expect?
```

**The "Surprised" line matters more than the rest.** It marks the edge of your mental model. By week
26 those lines are your best interview stories.

## Bonus: BF-10 if you have time

BF-10 (deleted-but-open file) is the same trap as BF-01's footnote, isolated. It is asked in
interviews constantly and almost nobody gets it first try. Worth doing separately.
