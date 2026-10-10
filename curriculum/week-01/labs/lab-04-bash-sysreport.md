# Lab 4 — Bash Scripting: Build `sysreport.sh`

**Time:** 4 hours · **This is the week's deliverable.**

## Objectives
Write a production-quality Bash script — error handling, argument parsing, structured output — and
publish it. This is your first portfolio artifact.

---

## Part 1 — The patterns (60 min)

Work through each of these in a scratch file. Understand them before building.

```bash
#!/usr/bin/env bash
#
# Why 'env bash' and not '/bin/bash'? Portability -- on macOS /bin/bash is
# ancient (3.2); Homebrew's modern bash is elsewhere on PATH.

set -euo pipefail
#   -e          exit on any non-zero return
#   -u          error on undefined variable (catches typos)
#   -o pipefail a pipeline fails if ANY stage fails, not just the last
IFS=$'\n\t'     # safer word splitting: don't split on spaces

# --- constants ---
readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="1.0.0"

# --- logging to stderr, so stdout stays clean for data ---
log()  { printf '[%s] %s\n' "$(date +%FT%T)" "$*" >&2; }
warn() { printf '[%s] WARN: %s\n' "$(date +%FT%T)" "$*" >&2; }
die()  { printf '[%s] ERROR: %s\n' "$(date +%FT%T)" "$*" >&2; exit 1; }

# --- cleanup and error traps ---
TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT
trap 'die "failed at line $LINENO (exit $?)"' ERR

# --- required config ---
: "${REQUIRED_VAR:?must be set}"       # fails immediately with a clear message

# --- argument parsing ---
usage() {
  cat <<USAGE
$SCRIPT_NAME v$VERSION - one line description

Usage: $SCRIPT_NAME [OPTIONS]

Options:
  -f, --format FORMAT   Output format: table|json  (default: table)
  -o, --output FILE     Write to FILE instead of stdout
  -v, --verbose         Verbose logging
  -h, --help            This message
USAGE
}

FORMAT="table"; OUTPUT=""; VERBOSE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--format)  FORMAT="${2:?--format needs a value}"; shift 2 ;;
    -o|--output)  OUTPUT="${2:?--output needs a value}"; shift 2 ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            usage >&2; die "unknown option: $1" ;;
  esac
done

# --- safe iteration over filenames ---
while IFS= read -r -d '' f; do
  printf 'processing %s\n' "$f"
done < <(find . -type f -print0)

# --- check a command exists before using it ---
need() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }
need jq; need awk

# --- retry with exponential backoff ---
retry() {
  local n=0 max="${MAX_RETRIES:-5}"
  until "$@"; do
    n=$((n + 1))
    (( n >= max )) && return 1
    warn "attempt $n failed, retrying in $((2**n))s"
    sleep $((2**n))
  done
}
```

**Run everything through ShellCheck.** It catches real bugs:
```bash
shellcheck sysreport.sh
```

---

## Part 2 — Build `sysreport.sh` (2.5 h)

### Requirements

**Must collect:**
| Section | Data |
|---|---|
| Host | hostname, kernel, distro, uptime, current time (UTC) |
| CPU | core count, load average (1/5/15), load-per-core ratio |
| Memory | total, used, available, swap used, percentage used |
| Disk | per-mounted-filesystem usage, flag anything over a threshold |
| Inodes | inode usage per filesystem (**flag this too — see BF-08**) |
| Processes | total count, top 5 by CPU, top 5 by memory, any zombies |
| Network | listening TCP ports with the owning process |
| systemd | any units in a failed state |
| Logins | currently logged-in users |

**Must support:**
- `--format table` (default, human-readable, colored) and `--format json`
- `--output FILE`
- `--threshold N` (disk/memory warning percentage, default 80)
- `--help`
- **Exit code 0** if everything is under threshold, **1** if any check exceeds it
  (so it can be used in monitoring)
- Graceful degradation — if `systemctl` doesn't exist, skip that section with a warning rather than
  crashing

### Starter skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly VERSION="1.0.0"
THRESHOLD=80
FORMAT="table"
OUTPUT=""
EXIT_CODE=0

# colors (disabled if not a tty or if NO_COLOR is set)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED=$'\e[31m'; YEL=$'\e[33m'; GRN=$'\e[32m'; BLD=$'\e[1m'; RST=$'\e[0m'
else
  RED=""; YEL=""; GRN=""; BLD=""; RST=""
fi

log()  { printf '%s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

collect_host()    { : ; }   # TODO
collect_cpu()     { : ; }   # TODO
collect_memory()  { : ; }   # TODO
collect_disk()    { : ; }   # TODO
collect_procs()   { : ; }   # TODO
collect_net()     { : ; }   # TODO
collect_systemd() { : ; }   # TODO

render_table()    { : ; }   # TODO
render_json()     { : ; }   # TODO

main() {
  # parse args, collect, render, exit $EXIT_CODE
  :
}
main "$@"
```

### Hints per section

```bash
# Host
hostname; uname -r; uptime -p
. /etc/os-release && echo "$PRETTY_NAME"

# CPU
nproc
read -r l1 l5 l15 _ < /proc/loadavg

# Memory -- parse /proc/meminfo rather than shelling out to free
awk '/MemTotal/{t=$2} /MemAvailable/{a=$2}
     END {printf "%.1f %.1f %.1f\n", t/1048576, (t-a)/1048576, (t-a)*100/t}' /proc/meminfo

# Disk -- -P forces POSIX single-line output (critical for parsing)
df -PH --exclude-type=tmpfs --exclude-type=devtmpfs | awk 'NR>1 {print $6, $5}'

# Inodes
df -Pi --exclude-type=tmpfs | awk 'NR>1 {print $6, $5}'

# Processes
ps -eo pid,%cpu,%mem,comm --sort=-%cpu | head -6
ps -eo stat | grep -c '^Z' || true      # `|| true` because grep returns 1 on no match
                                        # and `set -e` would kill the script

# Network
ss -tlnp 2>/dev/null | awk 'NR>1 {print $4, $6}'

# systemd
systemctl --failed --no-legend --plain 2>/dev/null || true
```

**`|| true` after `grep -c` is a real gotcha.** With `set -e`, a grep that finds nothing exits 1 and
kills your script. This trips up almost everyone the first time.

### JSON output without a JSON library

```bash
render_json() {
  jq -n \
    --arg host "$(hostname)" \
    --arg kernel "$(uname -r)" \
    --argjson cores "$(nproc)" \
    --argjson load1 "$l1" \
    --argjson mem_pct "$mem_pct" \
    --argjson disks "$disks_json" \
    '{
       timestamp: (now | todate),
       host:      {name: $host, kernel: $kernel},
       cpu:       {cores: $cores, load1: $load1},
       memory:    {used_pct: $mem_pct},
       disks:     $disks
     }'
}
```
Using `jq -n` with `--arg`/`--argjson` guarantees valid JSON and correct escaping. Hand-rolling JSON
with `printf` breaks the first time a value contains a quote.

---

## Part 3 — Test it (30 min)

```bash
./sysreport.sh
./sysreport.sh --format json | jq .
./sysreport.sh --threshold 1 ; echo "exit: $?"     # should exit 1
./sysreport.sh --bogus                             # should show usage, exit 2
NO_COLOR=1 ./sysreport.sh | cat                    # no escape codes when piped
shellcheck sysreport.sh                            # must be clean
```

**Then break it deliberately:** run it as a user who can't read `/proc/*/fd`, run it where
`systemctl` doesn't exist, run it with a full disk. It should degrade, not crash.

---

## Deliverable checklist
- [ ] Public GitHub repo
- [ ] `sysreport.sh`, executable, ShellCheck-clean
- [ ] README from `_shared/templates/PROJECT-README-template.md` with example output
- [ ] Conventional commit messages
- [ ] A **"What broke"** section in the README with at least two real entries
