#!/usr/bin/env python3
"""Static checks for every ```mermaid block, without starting a browser.

Two failures cost this curriculum real diagrams while it was being written, and
neither one announces itself: both produce a red error box on GitHub exactly
where the architecture should be, and both are invisible in a diff.

  1. linkStyle index past the last edge
     Mermaid numbers edges in DECLARATION order, counting edges declared inside
     subgraphs, so the index you want is rarely the one you guess. At render
     time it fails with "TypeError: Cannot set properties of undefined
     (setting 'style')" -- which names neither the file, the line, nor the index.

  2. classDef in a diagram type that has no classes
     flowchart, graph, classDiagram and stateDiagram accept classDef. A
     sequenceDiagram, gantt, journey, pie or erDiagram does not: the line is a
     parse error, and the whole diagram fails. This happens when a theme header
     meant for a flowchart is pasted above a sequence diagram -- which is
     exactly how five diagrams here broke at once.

  3. An ASCII diagram in an unlabelled fence
     A bare ``` block full of box-drawing characters is either a diagram nobody
     converted, or pre-formatted text whose alignment matters. Those need
     different treatment and look identical to a scan -- so every deliberate one
     is tagged ```text, and anything left bare is reported. Counting "how much
     is left" against a SIZE threshold is how a first pass misses every small
     diagram; this check has no size threshold.

  4. A fenced block that swallows the rest of the file
     CommonMark lets a CLOSING fence be indented up to three spaces and closes
     on the first bare fence of equal-or-greater length. So a ```markdown
     example containing an inner ```bash block ends early -- every fence after
     it is off by one, a ```mermaid block downstream is read as prose, and the
     tail of the document renders as one grey slab. The fix is a four-backtick
     outer fence. This is the failure that looks like "the diagram has a syntax
     error" when the diagram is fine.

Exit status is 0 when clean, 1 when anything failed. Advisories (a flowchart
with no theme header) are printed but do not fail the run.

Usage:
    ./check-diagrams.py [ROOT]     # ROOT defaults to the curriculum root
                                   # _reference is scanned only if you name it
"""
from __future__ import annotations

import concurrent.futures
import pathlib
import re
import subprocess
import sys
import time

# Every link form Mermaid accepts, including the OPEN ones that have no
# arrowhead -- `A --- B` and `A === B` are edges too, and they count toward the
# linkStyle index exactly like an arrow does.
EDGE_OP = re.compile(
    r"<?-{2,3}>"          # --> -->  <-->
    r"|<?={2,3}>"         # ==>      <==>
    r"|<?-\.-+>"          # -.->     <-.->
    r"|-\.-+(?![->])"     # -.-      (open dotted)
    r"|-{2,3}(?![->])"    # ---      (open)
    r"|={2,3}(?![=>])"    # ===      (open thick)
)
# Strip label bodies before counting, so an arrow inside a caption is not an
# edge -- and so the legacy `A --|text|--> B` form is one edge, not two.
LABEL = re.compile(r'\[".*?"\]|\(\[.*?\]\)|\{\{.*?\}\}|\[.*?\]|\(.*?\)|\|[^|\n]*\|')
SKIP = ("%%", "classDef", "linkStyle", "style ", "subgraph", "end", "direction", "click")

INIT = re.compile(r"%%\{.*?\}%%", re.S)
# diagram types that accept classDef / class / :::
STYLEABLE = ("flowchart", "graph", "classDiagram", "stateDiagram")


def diagram_type(body: str) -> str:
    """The declaration keyword, ignoring any %%{init}%% header above it."""
    stripped = INIT.sub("", body).strip()
    if not stripped:
        return ""
    first = stripped.splitlines()[0].strip()
    return first.split()[0] if first else ""


def count_edges(body: str) -> int:
    n = 0
    for raw in body.splitlines():
        line = raw.strip()
        if not line or line.startswith(SKIP):
            continue
        line = LABEL.sub("", line)
        ops = EDGE_OP.findall(line)
        if not ops:
            continue
        if len(ops) == 1:
            # `A --> B & C & D` fans out to one edge per target
            targets = line.split(">")[-1]
            n += targets.count("&") + 1
        else:
            # a chain `A --> B --> C` is one edge per operator
            n += len(ops)
    return n


FENCE = re.compile(r"^(?P<indent> {0,3})(?P<fence>`{3,}|~{3,})(?P<info>.*)$")


BOX_GLYPHS = "\u250c\u2510\u2514\u2518\u251c\u2524\u252c\u2534\u253c\u2500\u2502\u25bc\u25b2\u25c4\u25ba\u2550\u2551\u2554\u2557\u255a\u255d\u256d\u256e\u2570\u256f"


def check_untagged_ascii(path: pathlib.Path) -> list[str]:
    """A bare ``` block full of box-drawing characters is unfinished work.

    Deliberate pre-formatted text -- a field-position annotation, a permission
    bit layout, anything whose meaning depends on column alignment -- is tagged
    ```text. Anything still bare is a diagram that was missed, and there is no
    size threshold here on purpose: a five-step flow drawn with `\u2502` and `v` uses
    about eight glyphs, which is exactly what a generous threshold hides.
    """
    problems: list[str] = []
    lines = path.read_text(encoding="utf-8", errors="replace").split("\n")
    open_fence = info = None
    buf: list[str] = []
    start = 0
    for n, line in enumerate(lines, 1):
        m = FENCE.match(line)
        if m:
            fence, inf = m.group("fence"), m.group("info").strip()
            if open_fence is None:
                open_fence, info, buf, start = fence, inf, [], n
            elif fence[0] == open_fence[0] and len(fence) >= len(open_fence) and not inf:
                if not info and sum(b.count(c) for b in buf for c in BOX_GLYPHS) >= 4:
                    problems.append(
                        f"{path}:{start}: box-drawing characters in an unlabelled "
                        f"fence \u2014 convert it to Mermaid or markdown, or tag the "
                        f"fence ```text if the alignment is the point"
                    )
                open_fence = None
            continue
        if open_fence is not None:
            buf.append(line)
    return problems


def check_fences(path: pathlib.Path) -> list[str]:
    """Walk the file the way a CommonMark parser does, and report what breaks.

    Two findings, both fatal to whatever follows them in the document:
      * a fence that is never closed  -- the rest of the file becomes code
      * an inner fence that closes its parent -- everything after it is shifted
    """
    problems: list[str] = []
    lines = path.read_text(encoding="utf-8", errors="replace").split("\n")
    open_fence: str | None = None
    open_line = 0
    open_info = ""

    for n, line in enumerate(lines, 1):
        m = FENCE.match(line)
        if not m:
            continue
        fence, info = m.group("fence"), m.group("info").strip()

        if open_fence is None:
            open_fence, open_line, open_info = fence, n, info
            continue

        # inside a block: only a bare fence of the same char and >= length closes
        if fence[0] == open_fence[0] and len(fence) >= len(open_fence) and not info:
            if n - open_line < 3 and open_info:
                pass  # a genuinely tiny block, fine
            open_fence = None
            continue

        # an inner opener of the SAME width inside a labelled block is the trap:
        # its own closing fence will close this block instead of itself.
        if fence[0] == open_fence[0] and len(fence) == len(open_fence) and info:
            problems.append(
                f"{path}:{n}: ```{info} opens inside the ```{open_info or '(bare)'} "
                f"block from line {open_line}, and its closing fence will close "
                f"THAT block instead. Widen the outer fence to "
                f"{'`' * (len(open_fence) + 1)}."
            )

    if open_fence is not None:
        problems.append(
            f"{path}:{open_line}: ```{open_info or '(bare)'} is never closed — "
            f"the rest of the file renders as one code block"
        )

    # Box-drawing characters OUTSIDE any fence. Either a block was replaced only
    # in part -- the tail left stranded -- or a nested bare fence closed its
    # parent early. Both render as a wall of broken characters.
    open_fence = None
    for n, line in enumerate(lines, 1):
        m = FENCE.match(line)
        if m:
            fence, info = m.group("fence"), m.group("info").strip()
            if open_fence is None:
                open_fence = fence
            elif fence[0] == open_fence[0] and len(fence) >= len(open_fence) and not info:
                open_fence = None
            continue
        if open_fence is None and line.lstrip()[:1] in "\u2502\u250c\u2514\u251c" \
                and sum(line.count(c) for c in "\u250c\u2510\u2514\u2518\u251c\u2524\u252c\u2534\u253c\u2500\u2502") >= 3:
            problems.append(
                f"{path}:{n}: box-drawing characters outside any code fence — "
                f"a block was replaced only in part, or a nested fence closed "
                f"its parent early"
            )
            break
    return problems


def check(path: pathlib.Path) -> tuple[list[str], list[str]]:
    problems: list[str] = []
    advisories: list[str] = []
    text = path.read_text(encoding="utf-8", errors="replace")

    for block_no, m in enumerate(re.finditer(r"```mermaid\n(.*?)```", text, re.S)):
        body = m.group(1)
        kind = diagram_type(body)
        where = (f"{path}:~{text[: m.start()].count(chr(10)) + 1} "
                 f"(mermaid block {block_no})")

        # --- 2. classDef where the grammar has no classes ------------------
        if not kind.startswith(STYLEABLE):
            for token in ("classDef ", ":::"):
                if token in body:
                    problems.append(
                        f"{where}: a {kind} block contains `{token.strip()}` — that grammar "
                        f"has no classes, so the whole diagram fails to parse. Drop the "
                        f"classDef lines; keep the %%{{init}}%% header."
                    )
                    break

        # --- 0. a multi-line %%{init}%% directive ---------------------------
        # Mermaid's own parser accepts it. Plenty of renderers do not -- they
        # detect directives line-by-line and then report a syntax error on
        # EVERY diagram in the file, which is the hardest version of this bug
        # to diagnose because nothing looks wrong with any single diagram.
        m_init = re.match(r"\s*%%\{init:", body)
        if m_init and "}}%%" not in body.split("\n")[0]:
            problems.append(
                f"{where}: the %%{{init}}%% directive spans several lines — put "
                f"it on one line. Renderers that parse directives line-by-line "
                f"fail on every diagram in the file."
            )

        # --- 2a. `classDef default` in a stateDiagram ----------------------
        # stateDiagram accepts classDef, but `default` is a reserved token in
        # that grammar and the whole diagram fails to parse.
        if kind.startswith("stateDiagram") and "classDef default" in body:
            problems.append(
                f"{where}: `classDef default` is invalid in a stateDiagram — "
                f"`default` is a reserved token there. Name the class something "
                f"else, or drop it."
            )

        # --- 2b. a semicolon inside sequence-diagram text ------------------
        # `;` is a STATEMENT SEPARATOR in a sequenceDiagram, so a semicolon in
        # the text of a message or a Note ends the statement there and the rest
        # of the sentence is parsed as syntax. It fails at render time only.
        if kind == "sequenceDiagram":
            for n, raw in enumerate(body.splitlines(), 1):
                s = raw.strip()
                if not (s.startswith("Note ") or "->>" in s or "-->>" in s):
                    continue
                if ";" in s.split(":", 1)[-1]:
                    problems.append(
                        f"{where}, line {n}: a semicolon inside sequence-diagram "
                        f"text ends the statement — Mermaid reads `;` as a "
                        f"separator. Use a dash or a comma."
                    )

        # --- 1. linkStyle index past the last edge -------------------------
        if not kind.startswith(("flowchart", "graph")):
            continue  # only flowcharts number edges
        edges = count_edges(body)
        for ls in re.finditer(r"linkStyle\s+([\d,\s]+)", body):
            idxs = [int(x) for x in ls.group(1).replace(" ", "").split(",") if x != ""]
            over = [i for i in idxs if i >= edges]
            if over and edges:
                problems.append(
                    f"{where}: linkStyle references {over} but the diagram has ~{edges} "
                    f"edges (valid: 0–{edges - 1})"
                )

        # --- advisory: a flowchart with no house theme ---------------------
        if "%%{init" not in body:
            advisories.append(f"{where}: no %%{{init}}%% theme header — see theme.mmd")

    return problems, advisories



# ---------------------------------------------------------------------------
# --links: external URL liveness.
#
# A dead link is invisible: the file still renders, the reader just lands on a
# 404 at the exact moment they needed the answer. Worse is a link that still
# returns 200 but points at a superseded version of a spec -- nothing can
# detect that, which is why the convention is to link the vendor's floating
# "latest" URL and pin a version only when the version IS the content.
# ---------------------------------------------------------------------------

# Only links a reader can actually click: markdown link targets, outside code
# fences. A URL inside a ```bash block is a config example, not a citation --
# checking those drowns the real failures in localhost and example.com.
MD_LINK = re.compile(r"\]\(\s*(https?://[^)\s]+?)\s*(?:\"[^\"]*\")?\s*\)")
FENCE_BLOCK = re.compile(r"^(?P<f>`{3,}).*?^(?P=f)\s*$", re.S | re.M)
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
# Hosts that rate-limit or block scripted requests; a 403 from these is not a
# broken link, and reporting it trains you to ignore the output.
TOLERATE_403 = ("linkedin.com", "medium.com", "reddit.com", "x.com", "twitter.com",
                "hhs.gov", "iso.org", "defense.gov", "pcisecuritystandards.org",
                "weave.works", "sans.org", "gartner.com", "gnu.org")
# Placeholders and loopback: never real citations.
SKIP_HOST = re.compile(
    r"^(localhost|127\.|0\.0\.0\.0|\[?::1|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)"
    r"|(^|\.)(example|test|invalid|local|internal|localdomain)(\.|$)"
    r"|(^|\.)(example\.com|example\.org|example\.net|yourdomain|mycompany|acme)(\.|$)",
    re.I)


def _host(url: str) -> str:
    m = re.match(r"https?://([^/?#]*)", url)
    return (m.group(1).split("@")[-1] if m else "").lower()


def load_ignores(root: pathlib.Path) -> list[str]:
    """Substrings to skip, from .linkcheck-ignore at the root of the scan.

    Case-study hosts are deliberately anonymised, so they are SUPPOSED to be
    unresolvable. Without this the report is mostly noise and stops being read.
    """
    f = root / ".linkcheck-ignore"
    if not f.exists():
        return []
    return [ln.strip() for ln in f.read_text(encoding="utf-8").splitlines()
            if ln.strip() and not ln.startswith("#")]


def collect_urls(root: pathlib.Path) -> dict[str, list[str]]:
    """Clickable external URLs under root, mapped to the files that cite them."""
    ignores = load_ignores(root)
    seen: dict[str, list[str]] = {}
    for md in sorted(root.rglob("*.md")):
        if "node_modules" in md.parts or "_out" in md.parts:
            continue
        body = FENCE_BLOCK.sub("", md.read_text(encoding="utf-8", errors="replace"))
        for raw in MD_LINK.findall(body):
            u = raw.rstrip(".,;:")
            host = _host(u)
            if not host or SKIP_HOST.search(host) or "{" in u or "<" in u:
                continue
            if any(pat in u for pat in ignores):
                continue
            seen.setdefault(u, []).append(str(md.relative_to(root)))
    return seen


def probe(url: str, tries: int = 2) -> tuple[str, str]:
    """curl the URL. Retried once, because a transient 000 is a false report
    and a checker that cries wolf stops being run."""
    code = "ERR"
    for attempt in range(tries):
        try:
            out = subprocess.run(
                ["curl", "-sS", "-L", "-o", "/dev/null", "-w", "%{http_code}",
                 "--max-time", "20", "-A", UA, url],
                capture_output=True, text=True, timeout=30)
            code = out.stdout.strip() or "ERR"
        except Exception:
            code = "ERR"
        if code not in ("000", "ERR"):
            break
        if attempt + 1 < tries:
            time.sleep(1.5)
    return url, code


def check_links(root: pathlib.Path, jobs: int = 10) -> int:
    urls = collect_urls(root)
    if not urls:
        print("no external links found")
        return 0
    print(f"checking {len(urls)} unique URL(s) across {root} …")
    bad: list[tuple[str, str, list[str]]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as ex:
        for url, code in ex.map(probe, urls):
            if code.startswith("2"):
                continue
            host = _host(url)
            if code == "403" and any(h in host for h in TOLERATE_403):
                continue
            bad.append((code, url, urls[url]))

    if not bad:
        print(f"\033[32mOK\033[0m  {len(urls)} URLs, all reachable")
        return 0

    print(f"\033[31m{len(bad)} unreachable URL(s)\033[0m\n")
    for code, url, files in sorted(bad):
        print(f"  {code}  {url}")
        head = files[:3]
        more = f"  (+{len(files) - 3} more)" if len(files) > 3 else ""
        print(f"        cited by: {', '.join(head)}{more}")
    print("\n  A 200 does not mean current. Prefer the vendor's floating URL\n"
          "  (.../latest/...) and pin a version only when the version is the content.")
    return 1


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if not a.startswith("--")]
    flags = {a for a in argv[1:] if a.startswith("--")}
    explicit = bool(args)
    root = pathlib.Path(args[0]) if explicit else \
        pathlib.Path(__file__).resolve().parents[3]   # the mastery root

    if "--links" in flags:
        return check_links(root)
    problems: list[str] = []
    advisories: list[str] = []
    scanned = 0
    for md in sorted(root.rglob("*.md")):
        # _reference is skipped on a default run (it is curated third-party
        # material); pass it explicitly to check it too.
        if not explicit and "_reference" in md.parts:
            continue
        if "_out" in md.parts or "node_modules" in md.parts:
            continue
        scanned += 1
        p, a = check(md)
        problems += p + check_fences(md) + check_untagged_ascii(md)
        advisories += a

    if problems:
        print(f"\033[31m{len(problems)} problem(s)\033[0m\n")
        for p in problems:
            print(f"  {p}")
        if any("linkStyle" in p for p in problems):
            print(
                "\n  Edges are numbered in DECLARATION order, including edges declared\n"
                "  inside subgraphs. Count from the top of the diagram."
            )
        return 1

    print(f"\033[32mOK\033[0m  {scanned} files, no diagram errors")
    if advisories:
        print(f"\n  {len(advisories)} advisory:")
        for a in advisories[:20]:
            print(f"    {a}")
        if len(advisories) > 20:
            print(f"    … and {len(advisories) - 20} more")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
