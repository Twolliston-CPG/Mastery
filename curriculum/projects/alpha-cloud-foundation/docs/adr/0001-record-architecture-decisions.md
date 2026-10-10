# ADR-0001: Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-03-01

## Context

Interviewers at this level probe **judgment**, not tool familiarity. A record of what was rejected
and why is the cheapest way to demonstrate it. It is also genuinely useful six months later when
nobody remembers why a choice was made.

## Decision

Every non-obvious technical choice in this repo gets a short ADR in `docs/adr/`, numbered
sequentially, using the template in `_shared/templates/ADR-template.md`.

## Consequences

**Positive:** decisions are reviewable in PRs; the README's decision table links here; the "why not
X?" interview question has a written answer.

**Negative:** a small ongoing discipline cost. Mitigated by keeping ADRs short — half a page.
