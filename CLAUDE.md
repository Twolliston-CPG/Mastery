# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A 26-week DevOps/DevSecOps/Platform Engineering curriculum — **not an application.** The "source" is
~360,000 lines of Markdown plus a small Python toolchain that generates and validates parts of it.
Changes are almost always *content* changes, and the risk is silent breakage across hundreds of files
rather than a failing build.

Read [`README.md`](README.md) for the program, [`curriculum/STEP-BY-STEP.md`](curriculum/STEP-BY-STEP.md)
for how a learner moves through it.

## Status

<!-- Keep this current. Overwrite it, don't append — history is in `git log`. Updated 2026-10-17. -->
- **Git:** repo initialised 2026-10-10 on `main`; remote `origin` added and pushed (see next bullet). Last full review 2026-10-17 (setup scripts, guardrails, link integrity, anonymization residue; all commits on `main`). Repo-local identity
  "Sergino Delia" with the GitHub email (not the personal one).
- **GitHub repo:** live and private at `github.com/SerginoDelia/twots` (remote `origin`, `main` tracks it,
  pushes work as of 2026-10-17). `infra/github/` now names the same repo (`twots`) and `imports.tf` adopts it
  and its four settings resources on the first apply. **That apply has not run** (needs the fine-grained PAT);
  the plan must show 5 to import, 0 to add, 0 to destroy before applying.
- **Flags still off:** `enable_rulesets` (needs GitHub Pro), `require_signed_commits` (needs SSH signing).
- **Unknown:** GitHub plan (Free vs Pro). Username is `SerginoDelia`.
- **Unverified on a live system (2026-10-17):** Contour on kind (`02-kind-cluster.sh`), OS Login on the
  Ubuntu GCP lab image, `windows-setup.ps1`, the `figures-fresh` CI job, and all four `security.yml` jobs
  (every one passes locally; `gh` is not authenticated here, so runner results have not been seen). A job
  joins `required_status_checks` only after it has run green on the runner; the full target list is in
  `infra/github/terraform.tfvars.example`.
- **Next:** merge the open PR once `ci` + `security` are green on the runner → export `GITHUB_TOKEN`, `terraform
  plan` in `infra/github/` (5 imports, nothing to add) and apply → put the full `required_status_checks` list in
  `terraform.tfvars` → `terraform apply -var enable_rulesets=true` (needs Pro; Free returns 403).

## Where state lives

| Kind of information | Where |
|---|---|
| Stable rules, layout, invariants, commands | This file |
| Current stage, blockers, next step | `## Status` above (short, dated, overwritten) |
| What changed and why | `git log` — commit messages carry the rationale |
| Facts that cut across folders (identities, rates, preferences stated mid-session) | Claude's auto-memory |
| Pre-git snapshots | `_backups/*.tar.gz` (gitignored; safe to delete once the remote exists) |

Don't put dates, versions, or blockers anywhere but `## Status` — they go stale everywhere else.

## Hard constraints

1. **Anonymize company names.** The reference library and case studies are derived from real material
   and are fully anonymized (`StreamCo`, `AudioWave`, `CraftMarket`, `IdentityCo`, `ThreatGroup-A/B`,
   `FileTransferApp`). Never reintroduce a real name, and never "fix" an anonymized URL into a working
   one — `curriculum/_reference/.linkcheck-ignore` exists because those links are *supposed* to 404.
2. **Never read or touch personal directories** outside this repo (e.g. `~/projects/taxes`).
3. **`real-projects/` figures are style references only.** Their visual language was copied; their
   content never is.
4. **Only `mastery/` goes to GitHub** (as the repo `SerginoDelia/twots`). The parent `serge/` workspace holds résumés with PII and is not a
   git repo; never `git init` it, never add it as a remote, never copy files from it into here.

## Commands

```bash
# Validate diagrams, markdown structure, and relative links (~1s, no browser)
python3 curriculum/_shared/diagrams/check-diagrams.py curriculum/_reference
python3 curriculum/_shared/diagrams/check-diagrams.py            # whole repo

# Validate every external URL (~30s; honours .linkcheck-ignore)
python3 curriculum/_shared/diagrams/check-diagrams.py --links curriculum/_reference

# Regenerate the per-file Feynman self-tests (623 files, idempotent)
python3 curriculum/_shared/feynman/inject.py           # dry run FIRST
python3 curriculum/_shared/feynman/inject.py --apply

# Re-render the ten lab-platform figures for curriculum/_setup/ARCHITECTURE.md (diagrams lib + graphviz)
python3 curriculum/_shared/diagrams/generate-setup-figures.py

# Re-render the 26 weekly figures + their content/FIGURE.md scripts + README sections (same toolchain)
python3 curriculum/_shared/diagrams/generate-week-figures.py            # --only 14 for one week
python3 curriculum/_shared/diagrams/generate-week-figures.py --docs-only # what CI runs: FIGURE.md + README only
pip install -r curriculum/_shared/diagrams/requirements.txt             # pinned diagrams/graphviz for both generators

# Re-render + re-embed Mermaid diagrams as PNGs into the .md files
python3 curriculum/_shared/diagrams/embed-figures.py --apply
python3 curriculum/_shared/diagrams/embed-figures.py --revert   # strip images, keep Mermaid

# Actually render every diagram through mermaid-cli and report failures.
# Slow (minutes, launches a browser) — the ground truth check-diagrams.py approximates.
bash curriculum/_shared/diagrams/render.sh           # curriculum only, fast path
bash curriculum/_shared/diagrams/render.sh --all     # include _reference/
JOBS=10 bash curriculum/_shared/diagrams/render.sh --all --png   # + PNGs to _out/ to eyeball
```

`render.sh` takes only `--all` and `--png` (no `--help`); parallelism is the `JOBS` env var.
mermaid-cli installs into `_shared/diagrams/.tools/`, never globally.

**After any edit under `curriculum/_reference/`, run both checkers.** They are the only thing standing
between a small edit and 600 quietly-broken files.

## Repo-as-code and guardrails

| Piece | What it does |
|---|---|
| `infra/github/` | Terraform (`integrations/github`) that creates and hardens the private repo: squash-only, Dependabot, GitHub-authored actions only, archive-on-destroy, opt-in `main` ruleset. State is local and gitignored. Bootstrap pattern: the config lives inside the repo it creates |
| `.github/workflows/ci.yml` | `secrets-scan` (gitleaks, pinned + sha256-checked, full history), `content-checks` (`check-diagrams.py` on the authored layers, then on `_reference/`), `terraform-validate` (`fmt -check` repo-wide, `init -backend=false` + `validate` on all nine root modules, in one job so the check name is stable), `figures-fresh` (weekly-figure docs regenerated from the specs must match what is committed). The first three job names are the required checks in `rulesets.tf` — rename in both places or never; `figures-fresh` is deliberately not required until it has been seen green on the runner |
| `.github/workflows/security.yml` | `actions-lint` (actionlint + zizmor on the workflows), `shell-lint` (shellcheck on every tracked `.sh`), `iac-scan` (checkov + trivy on the **whole repository**, teaching projects and solutions included, all blocking). Tools pinned by version and sha256; only GitHub-authored actions, as `actions.tf` demands. Also runs weekly against `main` |
| `.github/workflows/links.yml` | Weekly external link check |
| `.checkov.yaml`, `.trivyignore.yaml` | Scanner config. Suppressions live on the resource they excuse, with the reason: Terraform uses `# checkov:skip=...: reason` inside the block and `#trivy:ignore:AVD-...` directly above it; Kubernetes uses `checkov.io/skipN: ID=reason` annotations. trivy has no inline form for YAML, so those few go in `.trivyignore.yaml` scoped to one file. `.checkov.yaml` holds frameworks and skip-paths only; skip-path patterns are relative to the scanned directory |
| `.github/PULL_REQUEST_TEMPLATE.md`, `.github/CODEOWNERS` | The human half of the review requirements: author checklist (anonymization, PII, decoded allowlist entries, pinned actions) and ownership of the token-bearing paths. Policy summary: `infra/github/README.md` → "Review requirements" |
| `.pre-commit-config.yaml` | gitleaks, private-key, large-file (5 MB), yaml/json, shellcheck, `terraform fmt` on every root, `check-diagrams.py` on changed `.md`; a **pre-push** hook refuses a direct push to `main`. **No formatters on purpose** — a fixer would rewrite ~1,000 files |
| `.gitleaks.toml` | Allowlist for documented placeholder secrets in the reference library |

Rules:

- `pre-commit install` once per clone (installs the commit and push hooks). If a hook fails, fix the cause;
  don't `--no-verify`. Changes reach `main` through a pull request, never a direct push.
- A new scanner exception goes on the resource it excuses, with the reason (see the table above for the
  form per tool). Never add a `skip-check` to `.checkov.yaml`. Teaching solutions are scanned to the same
  bar as the real infrastructure: a finding there is either fixed in the solution or explained on it.
- A new gitleaks hit: decode it and confirm it is a placeholder **before** adding it to `.gitleaks.toml`.
- The gitleaks version is pinned in two places (`ci.yml` env and `.pre-commit-config.yaml` rev). Bump both.
- Tokens are shell env only (`GITHUB_TOKEN`); never in `.tf`, `.tfvars`, or this file.
- Commit messages explain *why*; the Status block above is the only other place state is recorded.

## Architecture

Four layers, each with a different audience:

| Layer | Purpose |
|---|---|
| Root `*.md` | Strategy — roadmap, certs, projects, job search. Read by a human deciding whether to commit |
| `curriculum/week-01…26/` | Execution. Every week is `README.md` (thesis · **Figure W.1**, always the first H2 · day plan · reading map · exit criteria) + `content/` (the figure as PNG/SVG and `FIGURE.md`, its numbered spoken script) + `labs/` + `solutions/` + `assessment.md`. Weeks 4/9/13/17/21/26 are the six **gates**. `curriculum/FIGURES.md` indexes the figures and states the convention |
| `curriculum/_shared/` | Cross-cutting: 58 break/fix scenarios (`BF-01`–`BF-58`), drills, Anki, interview bank, templates, and the `diagrams/` + `feynman/` toolchains |
| `curriculum/_reference/` | 623 files of anonymized long-form material, ten domains. A **lookup, not a course** — each week's reading map names the exact files |

The coupling that matters: **week READMEs reference `_reference/` files by path.** Renaming or moving
anything under `_reference/` breaks reading maps silently — grep the week files first.

### Generated content — do not hand-edit

Three things in `_reference/` are machine-written and will be overwritten:

- **Feynman blocks** between `<!-- feynman-check -->` and `<!-- /feynman-check -->` at the bottom of
  every file. Edit `_shared/feynman/targets.py` (heading filter) or `domains.py` (per-domain content),
  then re-run the injector.
- **Figure embeds** — the `![...](...png)` plus collapsed `<details>` source. Owned by
  `embed-figures.py`; PNGs live in `_figures/` at the repo root (476 files, ~34 MB) with a content
  hash in the filename so unchanged diagrams are never re-rendered.
- **`_reference/SOURCES.md` links** are duplicated into all 623 Feynman blocks via `domains.py`.
  Change the source there, not in the files.
- **Weekly figures** — `week-WW/content/figure-W.1-*.png|pdf`, `content/FIGURE.md`, and the
  `## The week in one figure` README section are written by `_shared/diagrams/generate-week-figures.py`
  from the specs in `_shared/diagrams/week_figures/`. Edit the spec and re-run; hand edits are overwritten,
  and CI's `figures-fresh` job fails on any that slipped through. Outputs are reproducible (PDF dates
  come from the spec's last commit), so a re-run on an unchanged spec produces no diff.

## Invariants that break silently

Each of these has already caused a repo-wide failure; `check-diagrams.py` now catches all of them.

- **The `%%{init}%%` theme header must be one line.** Multi-line directives break line-by-line parsers
  and were the cause of "syntax error on all the mermaid diagrams." Copy from `_shared/diagrams/theme.mmd`.
- **`classDef` is only legal in flowchart/graph/class/state grammars** — in `sequenceDiagram` or
  `gantt` it kills the whole diagram. `classDef default` is a parse error in `stateDiagram` (`default`
  is reserved). A `;` inside sequence-diagram text is a statement separator.
- **`linkStyle` indices count edges in declaration order, including inside subgraphs.**
- **Nested code fences.** A ```` ```markdown ```` block containing an inner ```` ```bash ```` block
  closes early and shifts every following fence in the file. Widen the outer fence to 4 backticks.
- **PNG, never SVG, for embedded figures.** Browsers do not render Mermaid's `<foreignObject>` labels
  when an SVG is loaded via `<img>`.
- **A bare ``` block full of box-drawing characters is unfinished work**, at any size — a five-step
  ASCII flow uses ~8 glyphs. There is deliberately no size threshold on that check.
- **Every relative link must resolve.** `_reference/` was flattened from directory trees into one file
  per topic, which left ~440 links pointing at paths that no longer exist; they were rewritten or
  unlinked on 2026-10-17 and the checker now fails on any new one. Links inside code fences,
  placeholders (`{var}`, `...`, `xxx`) and `_shared/templates/` are exempt.

## Conventions

- **Two files named `SOURCES.md`, different jobs.** `curriculum/SOURCES.md` is the provenance and
  anonymization record; `curriculum/_reference/SOURCES.md` is the reading list. Both carry a banner
  pointing at the other.
- **Link policy:** prefer the vendor's floating-current URL (`.../latest/...`); pin a version only when
  the version *is* the content. A 200 does not mean current — a stale SLSA v1.0 link survived here for
  exactly that reason. Every link should go to a specific page, never a docs homepage.
- **ASCII art is not automatically a diagram.** Tables → Markdown tables; framed prose → prose; trees →
  nested lists; exercise specs → headings + real code fences. Only flows and topologies become Mermaid,
  and that conversion is done **by hand** — `deascii.py` classifies, it does not translate semantics.
- Prose voice throughout is direct and specific; mechanism over vocabulary. See
  `curriculum/_reference/MASTERY.md` for the standard the content is held to.

## Notes

- **Git repo since 2026-10-10.** ~1,000 content files and 34 MB of generated figures; a mechanical edit is
  now reversible, but still state the blast radius (file count) before running one, and commit before and
  after so the diff is reviewable.
- Mermaid diagrams are validated against both mermaid-cli 10.9 and 11 (installed under
  `_shared/diagrams/.tools/`, gitignored).
