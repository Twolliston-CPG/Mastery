# Bash One-Liner Drill

> Weeks 1–26. Cover the right column. Write the command from the description alone.
> These appear verbatim in live technical screens.

## Text and log processing

| Task | Command |
|---|---|
| Top 10 IPs by request count in an access log | `awk '{print $1}' access.log \| sort \| uniq -c \| sort -rn \| head -10` |
| Count 5xx responses | `awk '$9 ~ /^5/ {c++} END {print c+0}' access.log` |
| Requests per minute | `awk '{print substr($4,2,17)}' access.log \| uniq -c` |
| Sum a numeric column | `awk '{s+=$3} END {print s}' file` |
| Average of a column | `awk '{s+=$1; n++} END {print s/n}' file` |
| Lines between two patterns | `sed -n '/START/,/END/p' file` |
| Replace in place, with backup | `sed -i.bak 's/old/new/g' file` |
| Delete blank lines and comments | `grep -vE '^\s*(#\|$)' file` |
| Unique lines, keep original order | `awk '!seen[$0]++' file` |
| Last field of each line | `awk '{print $NF}' file` |
| Print lines longer than 80 chars | `awk 'length > 80' file` |
| Join every 2 lines | `paste - - < file` |
| Field 2 from CSV, handling quotes | `python3 -c "import csv,sys;[print(r[1]) for r in csv.reader(sys.stdin)]" < f.csv` |

## Files and disks

| Task | Command |
|---|---|
| 20 largest files under a tree | `find . -type f -printf '%s %p\n' 2>/dev/null \| sort -rn \| head -20` |
| Largest directories (one filesystem) | `du -xh / 2>/dev/null \| sort -rh \| head -20` |
| Files modified in the last hour | `find . -type f -mmin -60` |
| Delete files older than 30 days | `find /var/log -type f -mtime +30 -delete` |
| Deleted-but-open files eating disk | `lsof +L1` |
| Count files per directory | `find . -type f \| awk -F/ '{print $2}' \| sort \| uniq -c \| sort -rn` |
| Find world-writable files | `find / -xdev -type f -perm -0002 -ls 2>/dev/null` |
| Find setuid binaries | `find / -xdev -perm -4000 -type f 2>/dev/null` |

## Processes and network

| Task | Command |
|---|---|
| Top 10 by memory | `ps -eo pid,rss,comm --sort=-rss \| head -11` |
| Top 10 by CPU | `ps -eo pid,%cpu,comm --sort=-%cpu \| head -11` |
| What's listening on a port | `ss -tlnp \| grep :8080` |
| Which process owns a port | `lsof -i :8080` |
| Kill by name | `pkill -f 'pattern'` |
| Established connections by remote IP | `ss -tn state established \| awk '{print $4}' \| cut -d: -f1 \| sort \| uniq -c \| sort -rn` |
| Watch a command every 2s | `watch -n2 'kubectl get pods'` |
| Test a port without telnet | `timeout 3 bash -c '</dev/tcp/host/443' && echo open \|\| echo closed` |
| Capture traffic to one host | `tcpdump -ni any host 10.0.0.5 -w /tmp/cap.pcap` |

## JSON and APIs

| Task | Command |
|---|---|
| Pretty-print | `jq . file.json` |
| Extract nested field | `jq -r '.items[].metadata.name' f.json` |
| Filter an array | `jq '.[] \| select(.status=="running")' f.json` |
| Build a table | `jq -r '.[] \| [.name,.ip] \| @tsv' f.json \| column -t` |
| Sum a field | `jq '[.[].size] \| add' f.json` |
| Convert YAML to JSON | `yq -o=json '.' f.yaml` |
| curl with timing | `curl -w '\ntotal: %{time_total}s\n' -o /dev/null -s https://example.com` |
| Retry with backoff | `curl --retry 5 --retry-delay 2 --retry-all-errors https://api.example.com` |

## Scripting patterns worth memorizing

```bash
#!/usr/bin/env bash
set -euo pipefail            # exit on error, undefined var, pipeline failure
IFS=$'\n\t'                  # safer word splitting

trap 'rc=$?; echo "failed at line $LINENO (rc=$rc)" >&2; exit $rc' ERR
trap 'rm -rf "$TMPDIR"' EXIT

TMPDIR=$(mktemp -d)
: "${REQUIRED_VAR:?must be set}"          # fail fast on missing config

# safe loop over filenames with spaces
while IFS= read -r -d '' f; do
  printf 'processing %s\n' "$f"
done < <(find . -type f -print0)

# retry with exponential backoff
retry() {
  local n=0 max=${MAX:-5}
  until "$@"; do
    n=$((n+1)); [[ $n -ge $max ]] && return 1
    sleep $((2**n))
  done
}
```

**`set -euo pipefail` is the single highest-value habit in shell scripting.** Without `pipefail`,
`false | true` succeeds — which is how silent data-loss bugs happen in pipelines.
