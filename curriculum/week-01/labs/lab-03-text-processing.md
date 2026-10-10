# Lab 3 — Text Processing: The Log Analysis Lab

**Time:** 3 hours

> This lab produces skills you will use every single day of your career, and it is one of the most
> common live-coding exercises in a technical screen.

## Generate the dataset

```bash
mkdir -p ~/lab3 && cd ~/lab3
python3 - <<'PY'
import random, datetime
ips   = [f"10.0.{random.randint(0,3)}.{random.randint(1,254)}" for _ in range(60)]
hot   = ["203.0.113.7", "198.51.100.22"]          # two noisy clients
paths = ["/", "/api/users", "/api/orders", "/api/orders/12345", "/login",
         "/static/app.js", "/health", "/api/search"]
codes = [200]*80 + [201]*5 + [301]*3 + [404]*6 + [500]*4 + [502]*2
agents = ["Mozilla/5.0", "curl/8.4.0", "python-requests/2.31", "Googlebot/2.1"]
t = datetime.datetime(2026, 3, 14, 8, 0, 0)
with open("access.log", "w") as f:
    for i in range(100000):
        t += datetime.timedelta(milliseconds=random.randint(10, 900))
        ip = random.choice(hot) if random.random() < 0.15 else random.choice(ips)
        code = random.choice(codes)
        size = random.randint(180, 48000) if code < 400 else random.randint(0, 900)
        dur  = round(random.gauss(0.12, 0.09), 3)
        if code >= 500: dur = round(random.gauss(2.5, 0.8), 3)
        dur = max(dur, 0.001)
        f.write(f'{ip} - - [{t.strftime("%d/%b/%Y:%H:%M:%S %z")}] '
                f'"GET {random.choice(paths)} HTTP/1.1" {code} {size} '
                f'"-" "{random.choice(agents)}" {dur}\n')
print("wrote access.log")
PY
wc -l access.log && head -2 access.log
```

**Field positions** (space-separated, 1-indexed):
`$1`=IP · `$4`=`[timestamp` · `$6`=`"GET` · `$7`=path · `$9`=status · `$10`=bytes · `$NF`=duration

---

## Part 1 — grep (30 min)

```bash
grep '" 500 ' access.log | head                 # 500s
grep -c '" 500 ' access.log                     # count them
grep -E '" 5[0-9]{2} ' access.log | wc -l       # all 5xx
grep -v '" 200 ' access.log | wc -l             # everything that isn't 200
grep -E '^(203\.0\.113\.7|198\.51\.100\.22)' access.log | wc -l
grep -o '"GET [^ ]*' access.log | sort -u | head -20    # -o prints only the match
grep -B2 -A2 '" 502 ' access.log | head -20     # context around an error
grep -P '(?<=\] ")GET' access.log | head -2     # PCRE lookbehind (GNU grep)
```

**Tasks:** find (1) every 5xx, (2) every request from the two hot IPs, (3) every request to a path
containing `orders`, (4) all unique user agents.

---

## Part 2 — awk (60 min) — the one that matters most

```bash
# Field extraction
awk '{print $1}' access.log | head
awk '{print $1, $9, $NF}' access.log | head

# Filtering
awk '$9 >= 500' access.log | head
awk '$9 ~ /^5/ {print $1, $7}' access.log | head

# Counting into an associative array -- THE core awk pattern
awk '{count[$1]++} END {for (ip in count) print count[ip], ip}' access.log \
  | sort -rn | head -10

# Aggregation
awk '{sum += $10} END {print sum/1048576 " MB"}' access.log
awk '{sum += $NF; n++} END {printf "avg %.3fs over %d reqs\n", sum/n, n}' access.log

# Multiple aggregations at once
awk '{
  total++
  status[$9]++
  bytes += $10
  if ($NF > max) { max = $NF; slow = $7 }
} END {
  printf "requests: %d\n", total
  printf "bytes:    %.1f MB\n", bytes/1048576
  printf "slowest:  %.3fs on %s\n", max, slow
  for (s in status) printf "  %s: %d (%.1f%%)\n", s, status[s], status[s]*100/total
}' access.log

# Per-key averages -- two arrays
awk '{ sum[$7] += $NF; n[$7]++ }
     END { for (p in n) printf "%.3f %s\n", sum[p]/n[p], p }' access.log | sort -rn
```

**Tasks:**
1. Top 10 IPs by request count
2. Error rate as a percentage
3. Average duration per path, slowest first
4. Total bytes served, per status code
5. Requests per minute (hint: `substr($4, 2, 17)`)
6. The p95 duration (hint: sort numerically, take the row at 95%)

---

## Part 3 — sed (30 min)

```bash
sed 's/GET/POST/' access.log | head -2          # first occurrence per line
sed 's/GET/POST/g' access.log | head -2         # all occurrences
sed -n '100,105p' access.log                    # print a line range
sed -n '/500/p' access.log | head               # print matching lines
sed '/^#/d' somefile                            # delete comment lines
sed -n '/08:00:00/,/08:00:05/p' access.log      # between two patterns
sed -E 's/([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+/\1.xxx/' access.log | head -2   # anonymize last octet
sed -i.bak 's/old/new/g' file.txt               # in place, with a backup
```

**Task:** produce a copy of the log with all IP addresses anonymized to their /24 (e.g.
`10.0.1.55` → `10.0.1.0`). This is a real task — you do it before sharing logs with a vendor.

---

## Part 4 — jq (30 min)

```bash
# Convert a slice of the log to JSON first
awk 'NR<=1000 {print "{\"ip\":\""$1"\",\"path\":\""$7"\",\"status\":"$9",\"dur\":"$NF"}"}' \
  access.log | jq -s '.' > reqs.json

jq '.[0]' reqs.json
jq -r '.[].ip' reqs.json | sort | uniq -c | sort -rn | head
jq '[.[] | select(.status >= 500)]' reqs.json | jq length
jq -r '.[] | [.ip, .path, .status] | @tsv' reqs.json | head | column -t
jq '[.[].dur] | add / length' reqs.json                  # mean
jq 'group_by(.path) | map({path: .[0].path, n: length})' reqs.json
jq -r '.[] | select(.dur > 2) | "\(.path) took \(.dur)s"' reqs.json | head
```

**You will use `jq` constantly** — every cloud CLI and Kubernetes command outputs JSON.

---

## The deliverable: `loganalyze.sh`

Write a script that takes a log file and prints a report:

```
=== Log Analysis: access.log ===
Total requests:   100000
Time range:       14/Mar/2026:08:00:00 - 14/Mar/2026:21:22:41
Unique IPs:       62

Status codes:
  200   79831  (79.8%)
  404    6012  (6.0%)
  500    4022  (4.0%)
  ...

Top 10 IPs:
  15043  203.0.113.7
  ...

Slowest paths (avg):
  2.487s  /api/search
  ...

Error rate: 6.1%   [ALERT: above 5% threshold]
```

Requirements: `set -euo pipefail`, accept the file as `$1`, fail with usage if missing, exit 1 if
error rate > 5%.

---

## Exit check
- [ ] Wrote the top-10-IPs one-liner from memory
- [ ] Can explain the `count[key]++` / `END` awk pattern
- [ ] `loganalyze.sh` runs and produces the report
- [ ] Extracted structured data with `jq` including `group_by` and `select`
