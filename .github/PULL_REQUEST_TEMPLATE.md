## What and why

<!-- One paragraph. The squash commit uses this body, so write it as the commit message. -->

## Review requirements

CI enforces the first block; the author confirms the rest, because no scanner can.

**Enforced by CI (must be green before merge)**
- `secrets-scan` · `content-checks` · `terraform-validate` · `figures-fresh` (ci.yml)
- `actions-lint` · `shell-lint` · `iac-scan` (security.yml)

**Confirmed by the author**
- [ ] No real company, product, or person name reintroduced into `curriculum/_reference/` or a case study; anonymized URLs left as they are (they are supposed to 404).
- [ ] No personal data: nothing copied in from the parent workspace, no phone/email/account IDs.
- [ ] Any new gitleaks finding was **decoded by hand** and is a placeholder before it was added to `.gitleaks.toml`.
- [ ] Any new `checkov:skip` / `trivy:ignore` comment states the reason on the resource it excuses.
- [ ] A new or bumped GitHub Action is GitHub-authored, pinned to a full commit SHA, and allowed by `infra/github/actions.tf`.
- [ ] Edits under `curriculum/_reference/`: both checkers run locally (`check-diagrams.py` with and without `curriculum/_reference`).
- [ ] Generated files (`FIGURE.md`, week README figure sections, Feynman blocks, figure embeds) were produced by their generator, not hand-edited.
- [ ] Mechanical edits: the number of files touched is stated above.

## Blast radius

<!-- Files touched, learners affected (which weeks), and what breaks if this is wrong. -->
