# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A 26-week DevOps/DevSecOps/Platform Engineering curriculum — **not an application.** The "source" is
~360,000 lines of Markdown plus a small Python toolchain that generates and validates parts of it.
Changes are almost always *content* changes, and the risk is silent breakage across hundreds of files
rather than a failing build.

Read [`README.md`](README.md) for the program, [`curriculum/STEP-BY-STEP.md`](curriculum/STEP-BY-STEP.md)
for how a learner moves through it.

## Hard constraints

1. **Anonymize company names.** The reference library and case studies are derived from real material
   and are fully anonymized (`StreamCo`, `AudioWave`, `CraftMarket`, `IdentityCo`, `ThreatGroup-A/B`,
   `FileTransferApp`). Never reintroduce a real name, and never "fix" an anonymized URL into a working
   one — `curriculum/_reference/.linkcheck-ignore` exists because those links are *supposed* to 404.
2. **Never read or touch personal directories** outside this repo (e.g. `~/projects/taxes`).
3. **`real-projects/` figures are style references only.** Their visual language was copied; their
   content never is.

## Commands

```bash
# Validate diagrams + markdown structure across the library (~1s, no browser)
python3 curriculum/_shared/diagrams/check-diagrams.py curriculum/_reference
python3 curriculum/_shared/diagrams/check-diagrams.py            # whole repo

# Validate every external URL (~30s; honours .linkcheck-ignore)
python3 curriculum/_shared/diagrams/check-diagrams.py --links curriculum/_reference

# Regenerate the per-file Feynman self-tests (623 files, idempotent)
python3 curriculum/_shared/feynman/inject.py           # dry run FIRST
python3 curriculum/_shared/feynman/inject.py --apply

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

## Architecture

Four layers, each with a different audience:

| Layer | Purpose |
|---|---|
| Root `*.md` | Strategy — roadmap, certs, projects, job search. Read by a human deciding whether to commit |
| `curriculum/week-01…26/` | Execution. Every week is `README.md` (thesis · day plan · reading map · exit criteria) + `labs/` + `solutions/` + `assessment.md`. Weeks 4/9/13/17/21/26 are the six **gates** |
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

- **This is not a git repository.** ~1,000 content files and 34 MB of generated figures with no version
  control — worth raising before any large mechanical edit.
- Mermaid diagrams are validated against both mermaid-cli 10.9 and 11 (installed under
  `_shared/diagrams/.tools/`, gitignored).
