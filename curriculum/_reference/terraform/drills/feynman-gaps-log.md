# Gaps Log

Dated journal of "I thought I knew X." Structured entries make weekly review fast — at end of each week, topics that appear **twice** get demoted to `[ ]` shaky in `00-mastery-tracker.md`, no matter your prior confidence.

---

## Entry template — copy this

```
### YYYY-MM-DD — <short title>
**Topic:** <domain + concept, e.g. "Domain 4 / configuration_aliases">
**Source:** <flashcard / MCQ #42 / scenario 3 / teach-back on X / real error>
**What I thought:** <your incorrect or incomplete model>
**What's actually true:** <the correction, in one clear sentence>
**Why I got it wrong:** <was it jargon collision? outdated knowledge? never learned?>
**Fix action:** <which lab to redo, which domain file to re-read, which flashcard to promote>
```

---

## Entries

<!-- append newest at the bottom; date-sorted -->

### 2026-04-20 — example entry (delete after your first real one)
**Topic:** Domain 2 / `for_each` key timing
**Source:** flashcard Q ("Why does `for_each = toset([for r in aws_x.y : r.id])` fail?")
**What I thought:** any set of strings works for `for_each`
**What's actually true:** the keys must be known **at plan time**; resource IDs aren't known until apply
**Why I got it wrong:** didn't internalize plan/apply boundary when thinking about `for_each`
**Fix action:** redo `week1/day2-foreach-dynamic-meta`; add a failing case to a teach-back

---

## Weekly review block — copy to the end of each study week

```
## Week ending YYYY-MM-DD
Entries this week: <n>
Topics appearing twice (demote in tracker): <list>
Topics that keep surfacing across weeks (systemic gap): <list>
Lab/flashcard redo queue: <list>
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Entry template — copy this
- Entries
- Weekly review block — copy to the end of each study week
- Week ending YYYY-MM-DD

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Terraform manages your infrastructure."* |
| ✓ | *"`plan` is a three-way comparison: the configuration (desired), the state file (what Terraform believes it created), and a refresh against the real API (what exists). Almost every confusing result is one of those three drifting from the other two."* |

**Trace it:** `terraform apply` on one resource: config → plan → API call → state write. Then say what happens if the process dies between the API call and the state write.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [the purpose of Terraform state](https://developer.hashicorp.com/terraform/language/state/purpose) — almost every confusing result is a three-way disagreement, spelled out there.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#terraform)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
