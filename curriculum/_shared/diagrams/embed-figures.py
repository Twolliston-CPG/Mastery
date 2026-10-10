#!/usr/bin/env python3
"""Render each ```mermaid block to an image and embed it above the source.

WHY, and when you actually want this
------------------------------------
A ```mermaid block renders natively on GitHub and diffs as text in a pull
request. That is worth a lot, and it is why the source stays in the file. But
the block renders *client-side*, which means it can fail for reasons that have
nothing to do with your diagram:

  * GitHub pins its own Mermaid version and refuses diagrams past a complexity
    ceiling ("Unable to render rich display")
  * anything that is not GitHub -- a PDF export, a Notion paste, an offline
    clone, a recruiter's markdown preview -- may not render Mermaid at all
  * a markdown structure bug upstream in the file (see check-diagrams.py) turns
    the block into prose, which reads to a viewer as "the diagram is broken"

Embedding a pre-rendered image removes every one of those failure modes at the
cost of a build step and a binary in the repo. So: embed where a stranger will
look (the top-level docs and the project READMEs), and leave plain Mermaid
everywhere a learner is reading and editing.

PNG, not SVG -- and this is the part that bites people
-----------------------------------------------------
Mermaid draws node labels inside `<foreignObject>` when HTML labels are on.
A browser does NOT render foreignObject when the SVG is loaded through an
`<img>` tag, which is exactly what a markdown image is. The picture appears,
the boxes appear, and every label is invisible. You can avoid it with
`htmlLabels: false`, but then `<b>`, `<i>` and `<code>` in labels print
literally. PNG at 2x has none of that ambiguity.

The Mermaid source is kept, inside a <details>, so it stays greppable, stays
diffable, and stays visible to check-diagrams.py and render.sh.

    ./embed-figures.py                 # report what would be embedded
    ./embed-figures.py --apply         # portfolio docs (the default scope)
    ./embed-figures.py --apply --all   # every markdown file, _reference included
    ./embed-figures.py --revert        # strip the images, keep the Mermaid
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import hashlib
import os
import pathlib
import re
import shutil
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]                      # the mastery root
FIGDIR = ROOT / "_figures"
TOOLS = HERE / ".tools"

BLOCK = re.compile(r"```mermaid\n(.*?)```", re.S)
# an already-embedded figure: the marker, the image, and the <details> wrapper
EMBEDDED = re.compile(
    r"<!-- figure: [^\n]*-->\n!\[[^\]]*\]\([^)]*\)\n\n"
    r"<details>\n<summary>[^\n]*</summary>\n\n(```mermaid\n.*?```)\n\n</details>",
    re.S,
)

# Files a stranger opens: the strategy docs and the three portfolio projects.
PORTFOLIO = ["*.md", "curriculum/projects/**/*.md"]


def targets(all_files: bool) -> list[pathlib.Path]:
    if all_files:
        return [p for p in sorted(ROOT.rglob("*.md"))
                if "node_modules" not in p.parts and "_out" not in p.parts]
    out: list[pathlib.Path] = []
    for pat in PORTFOLIO:
        out += sorted(ROOT.glob(pat))
    return [p for p in out if "node_modules" not in p.parts]


KIND = {"flowchart": "diagram", "graph": "diagram", "sequenceDiagram": "sequence diagram",
        "stateDiagram-v2": "state diagram", "gantt": "timeline"}


def title_of(body: str, before: str) -> str:
    """Alt text a screen reader can use: the section it sits under, plus the kind.

    The nearest preceding heading describes the diagram far better than anything
    inside it -- node labels are fragments, and the first one is arbitrary.
    """
    heads = re.findall(r"^#{1,6}\s+(.+?)\s*$", before, re.M)
    stripped = re.sub(r"%%\{.*?\}%%", "", body, flags=re.S).strip()
    first = stripped.splitlines()[0].strip().split()[0] if stripped else ""
    kind = KIND.get(first, "diagram")
    if heads:
        head = re.sub(r"[`*_]", "", heads[-1]).strip()
        return f"{head} — {kind}"
    return kind


def ensure_toolchain() -> pathlib.Path:
    mmdc = TOOLS / "node_modules" / ".bin" / "mmdc"
    if mmdc.exists():
        return mmdc
    print("installing mermaid-cli into .tools/ (first run only)")
    TOOLS.mkdir(parents=True, exist_ok=True)
    subprocess.run(["npm", "install", "--silent", "--no-fund", "--no-audit",
                    "@mermaid-js/mermaid-cli@11"], cwd=TOOLS, check=True)
    subprocess.run(["npx", "--yes", "puppeteer", "browsers", "install",
                    "chrome-headless-shell"], cwd=TOOLS, check=True,
                   stdout=subprocess.DEVNULL)
    return mmdc


def puppeteer_config(tmp: pathlib.Path) -> pathlib.Path:
    cfg = tmp / "puppeteer.json"
    chrome = sorted(pathlib.Path.home().glob(
        ".cache/puppeteer/chrome-headless-shell/*/chrome-headless-shell-*/chrome-headless-shell"))
    if chrome:
        cfg.write_text('{ "executablePath": "%s", "args": ["--no-sandbox"] }' % chrome[-1])
    else:
        cfg.write_text('{ "args": ["--no-sandbox"] }')
    return cfg


def render(mmdc: pathlib.Path, cfg: pathlib.Path, body: str, out: pathlib.Path) -> bool:
    """Render one block. Each mmdc call spawns a browser, so this costs ~2s."""
    tmp = out.with_suffix(".mmd")
    tmp.write_text(body, encoding="utf-8")
    r = subprocess.run([str(mmdc), "-p", str(cfg), "-i", str(tmp), "-o", str(out),
                        "-b", "white", "-s", "2"],
                       capture_output=True, text=True)
    tmp.unlink(missing_ok=True)
    if r.returncode != 0:
        sys.stderr.write(f"  render failed: {out.name}\n")
        for line in r.stderr.splitlines():
            if re.search(r"error|expect", line, re.I):
                sys.stderr.write(f"      {line[:160]}\n")
        return False
    return True


def render_all(mmdc, cfg, jobs: list[tuple[str, pathlib.Path]], workers: int) -> set[pathlib.Path]:
    """Render every block concurrently and return the ones that succeeded.

    Serially this is two seconds per diagram, which is twenty minutes for a
    library this size. The work is a browser per call, so it parallelises
    almost perfectly up to the core count.
    """
    done: set[pathlib.Path] = set()
    if not jobs:
        return done
    total = len(jobs)
    with cf.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(render, mmdc, cfg, body, out): out for body, out in jobs}
        for i, fut in enumerate(cf.as_completed(futures), 1):
            out = futures[fut]
            if fut.result():
                done.add(out)
            if i % 25 == 0 or i == total:
                print(f"    rendered {i}/{total}", flush=True)
    return done


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true", help="write the images and edit the files")
    ap.add_argument("--all", action="store_true", help="every markdown file, not just the portfolio set")
    ap.add_argument("--revert", action="store_true", help="remove embedded images, keep the Mermaid")
    args = ap.parse_args(argv[1:])

    files = targets(args.all)

    # ------------------------------------------------------------- revert --
    if args.revert:
        n = 0
        for md in files:
            text = md.read_text(encoding="utf-8")
            new, k = EMBEDDED.subn(lambda m: m.group(1), text)
            if k:
                md.write_text(new, encoding="utf-8")
                n += k
                print(f"  {md.relative_to(ROOT)}: {k} reverted")
        print(f"\n  {n} figure(s) reverted; _figures/ left in place")
        return 0

    # ------------------------------------------------------------- report --
    # Count blocks in the SOURCE (embeds stripped first), so an already-embedded
    # file is still in scope. That makes --apply idempotent and self-healing: if
    # _figures/ is deleted, re-running rebuilds it instead of reporting no work.
    todo = [(md, len(BLOCK.findall(EMBEDDED.sub(lambda m: m.group(1),
                                                md.read_text(encoding="utf-8")))))
            for md in files]
    todo = [(md, k) for md, k in todo if k]
    total = sum(k for _, k in todo)
    if not args.apply:
        for md, k in todo:
            print(f"  {md.relative_to(ROOT)}  ({k} diagram{'s' if k > 1 else ''})")
        print(f"\n  would embed {total} diagram(s) across {len(todo)} file(s)")
        print("  scope:", "every markdown file" if args.all else "portfolio docs only")
        print("\n  re-run with --apply to write them")
        return 0

    # -------------------------------------------------------------- apply --
    if not shutil.which("npm"):
        sys.stderr.write("npm is required to render the figures\n")
        return 1
    mmdc = ensure_toolchain()
    FIGDIR.mkdir(exist_ok=True)
    tmp = FIGDIR / ".tmp"
    tmp.mkdir(exist_ok=True)
    cfg = puppeteer_config(tmp)

    # ---- pass 1: work out every image, and render the ones we do not have ----
    plan: dict[pathlib.Path, tuple[str, list[tuple[re.Match, pathlib.Path]]]] = {}
    jobs: list[tuple[str, pathlib.Path]] = []
    seen: set[pathlib.Path] = set()
    for md, _ in todo:
        text = EMBEDDED.sub(lambda m: m.group(1),
                            md.read_text(encoding="utf-8"))   # start from source
        stem = md.relative_to(ROOT).with_suffix("").as_posix().replace("/", "-")
        blocks = []
        for i, m in enumerate(BLOCK.finditer(text)):
            body = m.group(1)
            digest = hashlib.sha1(body.encode()).hexdigest()[:8]
            png = FIGDIR / f"{stem}-{i}-{digest}.png"
            blocks.append((m, png))
            # the digest is in the name, so an unchanged diagram is never re-rendered
            if not png.exists() and png not in seen:
                jobs.append((body, png))
                seen.add(png)
        plan[md] = (text, blocks)

    print(f"  {len(jobs)} diagram(s) to render ({len(seen)} unique), "
          f"{sum(len(b) for _, b in plan.values()) - len(jobs)} already cached")
    ok = render_all(mmdc, cfg, jobs, workers=int(os.environ.get("JOBS", "6")))
    failed = len(jobs) - len(ok)

    # ---- pass 2: rewrite the markdown ---------------------------------------
    made = 0
    for md, (text, blocks) in plan.items():
        out_parts: list[str] = []
        last = 0
        for m, png in blocks:
            if not png.exists():
                continue                      # render failed; leave the source alone
            made += 1
            rel = os.path.relpath(png, md.parent)
            alt = title_of(m.group(1), text[:m.start()]).replace("]", ")")
            out_parts.append(text[last:m.start()])
            out_parts.append(
                f"<!-- figure: generated from the Mermaid below by "
                f"_shared/diagrams/embed-figures.py — do not edit the image -->\n"
                f"![{alt}]({rel})\n\n"
                f"<details>\n<summary>Diagram source (Mermaid)</summary>\n\n"
                f"{m.group(0)}\n\n</details>"
            )
            last = m.end()
        out_parts.append(text[last:])
        md.write_text("".join(out_parts), encoding="utf-8")

    shutil.rmtree(tmp, ignore_errors=True)

    # Prune images no markdown references any more. Editing a diagram changes
    # its hash and therefore its filename, so without this every edit leaves the
    # previous render behind for ever.
    #
    # `referenced` is read back off disk from EVERY file in scope, not just the
    # ones this run edited -- a run with nothing to do still has 400 live
    # images, and computing this from the edit set alone deletes all of them.
    if args.all:
        ref = re.compile(r"!\[[^\]]*\]\(([^)]*\.png)\)")
        referenced: set[pathlib.Path] = set()
        for md in targets(True):
            for rel in ref.findall(md.read_text(encoding="utf-8", errors="replace")):
                referenced.add((md.parent / rel).resolve())
        orphans = [f for f in FIGDIR.glob("*.png") if f.resolve() not in referenced]
        for f in orphans:
            f.unlink()
        print(f"  live images: {len(referenced & {f.resolve() for f in FIGDIR.glob('*.png')})}"
              + (f"   pruned: {len(orphans)}" if orphans else ""))

    print(f"\n  embedded: {made}   failed to render: {failed}")
    print(f"  images:   {FIGDIR.relative_to(ROOT)}/")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
