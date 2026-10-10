# Feynman check injector

Appends a file-specific self-test to the bottom of every `.md` in `_reference/` (623 files).

```bash
python3 inject.py            # dry run — always do this first
python3 inject.py --apply    # write
python3 inject.py --revert   # strip every block
```

**Idempotent.** The block is delimited by `<!-- feynman-check -->` … `<!-- /feynman-check -->`; a
re-run replaces it rather than stacking a second copy. `--apply` after editing `targets.py` or
`domains.py` refreshes all 623 in about a second.

| File | Holds |
|---|---|
| `targets.py` | Turns a file's own H2/H3 headings into explain-targets. The `SKIP` set is the whole game — structural headings ("Executive Summary", "Cost Estimate", "Tier 1: Guided Instructions") are navigation, and asking someone to explain one is noise |
| `domains.py` | Per-domain ✗/✓ phrasing pair, trace prompt, and the one primary source. Ten domains, keyed by the top-level directory name under `_reference/` |
| `inject.py` | Assembles and writes the block; computes the relative `MASTERY.md` / `SOURCES.md#anchor` links per file depth |

## Tuning the targets

After changing `SKIP` / `SKIP_SUB`, check the result *before* applying:

```bash
python3 - <<'PY'
import sys, collections; sys.path.insert(0, ".")
from targets import pick, H1
import inject
c = collections.Counter(); n = collections.Counter()
for p in sorted(inject.ROOT.rglob("*.md")):
    if p.parent == inject.ROOT and p.name in inject.SKIP_FILES: continue
    base = inject.BLOCK.sub("", p.read_text(encoding="utf-8"))
    g = pick(base, (H1.findall(base) or [p.stem])[0])
    n[len(g)] += 1
    for x in g: c[x] += 1
print("bullets per file:", dict(sorted(n.items())))
print("unique:", len(c), "of", sum(c.values()))
print(c.most_common(15))
PY
```

**A target repeated more than ~5 times is almost certainly structural** — add it to `SKIP` and re-run.
Current baseline: 2,164 unique targets across 2,400, worst repeat 5, 579 of 623 files with a full 4.

## After applying

`domains.py` embeds external URLs, so:

```bash
python3 ../diagrams/check-diagrams.py --links ../../_reference
```
