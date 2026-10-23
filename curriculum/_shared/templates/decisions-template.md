# Decisions

> A lightweight ADR log: one row for every non-obvious choice across Alpha, Bravo, and Charlie.
> The column that matters is **alternatives rejected, and why** — that is the staff-level signal in
> an interview, and it is the first thing you forget. Lives at `~/mastery-progress/progress/decisions.md`.

| Date | Week | Project | Decision | Alternatives rejected, and why | Revisit when |
|---|---|---|---|---|---|
| 2026-01-01 | 11 | alpha | Remote state in S3 with native lockfile | DynamoDB lock table: an extra resource for a single-operator repo; local state: no recovery | A second operator joins |
| | | | | | |

- One row at the moment of the decision, not at the end of the week. Memory rewrites the reasons.
- A decision big enough to need a page gets a full ADR from `ADR-template.md` in the project's
  `docs/adr/` folder; link it from the row.
- "Revisit when" is a condition, not a date. A decision with no revisit condition is a belief.
