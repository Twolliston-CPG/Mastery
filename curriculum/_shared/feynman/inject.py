#!/usr/bin/env python3
"""Append a file-specific Feynman check to every file in the reference library.

Idempotent: an existing block is replaced, so re-running after editing a file
refreshes its targets rather than stacking a second copy.

    ./inject.py --dry-run
    ./inject.py --apply
    ./inject.py --revert
"""
from __future__ import annotations

import argparse
import os
import pathlib
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from targets import pick, H1          # noqa: E402
from domains import for_path          # noqa: E402

# _shared/feynman/inject.py -> ../../_reference
ROOT = pathlib.Path(__file__).resolve().parents[2] / "_reference"
MARK = "<!-- feynman-check -->"
BLOCK = re.compile(re.escape(MARK) + r".*?" + re.escape("<!-- /feynman-check -->") + r"\n?",
                   re.S)
SKIP_FILES = {"README.md", "MASTERY.md", "SOURCES.md"}


def block_for(md: pathlib.Path, text: str) -> str:
    rel = md.relative_to(ROOT).parts
    d = for_path(rel)
    title = (H1.findall(text) or [md.stem])[0]
    goals = pick(text, title)
    bullets = "\n".join(f"- {g}" for g in goals) if goals else f"- {title}"
    up = "../" * (len(rel) - 1) or "./"
    anchor = rel[0] if len(rel) > 1 else "kubernetes"
    return f"""{MARK}

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

{bullets}

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"{d['weak']}"* |
| ✓ | *"{d['strong']}"* |

**Trace it:** {d['trace']}

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** {d['source']}.
Full list per domain: [`SOURCES.md`]({up}SOURCES.md#{anchor})

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`]({up}MASTERY.md)

<!-- /feynman-check -->
"""


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--revert", action="store_true")
    args = ap.parse_args(argv[1:])

    files = [p for p in sorted(ROOT.rglob("*.md"))
             if not (p.parent == ROOT and p.name in SKIP_FILES)]
    added = refreshed = removed = 0

    for md in files:
        text = md.read_text(encoding="utf-8")
        had = bool(BLOCK.search(text))
        base = BLOCK.sub("", text).rstrip() + "\n"

        if args.revert:
            if had:
                removed += 1
                if args.apply or True:
                    md.write_text(base, encoding="utf-8")
            continue

        new = base + "\n" + block_for(md, base)
        if had:
            refreshed += 1
        else:
            added += 1
        if args.apply:
            md.write_text(new, encoding="utf-8")

    if args.revert:
        print(f"  removed from {removed} file(s)")
    elif args.apply:
        print(f"  added: {added}   refreshed: {refreshed}   (of {len(files)} files)")
    else:
        print(f"  would add: {added}   would refresh: {refreshed}   (of {len(files)} files)")
        print("  re-run with --apply")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
