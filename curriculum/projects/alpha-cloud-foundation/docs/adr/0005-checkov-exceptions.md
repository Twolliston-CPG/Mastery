# ADR-0005: Documented checkov exceptions

- **Status:** Accepted
- **Date:** 2026-03-05

## Context

`checkov` runs as a hard gate in CI. Two checks fail on this repo for reasons that are deliberate
rather than accidental. A security gate with undocumented skips is theater; a gate with *no* skips
that people disable under deadline pressure is worse.

## Decision

Exactly two checks are skipped, each with a written justification and a review date.

| Check | What it wants | Why skipped |
|---|---|---|
| `CKV_AWS_18` | S3 access logging on every bucket | The only bucket here is the **state bucket**. Logging its access requires a second bucket, which itself needs logging, which recurses. CloudTrail data events cover it instead, and the bucket policy already denies non-TLS access. |
| `CKV_AWS_144` | S3 cross-region replication | Replicating state cross-region is real DR, but at this scale versioning plus a 90-day noncurrent retention meets the recovery objective at a fraction of the cost. **Revisit if the RPO for state ever becomes formal.** |

## Consequences

**Positive:** the gate stays hard-failing, so a *new* finding actually blocks a merge.

**Negative:** skips can silently become permanent. Mitigated by the review date and by the fact that
adding one requires a PR that edits this file — so a reviewer sees the justification, not just a
check ID.

**Review:** 2026-09-05.
