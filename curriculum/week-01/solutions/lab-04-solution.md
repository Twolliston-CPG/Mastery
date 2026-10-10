# Lab 4 — Solution Notes

**The complete working script is at [`sysreport/sysreport.sh`](sysreport/sysreport.sh).**
Read it *after* you've written your own. Diffing your version against it is worth far more than
reading it first.

> **Platform note:** it targets Linux (it reads `/proc/loadavg` and `/proc/meminfo` directly). Run it
> in your lab VM, not on macOS. That's deliberate — parsing `/proc` is the real skill; shelling out
> to `free` is slower and its output format varies between distros.

---

## The seven things worth studying in the solution

### 1. `|| true` after `grep -c`
```bash
PROC_ZOMBIE="$(ps -eo stat --no-headers | grep -c '^Z' || true)"
```
`grep -c` exits **1** when it matches nothing. Under `set -e` that kills your script — so a *healthy*
system with no zombies crashes the health checker. This is the single most common `set -e` surprise.

### 2. Reading two values from one awk call
```bash
read -r MEM_TOTAL_GB MEM_USED_GB MEM_PCT < <(awk '...' /proc/meminfo)
```
Process substitution `< <(...)` keeps `read` in the current shell. Piping (`awk | read`) would run
`read` in a subshell and the variables would vanish. Classic Bash trap.

### 3. `df -P` is mandatory for parsing
Without `-P`, a long device name wraps onto two lines and your field positions shift silently. `-P`
forces POSIX single-line output. Same reasoning as `ls` — never parse the pretty format.

### 4. Colors that disappear when piped
```bash
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then RED=$'\e[31m'; else RED=""; fi
```
`-t 1` tests whether stdout is a terminal. Without this, piping to a file embeds escape codes and
breaks every downstream parser. Honoring `NO_COLOR` is the accepted convention.

### 5. JSON built with `jq -n`, never `printf`
```bash
jq -n --arg host "$HOST_NAME" --argjson cores "$CPU_CORES" '{host:$host, cores:$cores}'
```
`--arg` produces a string, `--argjson` produces a number/bool/object. jq handles escaping. A
hand-rolled `printf '{"host":"%s"}'` breaks the first time a hostname contains a quote or backslash —
and produces *invalid JSON*, which is worse than an error because it fails downstream.

### 6. The exit code is the product
```bash
(( pct > THRESHOLD )) && EXIT_CODE=1
...
exit "$EXIT_CODE"
```
`0` healthy, `1` threshold breached, `2` usage/runtime error. That three-way split is what lets a
cron job, systemd timer, or CI step act on the result. A script that only prints is a report; one
with meaningful exit codes is a **check**.

### 7. Graceful degradation
```bash
have() { command -v "$1" >/dev/null 2>&1; }
if have ss; then ... else warn "ss not available; skipping"; fi
```
A health checker that crashes on a minimal container is useless exactly where you need it. Skip the
section, warn on stderr, keep going.

---

## Make it a systemd timer (do this — it previews week 2)

```ini
# /etc/systemd/system/sysreport.service
[Unit]
Description=System health report
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sysreport.sh --format json --output /var/log/sysreport.json
User=root
```
```ini
# /etc/systemd/system/sysreport.timer
[Unit]
Description=Run sysreport every 15 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
```
```bash
sudo systemctl daemon-reload            # REQUIRED after any unit edit
sudo systemctl enable --now sysreport.timer
systemctl list-timers sysreport.timer
journalctl -u sysreport.service -n 20
```

**Why a timer instead of cron:** real logging through journald, dependency ordering (`After=`),
`Persistent=true` catches up missed runs after downtime, and `systemctl list-timers` shows you state.
Cron gives you none of that (see BF-07).

---

## README quality bar

Your README is the artifact a hiring manager actually reads. It must have:

1. **The problem in the first sentence**, not the tech list
2. **Example output** — paste a real run, it is the fastest way to show it works
3. **Exit codes documented** — this is what signals "I thought about how it gets used"
4. **A "What broke" section** with at least two genuine entries

Two real ones from building this:

> **`set -e` killed the script on a healthy system.** `grep -c '^Z'` returns exit 1 when there are
> no zombies, so a clean system crashed the health check. Found it by running with `bash -x`. Fixed
> with `|| true`. Lesson: under `set -e`, any command whose non-zero exit is *expected* needs
> explicit handling.

> **Float comparison silently gave wrong answers.** `[[ "$pct" > "$THRESHOLD" ]]` compares strings,
> so "9" was reported as greater than "80". Caught it when a 9%-full disk triggered an alert. Bash
> has no float arithmetic — delegate to `awk 'BEGIN {exit !(a>b)}'` or use integer math.

Those two paragraphs do more for you in an interview than any bullet list of technologies.
