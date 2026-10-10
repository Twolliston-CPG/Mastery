#!/usr/bin/env python3
"""Convert the mechanical ASCII blocks in the reference library to real markdown.

Not everything drawn with box characters is a diagram, and the right target is
not always Mermaid:

    ASCII table   -> a markdown table      searchable, sortable by tooling,
                                            screen-reader friendly, diffs cleanly
    framed prose  -> a heading + prose     the frame carried no information
    tree          -> a nested list, or a   the glyphs were doing bullet-point
                     table when the         duty; a list says the same thing and
                     entries are annotated  survives a proportional font
    FLOW/topology -> left alone            needs human judgment; use Mermaid

This script only touches the first two. Flow diagrams are converted by hand
because the semantics -- which arrow is the critical path, which boundary is
real -- cannot be recovered mechanically, and a bad automatic conversion is
worse than the ASCII it replaced.

    ./deascii.py --dry-run          report what would change
    ./deascii.py --apply            rewrite in place
    ./deascii.py --apply --only tables
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

BOX = "┌┐└┘├┤┬┴┼─│▼▲◄►═║╔╗╚╝"
ARROWS = ("▼", "▲", "──▶", "-->", "──>", "◄", "►", "───►", "→")

# A TREE connector, as opposed to a box border. A bottom-left corner drawn as
# `└─────┘` also starts with `└──`, so the lookahead -- not followed by another
# dash -- is the whole difference between a branch and a border.
TREE_CONN = re.compile(r"[├└]──(?!─)")


def n_branch(s: str) -> int:
    return len(TREE_CONN.findall(s))


def strip_branches(s: str) -> str:
    return TREE_CONN.sub("", s)


def n_box(s: str) -> int:
    return sum(s.count(c) for c in BOX)


def _aligned_columns(lines: list[str]) -> bool:
    """A real table has its separators in the SAME columns on every data row.

    A nested architecture diagram also has many vertical bars per line, but they
    sit at different offsets on each row. Without this check the classifier calls
    a VPC-with-subnets drawing a "table" and flattens it into nonsense -- which is
    exactly the failure mode that makes automatic conversion dangerous.
    """
    cols = [frozenset(i for i, ch in enumerate(l) if ch in "│║") for l in lines]
    cols = [c for c in cols if len(c) >= 2]
    if len(cols) < 3:
        return False
    # the column signature shared by the majority of data rows
    common = set.intersection(*(set(c) for c in cols))
    if len(common) < 2:
        return False
    agree = sum(1 for c in cols if common <= c)
    return agree >= max(3, int(0.8 * len(cols)))


def classify(b: str) -> str:
    lines = [l for l in b.splitlines() if l.strip()]
    if not lines:
        return "empty"
    # A tree: connector glyphs and no box corners. `└` is itself a tree
    # connector, so only the OTHER corners disqualify a block from being one.
    if n_branch(b) >= 3 and not any(c in b for c in "┌┐┘┬┴┼"):
        return "tree"
    # Arrows or multiple frames mean it is a drawing, whatever its bar alignment.
    if any(x in b for x in ARROWS) or b.count("┌") >= 2:
        return "flow"
    if sum(l.count("│") >= 3 for l in lines) >= 3 and ("┼" in b or "┬" in b) \
            and _aligned_columns(lines):
        return "table"
    # Strip tree connectors before counting corners: a border drawn around a
    # list still has exactly one real corner at each end.
    bare = strip_branches(b)
    if bare.count("┌") == 1 and bare.count("└") == 1:
        return "framed"
    return "other"


# --------------------------------------------------------------- tables ----
def to_markdown_table(b: str) -> str | None:
    """An ASCII table with │ separators becomes a markdown table.

    Only when the block is essentially *just* the table. Tool output that happens
    to contain a box-drawn table (a Trivy scan, a `kubectl get` with a banner and
    a totals line) keeps its fence -- the surrounding lines are part of what the
    reader is meant to see.
    """
    body = [l for l in b.splitlines() if l.strip()]
    tabular = [l for l in body if l.strip()[0] in "│┌├└┬┼┴╔╠╚║"]
    if not body or len(tabular) < 0.8 * len(body):
        return None

    rows: list[list[str]] = []
    for line in b.splitlines():
        s = line.strip()
        if not s or s[0] not in "│┌├└┬┼┴╔╠╚║":
            continue
        if set(s) <= set(BOX + " "):          # a rule line, not data
            continue
        if "│" not in s and "║" not in s:
            continue
        sep = "║" if "║" in s else "│"
        cells = [c.strip() for c in s.strip(sep).split(sep)]
        if any(cells):
            rows.append(cells)

    if len(rows) < 2:
        return None
    width = max(len(r) for r in rows)
    if width < 2:
        return None
    rows = [r + [""] * (width - len(r)) for r in rows]

    # cells must not contain a raw pipe
    rows = [[c.replace("|", "\\|") for c in r] for r in rows]

    head, *body = rows
    out = ["| " + " | ".join(head) + " |",
           "|" + "|".join(["---"] * width) + "|"]
    out += ["| " + " | ".join(r) + " |" for r in body]
    return "\n".join(out)


# ------------------------------------------------------------------ trees ----
TREE_LINE = re.compile(r"^(?P<prefix>[\u2502\s]*)(?P<conn>\u251c\u2500\u2500|\u2514\u2500\u2500)\s?(?P<rest>.*)$")
# "name   # what it does"  or  "name   (what it does)"  or  "name   what it does"
# The name may contain single spaces -- "Datadog (AWS)" is one name. The split
# is the first run of TWO or more spaces, which is what the author used to line
# the second column up.
ANNOTATION = re.compile(r"^(?P<name>\S+(?: \S+)*?)\s{2,}(?:#\s*)?(?P<note>\S.*)$")


def _tree_rows(b: str):
    """Parse a box-drawing tree into (depth, text, note) rows, or None.

    Returns None the moment a line does not fit the grammar, because a partial
    parse of a tree is a silently wrong document -- worse than the ASCII.
    """
    # A tree indented as a whole -- inside a list item, or just typed that way --
    # is the same tree. Remove the common margin before parsing depth.
    pad = min((len(l) - len(l.lstrip()) for l in b.splitlines() if l.strip()),
              default=0)
    if pad:
        b = "\n".join(l[pad:] if l.strip() else l for l in b.splitlines())
    rows = []
    for raw in b.splitlines():
        line = raw.rstrip()
        if not line.strip():
            rows.append(None)                      # a blank line separates groups
            continue
        if set(line.strip()) <= set("\u2502 "):     # a spacer line of bare pipes
            continue
        m = TREE_LINE.match(line)
        if m:
            # every level is exactly four columns: "|   " or "    "
            depth = len(m.group("prefix")) // 4 + 1
            text = m.group("rest").strip()
            if not text:
                return None
            rows.append((depth, text))
            continue
        # A line with no connector belongs at column 0 -- unless nothing after it
        # has a connector either, in which case it is a trailing note (a total,
        # a caption) and travels with the tree as prose.
        if line[0].isspace() or any(c in line for c in BOX):
            tail = b.split(line, 1)[1] if line in b else ""
            if TREE_CONN.search(tail):
                return None
            rows.append((0, line.strip()))
            continue
        rows.append((0, line.strip()))
    return [r for r in rows if r is None or r[1]] or None


def _split_note(text: str):
    m = ANNOTATION.match(text)
    if not m:
        return text, None
    return m.group("name"), m.group("note").strip()


def _code_if_pathlike(s: str) -> str:
    """A filename, a flag or a path reads better as code; a sentence does not."""
    if re.fullmatch(r"[\w./@-]+/?", s) and (
            "/" in s or "." in s or "_" in s or s.endswith("/")):
        return f"`{s}`"
    return s


def tree_to_markdown(b: str) -> str | None:
    """A box-drawing tree becomes a nested markdown list, or a table.

    The glyphs were doing bullet-point duty. A markdown list says exactly the
    same thing, is searchable, reads correctly in a proportional font, survives
    a screen reader, and diffs one entry at a time.

    When most entries carry a trailing description the shape is really a
    two-column table, and a table is the better target -- the descriptions line
    up instead of drifting.
    """
    rows = _tree_rows(b)
    if not rows:
        return None
    real = [r for r in rows if r is not None]
    if len(real) < 3:
        return None
    if max(d for d, _ in real) > 6:
        return None                                # implausible parse

    split = [(d, *_split_note(t)) for d, t in real]
    annotated = sum(1 for _, _, n in split if n)
    flat = len({d for d, _ in real}) <= 2

    # (1) a flat, annotated list is a table wearing a costume
    if flat and annotated >= max(3, int(0.6 * len(split))):
        root = [t for d, t, _ in split if d == 0]
        out = []
        if root:
            out.append(f"**{_code_if_pathlike(root[0])}**\n")
        branches = [(d, n, note) for d, n, note in split if d]
        files = sum(1 for _, n, _ in branches if re.search(r"\.[a-z]{1,5}$|/$", n))
        numeric = sum(1 for _, _, note in branches
                      if note and re.fullmatch(r"[$\u20ac\u00a3]?\s*[\d,.]+%?", note.strip()))
        left = "File" if files >= 0.6 * max(1, len(branches)) else "Item"
        right = "Value" if numeric >= 0.6 * max(1, len(branches)) else "What it is"
        out.append(f"| {left} | {right} |")
        out.append("|---|---|")
        for _, name, note in branches:
            out.append(f"| {_code_if_pathlike(name)} | {(note or '').replace('|', chr(92) + '|')} |")
        # a total or caption that followed the tree belongs under the table
        # use the ORIGINAL text, not the split name -- "Total: $4,550,000" is one
        # line, and _split_note would have torn the number off it
        zero = [txt for d, txt in real if d == 0]
        tail = zero[1:] if root else zero
        if tail:
            out.append("")
            out += tail
        return "\n".join(out)

    # (2) otherwise a nested list, with blank lines preserved as group breaks
    out = []
    last_was_branch = False
    for i, r in enumerate(rows):
        if r is None:
            last_was_branch = False
            if out and out[-1] != "":
                out.append("")
            continue
        d, text = r
        if d == 0:
            # A column-0 line is the label ABOVE a tree only when a branch
            # actually follows it. Prose that trails the tree is prose, and
            # bolding it turns an explanation into a row of shouted fragments.
            nxt = next((x for x in rows[i + 1:] if x is not None), None)
            heading = nxt is not None and nxt[0] >= 1 and not text.lstrip().startswith(("-", "*", "|"))
            if heading:
                if out and out[-1] != "":
                    out.append("")
                out.extend([f"**{_code_if_pathlike(text)}**", ""])
            else:
                # a blank line only where the tree ENDS and prose begins --
                # between two prose lines it would turn a tight list loose
                if last_was_branch and out and out[-1] != "":
                    out.append("")
                out.append(text)
            last_was_branch = False
            continue
        name, note = _split_note(text)
        out.append("  " * (d - 1) + f"- {_code_if_pathlike(name)}"
                   + (f" — {note}" if note else ""))
        last_was_branch = True
    while out and out[-1] == "":
        out.pop()
    return "\n".join(out) if out else None


# ------------------------------------------------------------------ specs ----
LABEL = re.compile(r"^(?P<label>[A-Z][A-Z0-9 /&'-]{2,30}):\s*(?P<rest>.*)$")
RULE = re.compile(r"^[\u2500\u2550]{10,}$")


def spec_to_markdown(b: str, lang: str = "python") -> str | None:
    """An exercise spec drawn with CAPS labels and rule lines becomes markdown.

        OBJECTIVE: ...            ->  **Objective** — ...
        TASKS:                    ->  **Tasks**
        1. ...                        1. ...
        STARTER CODE:             ->  **Starter code**
        ---------------               ```python
        import sys                    import sys
        ---------------               ```

    The rule lines were a poor person's code fence. Turning them into a real one
    gets syntax highlighting, a copy button, and a block a reader can paste.
    """
    lines = b.rstrip("\n").split("\n")
    labels = [l for l in lines if LABEL.match(l)]
    if len(labels) < 2:
        return None
    has_rule = any(RULE.match(l.strip()) for l in lines)
    has_tree = n_branch(b)
    if not (has_rule or has_tree):
        return None

    out: list[str] = []
    in_code = False
    for line in lines:
        s = line.rstrip()
        if RULE.match(s.strip()):
            out.append("```" + (lang if not in_code else ""))
            in_code = not in_code
            continue
        if in_code:
            out.append(line)
            continue
        m = LABEL.match(s)
        if m:
            label = m.group("label").strip()
            pretty = label[0] + label[1:].lower()
            rest = m.group("rest").strip()
            if out and out[-1] != "":
                out.append("")
            out.append(f"**{pretty}**" + (f" — {rest}" if rest else ""))
            out.append("")
            continue
        out.append(s)
    if in_code:                      # an unterminated rule -- do not guess
        return None
    out = _inline_trees(out)
    collapsed: list[str] = []
    for line in out:                 # never two blank lines in a row
        if line == "" and collapsed and collapsed[-1] == "":
            continue
        collapsed.append(line)
    while collapsed and collapsed[-1] == "":
        collapsed.pop()
    return "\n".join(collapsed)


def _inline_trees(lines: list[str]) -> list[str]:
    """Convert any directory tree sitting inside a spec, in place.

    The run starts at the line ABOVE the first connector -- that line is the
    root -- and ends at the first blank line. Indentation is preserved so a tree
    nested under a numbered step stays nested under it.
    """
    out: list[str] = []
    i = 0
    while i < len(lines):
        if not n_branch(lines[i]):
            out.append(lines[i])
            i += 1
            continue
        start = i - 1 if out and out[-1].strip() else i
        if start == i - 1:
            out.pop()
        j = i
        while j < len(lines) and lines[j].strip():
            j += 1
        run = lines[start:j]
        pad = min((len(l) - len(l.lstrip()) for l in run if l.strip()), default=0)
        converted = tree_to_markdown("\n".join(l[pad:] for l in run))
        if converted:
            out += [(" " * pad + l if l else "") for l in converted.split("\n")]
        else:
            out += run
        i = j
    return out


# ---------------------------------------------------------------- framed ----
ALIGNMENT_CHARS = "█▓▒░▄▀■□●○"


def _needs_monospace(lines: list[str]) -> bool:
    """Content whose meaning depends on column alignment must stay in a fence.

    A bar chart made of block characters, or columns held apart by runs of
    spaces, becomes unreadable the moment a proportional font touches it.
    """
    if any(c in l for l in lines for c in ALIGNMENT_CHARS):
        return True
    # Markdown reads 4+ leading spaces as a code block, so indented content
    # cannot become prose without changing how it renders.
    if any(len(l) - len(l.lstrip()) >= 4 for l in lines if l.strip()):
        return True
    multi_space = sum(1 for l in lines if re.search(r"\S {3,}\S", l))
    return multi_space >= max(3, int(0.6 * len([l for l in lines if l.strip()])))


def unbox(b: str):
    """A single frame around content carried no information. Strip it.

    Three possible outcomes, in order of preference:
      1. the content is really a table  -> a markdown table
      2. the content needs monospace    -> bold title + a plain fence, no frame
      3. otherwise                      -> bold title + prose
    """
    inner: list[str] = []
    for line in b.splitlines():
        s = line.rstrip()
        if not s:
            inner.append("")
            continue
        if set(s.strip()) <= set(BOX + " "):   # pure rule line
            continue
        s = re.sub(r"^\s*[│║]", "", s)
        s = re.sub(r"[│║]\s*$", "", s)
        inner.append(s.rstrip())

    while inner and not inner[0].strip():
        inner.pop(0)
    while inner and not inner[-1].strip():
        inner.pop()
    if not inner:
        return None

    joined = "\n".join(inner)

    # A frame whose content is itself a DRAWING is not prose. Tree connectors do
    # not count -- a border around a list is the commonest shape in this
    # library -- so strip them before testing for real box characters.
    without_tree = strip_branches(joined)
    if any(c in without_tree for c in "┌└├┬┼┤") \
            or any(a in joined for a in ARROWS):
        return None

    # (1) the frame was hiding a table
    if sum(l.count("│") >= 1 for l in inner) >= 3:
        as_table = to_markdown_table(b)
        if as_table:
            return as_table
        return None            # a partial table is worse than the original

    pad = min((len(l) - len(l.lstrip()) for l in inner if l.strip()), default=0)
    inner = [l[pad:] if l.strip() else "" for l in inner]

    title, rest = inner[0].strip(), inner[1:]
    while rest and not rest[0].strip():
        rest.pop(0)
    if not rest:
        return None

    # (1b) the frame was a border around a list
    if n_branch("\n".join(rest)):
        as_tree = tree_to_markdown("\n".join(rest))
        if as_tree:
            return f"**{title}**\n\n{as_tree}"
        return None

    # (2) alignment-dependent content keeps a fence, minus the decorative frame
    if _needs_monospace(rest):
        return f"**{title}**\n\n```\n" + "\n".join(rest).rstrip() + "\n```"

    # (3) plain prose
    return (f"**{title}**\n\n" + "\n".join(rest)).rstrip()


# ------------------------------------------------------------------ main ----
def process(path: pathlib.Path, only: str, apply: bool) -> tuple[int, int, list[str]]:
    text = path.read_text(encoding="utf-8", errors="replace")
    notes: list[str] = []
    changed = skipped = 0
    out, last = [], 0

    # The closing fence must be at the START of a line. A block that contains
    # an indented ``` -- a documentation example, a box with code drawn inside
    # it -- would otherwise be cut in half, and the tail left orphaned.
    for m in re.finditer(r"^```([a-z]*)\n(.*?)^```$", text, re.S | re.M):
        lang, b = m.group(1), m.group(2)
        # A small tree is still a tree: five branches use only 15 box glyphs,
        # which the drawing threshold alone would skip.
        if n_box(b) < 20 and n_branch(b) < 3:
            continue
        # A fence with a language is code or command output. Some Trivy/kubectl
        # output happens to contain a box-drawn table; rewriting it as markdown
        # would claim the tool prints markdown, which it does not.
        if lang not in ("", "text"):
            skipped += 1
            continue
        kind = classify(b)
        new = None
        if kind == "table" and only in ("all", "tables"):
            new = to_markdown_table(b)
        elif kind == "framed" and only in ("all", "framed"):
            new = unbox(b)
        elif kind == "tree" and only in ("all", "trees"):
            new = tree_to_markdown(b)
        elif kind == "other" and only in ("all", "specs") and new is None:
            new = spec_to_markdown(b)
        elif kind == "other" and only in ("all", "trees"):
            # A block with no frame and no arrows, but tree connectors in it, is
            # a list that was drawn instead of written.
            if n_branch(b):
                new = tree_to_markdown(b)

        if new is None:
            skipped += 1
            continue

        out.append(text[last:m.start()])
        out.append(new + "\n")
        last = m.end()
        changed += 1
        notes.append(f"      {kind} -> markdown")

    if changed and apply:
        out.append(text[last:])
        path.write_text("".join(out), encoding="utf-8")
    return changed, skipped, notes


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true", help="rewrite files in place")
    ap.add_argument("--dry-run", action="store_true", help="report only (default)")
    ap.add_argument("--only", choices=["all", "tables", "framed", "trees", "specs"],
                    default="all")
    ap.add_argument("--root", default=None)
    args = ap.parse_args(argv[1:])

    root = pathlib.Path(args.root) if args.root else \
        pathlib.Path(__file__).resolve().parent.parent.parent / "_reference"

    total_c = total_s = 0
    touched = 0
    for md in sorted(root.rglob("*.md")):
        if "node_modules" in md.parts or "_out" in md.parts or ".tools" in md.parts:
            continue
        c, s, notes = process(md, args.only, args.apply and not args.dry_run)
        total_c += c
        total_s += s
        if c:
            touched += 1
            print(f"  {md.relative_to(root)}  ({c} converted)")

    verb = "converted" if (args.apply and not args.dry_run) else "would convert"
    print(f"\n  {verb}: {total_c} blocks across {touched} files")
    print(f"  left for hand conversion (flow / tree / other): {total_s}")
    if not args.apply:
        print("\n  re-run with --apply to write the changes")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
