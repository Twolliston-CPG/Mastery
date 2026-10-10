# Lab 3 — Solutions

## Part 1 — grep

```bash
grep -E '" 5[0-9]{2} ' access.log                                   # all 5xx
grep -E '^(203\.0\.113\.7|198\.51\.100\.22) ' access.log            # hot IPs
grep 'GET /api/orders' access.log                                   # orders paths
grep -oE '"[^"]*"$' access.log | sort -u                            # unique user agents
```

## Part 2 — awk

```bash
# 1. Top 10 IPs
awk '{c[$1]++} END {for (i in c) print c[i], i}' access.log | sort -rn | head -10

# 2. Error rate
awk '{t++} $9 >= 400 {e++} END {printf "%.2f%% (%d/%d)\n", e*100/t, e, t}' access.log

# 3. Average duration per path, slowest first
awk '{s[$7] += $NF; n[$7]++}
     END {for (p in n) printf "%.4f %6d %s\n", s[p]/n[p], n[p], p}' access.log | sort -rn

# 4. Bytes per status code
awk '{b[$9] += $10} END {for (s in b) printf "%s %.2f MB\n", s, b[s]/1048576}' access.log | sort

# 5. Requests per minute
awk '{print substr($4, 2, 17)}' access.log | uniq -c | head -20
#   substr($4,2,17) turns "[14/Mar/2026:08:00:00" into "14/Mar/2026:08:00"
#   uniq -c works because the log is already time-ordered -- no sort needed,
#   which matters a lot on a multi-GB file.

# 6. p95 duration
awk '{print $NF}' access.log | sort -n | awk '{a[NR]=$1} END {print a[int(NR*0.95)]}'
```

**Why p95, not average:** the generated log has 5xx responses averaging 2.5s hidden among 200s
averaging 0.12s. The mean is ~0.22s, which looks fine. The p95 exposes the tail. **This is exactly
the argument for percentiles over averages in week 20's observability material** — and break/fix
BF-58.

## Part 3 — sed anonymization

```bash
sed -E 's/^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\.[0-9]{1,3}/\1.0/' access.log > anon.log
head -2 anon.log
```

`-E` gives extended regex (no backslash-escaping the groups). `\1` is the first capture group.
Anchoring with `^` means only the leading IP is touched, not IPs that might appear in a path.

## Part 4 — jq

```bash
jq -r 'group_by(.path)
       | map({path: .[0].path,
              n: length,
              avg: (map(.dur) | add / length),
              errors: (map(select(.status >= 500)) | length)})
       | sort_by(-.avg)
       | .[]
       | [.path, .n, (.avg * 1000 | round), .errors] | @tsv' reqs.json | column -t
```

## `loganalyze.sh` — complete solution

```bash
#!/usr/bin/env bash
#
# loganalyze.sh - summarize an nginx/apache-style access log
#
set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly ERROR_THRESHOLD="${ERROR_THRESHOLD:-5.0}"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
usage() { printf 'Usage: %s <access.log>\n' "$SCRIPT_NAME" >&2; }

[[ $# -eq 1 ]] || { usage; exit 2; }
LOG="$1"
[[ -r "$LOG" ]] || die "cannot read: $LOG"

total=$(wc -l < "$LOG" | tr -d ' ')
[[ "$total" -gt 0 ]] || die "empty log"

first=$(head -1 "$LOG" | awk '{print substr($4,2)}')
last=$(tail -1 "$LOG" | awk '{print substr($4,2)}')
unique_ips=$(awk '{print $1}' "$LOG" | sort -u | wc -l | tr -d ' ')

printf '=== Log Analysis: %s ===\n' "$(basename "$LOG")"
printf 'Total requests:   %s\n' "$total"
printf 'Time range:       %s - %s\n' "$first" "$last"
printf 'Unique IPs:       %s\n\n' "$unique_ips"

printf 'Status codes:\n'
awk '{c[$9]++; t++}
     END {for (s in c) printf "  %-5s %7d  (%.1f%%)\n", s, c[s], c[s]*100/t}' "$LOG" | sort

printf '\nTop 10 IPs:\n'
awk '{c[$1]++} END {for (i in c) print c[i], i}' "$LOG" \
  | sort -rn | head -10 | awk '{printf "  %7d  %s\n", $1, $2}'

printf '\nSlowest paths (avg):\n'
awk '{s[$7]+=$NF; n[$7]++}
     END {for (p in n) printf "%.3f %s\n", s[p]/n[p], p}' "$LOG" \
  | sort -rn | head -5 | awk '{printf "  %ss  %s\n", $1, $2}'

printf '\nBytes served:     %.1f MB\n' \
  "$(awk '{s+=$10} END {print s/1048576}' "$LOG")"

error_rate=$(awk '{t++} $9 >= 400 {e++} END {printf "%.1f", (e ? e*100/t : 0)}' "$LOG")
printf '\nError rate: %s%%' "$error_rate"

if awk -v r="$error_rate" -v t="$ERROR_THRESHOLD" 'BEGIN {exit !(r > t)}'; then
  printf '   [ALERT: above %s%% threshold]\n' "$ERROR_THRESHOLD"
  exit 1
fi
printf '   [OK]\n'
exit 0
```

### Two things worth noticing in that script

**Float comparison in Bash.** Bash has no floating-point arithmetic, so
`[[ "$error_rate" > "5.0" ]]` does a *string* comparison and gives wrong answers ("10.0" < "5.0" as
strings). The `awk 'BEGIN {exit !(r > t)}'` idiom delegates to awk and uses its exit status. This
catches people constantly.

**The exit code is the feature.** Returning 1 on threshold breach is what makes this usable from
cron, a systemd timer, or a CI job — the caller can act on it. A script that only prints is a report;
a script with meaningful exit codes is a check.
