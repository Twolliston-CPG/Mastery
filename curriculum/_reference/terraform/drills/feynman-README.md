# Feynman Method — Terraform Pro Mastery

If you can't explain it simply, you don't understand it. This folder is the scaffold for that test.

## The loop

1. **Pick a shaky topic** from `00-mastery-tracker.md`.
2. **Teach it back** in `teach-backs/<topic>.md` as if explaining to a sharp colleague who has never touched Terraform. No jargon without definition. Use `teach-backs/_template.md`.
3. **Find the gaps.** Where did you hand-wave? Where did you blank? Log in `gaps-log.md` with the structured entry.
4. **Simplify.** Pull an analogy from `analogies.md` (or invent one and add it). Rewrite the teach-back.
5. **Verify.** Run the linked lab, answer the self-test in the domain file, redo the relevant flashcards from `/FLASHCARDS.md`. Update the tracker.

## Daily workflow (30–45 min)

- 10 min — drill 10 flashcards. Log every miss in `gaps-log.md`.
- 15 min — write or rewrite one teach-back.
- 10 min — run the lab referenced in the domain file (at minimum `terraform plan`).
- 5 min — update `00-mastery-tracker.md`.

## Weekly review

End of each study week, re-read `gaps-log.md`. Any topic that shows up twice → demote its tracker row to `[ ]` shaky, regardless of prior confidence. Repetition of ignorance is the signal.

## Files

- `00-mastery-tracker.md` — scoreboard. One row per topic.
- `domains/01..06.md` — the teacher's voice. ELI5 + analogy + gotcha + self-test per concept. Read first.
- `teach-backs/` — your voice. One file per concept, filled in by you.
- `analogies.md` — memory hooks (state = bank ledger, etc.).
- `common-confusions.md` — X vs Y tables. The near-twins HashiCorp writes trick questions around.
- `gaps-log.md` — dated journal: "thought I knew X, missed Q12, here's why."
- `exam-traps.md` — distilled patterns from the 80 MCQ answer keys.

## The rule

Never copy from `domains/` into `teach-backs/`. Close the tab. Write it cold. If you can't, that's the gap — log it.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The loop
- Daily workflow (30–45 min)
- Weekly review
- The rule

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
