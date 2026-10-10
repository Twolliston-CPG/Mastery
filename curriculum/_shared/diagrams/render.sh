#!/usr/bin/env bash
#
# Extract every ```mermaid block, render it, and report failures.
#
# A diagram that does not render is worse than no diagram -- GitHub shows a red
# error box exactly where your architecture should be, on the repo a hiring
# manager is reading. Run check-diagrams.py first (one second, no browser);
# run this before you publish.
#
#   ./render.sh              validate the curriculum (fast path, no PNGs)
#   ./render.sh --all        include _reference/ too (~160 blocks, a few minutes)
#   ./render.sh --png        also write PNGs to _out/ for visual inspection
#
# mermaid-cli is installed once into .tools/ next to this script, not globally.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"   # the mastery root, so the top-level strategy docs are covered too
OUT="$HERE/_out"
TOOLS="$HERE/.tools"
WRITE_PNG=0
INCLUDE_REF=0
JOBS="${JOBS:-6}"

for a in "$@"; do
  case "$a" in
    --png) WRITE_PNG=1 ;;
    --all) INCLUDE_REF=1 ;;
    *) echo "unknown flag: $a" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------- extract --
python3 - "$ROOT" "$tmp" "$INCLUDE_REF" <<'PY'
import re, sys, pathlib
root, tmp, inc_ref = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3] == "1"
block = re.compile(r"```mermaid\n(.*?)```", re.S)
n = 0
for md in sorted(root.rglob("*.md")):
    if "_out" in md.parts or "node_modules" in md.parts:
        continue
    if "_reference" in md.parts and not inc_ref:
        continue
    for i, m in enumerate(block.finditer(md.read_text(encoding="utf-8", errors="replace"))):
        rel = md.relative_to(root).as_posix().replace("/", "__").removesuffix(".md")
        (tmp / f"{rel}__{i}.mmd").write_text(m.group(1))
        n += 1
print(f"extracted {n} mermaid blocks")
PY

shopt -s nullglob
files=("$tmp"/*.mmd)
if [[ ${#files[@]} -eq 0 ]]; then echo "no mermaid blocks found"; exit 0; fi

# ---------------------------------------------------------------- install --
MMDC="$TOOLS/node_modules/.bin/mmdc"
if [[ ! -x "$MMDC" ]]; then
  echo "installing mermaid-cli into .tools/ (first run only)"
  mkdir -p "$TOOLS"
  (cd "$TOOLS" && npm install --silent --no-fund --no-audit @mermaid-js/mermaid-cli@11)
  # puppeteer's postinstall may be blocked by npm's allow-scripts policy
  (cd "$TOOLS" && npx --yes puppeteer browsers install chrome-headless-shell >/dev/null)
fi

# Point mermaid-cli at the browser puppeteer just downloaded.
CHROME="$(ls -d "$HOME"/.cache/puppeteer/chrome-headless-shell/*/chrome-headless-shell-*/chrome-headless-shell 2>/dev/null | head -1 || true)"
PUP="$tmp/puppeteer.json"
if [[ -n "$CHROME" ]]; then
  printf '{ "executablePath": "%s", "args": ["--no-sandbox"] }\n' "$CHROME" > "$PUP"
else
  printf '{ "args": ["--no-sandbox"] }\n' > "$PUP"
fi

# ----------------------------------------------------------------- render --
ext=svg; [[ $WRITE_PNG -eq 1 ]] && ext=png
cat > "$tmp/one.sh" <<'ONE'
#!/bin/sh
n=$(basename "$1" .mmd)
if ! "$MMDC" -p "$PUP" -i "$1" -o "$OUT/$n.$ext" -b white > "$TMPD/$n.log" 2>&1; then
  printf '  \033[31mFAIL\033[0m %s\n' "$n"
  grep -iE 'error|expect' "$TMPD/$n.log" | head -3 | sed 's/^/        /'
  exit 1
fi
ONE
chmod +x "$tmp/one.sh"
export MMDC PUP OUT ext TMPD="$tmp"

fails=0
printf '%s\n' "${files[@]}" | xargs -P "$JOBS" -n1 "$tmp/one.sh" || fails=1
ok=$(ls "$OUT" | wc -l | tr -d ' ')

printf '\n  rendered: %s / %s\n' "$ok" "${#files[@]}"
[[ $WRITE_PNG -eq 1 ]] && printf '  output: %s\n' "$OUT"
exit $fails
