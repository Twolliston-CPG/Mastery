# Lab 06: Log Analysis

## Overview

Learn to analyze system and application logs effectively. Log analysis is crucial for troubleshooting, security monitoring, and understanding system behavior.

## Objectives

- Navigate system log locations
- Use grep, awk, sed for log analysis
- Analyze journald logs
- Create log monitoring scripts
- Set up log rotation

## Prerequisites

- Lab 05 completed
- Understanding of text processing

## Time Estimate

- Guided: 2-3 hours
- Challenge: 1-2 hours

---

## Tier 1: Guided Instructions

### Exercise 1: System Log Locations

```bash
# Common log directories
ls -la /var/log/

# Key log files
cat /var/log/syslog | head -20      # System log (Debian/Ubuntu)
cat /var/log/auth.log | head -20    # Authentication
cat /var/log/kern.log | head -20    # Kernel messages
cat /var/log/dpkg.log | head -20    # Package manager

# View logs in real-time
sudo tail -f /var/log/syslog
# Ctrl+C to exit
```

### Exercise 2: Journalctl Usage

```bash
# View all logs
sudo journalctl | head -50

# Follow logs
sudo journalctl -f

# Specific service
sudo journalctl -u nginx
sudo journalctl -u ssh

# Time-based queries
sudo journalctl --since "1 hour ago"
sudo journalctl --since "2024-01-15 10:00:00"
sudo journalctl --since yesterday --until today

# Priority filtering
sudo journalctl -p err         # Errors only
sudo journalctl -p warning     # Warnings and above

# Boot logs
sudo journalctl -b             # Current boot
sudo journalctl -b -1          # Previous boot
sudo journalctl --list-boots

# Output formats
sudo journalctl -o json | head -5
sudo journalctl -o short-precise | head -10
```

### Exercise 3: grep for Logs

```bash
# Create sample log file
cat > /tmp/sample.log << 'EOF'
2024-01-15 10:00:00 INFO Application started
2024-01-15 10:00:01 DEBUG Loading configuration
2024-01-15 10:00:02 INFO Server listening on port 8080
2024-01-15 10:01:00 WARNING High memory usage detected
2024-01-15 10:02:00 ERROR Database connection failed
2024-01-15 10:02:01 ERROR Retry attempt 1 failed
2024-01-15 10:02:02 INFO Database connected successfully
2024-01-15 10:03:00 WARNING Slow query detected: 5.2s
2024-01-15 10:04:00 ERROR Out of memory exception
2024-01-15 10:05:00 INFO Graceful shutdown initiated
EOF

# Basic grep
grep "ERROR" /tmp/sample.log
grep "WARNING" /tmp/sample.log

# Case insensitive
grep -i "error" /tmp/sample.log

# Count matches
grep -c "ERROR" /tmp/sample.log

# Show line numbers
grep -n "ERROR" /tmp/sample.log

# Context
grep -A 1 "Database connection" /tmp/sample.log  # After
grep -B 1 "Database connection" /tmp/sample.log  # Before
grep -C 1 "Database connection" /tmp/sample.log  # Both

# Invert match
grep -v "DEBUG" /tmp/sample.log

# Multiple patterns
grep -E "ERROR|WARNING" /tmp/sample.log
egrep "ERROR|WARNING" /tmp/sample.log

# Regex patterns
grep "10:0[0-2]" /tmp/sample.log
```

### Exercise 4: awk for Analysis

```bash
# Print specific fields
awk '{print $1, $2, $3}' /tmp/sample.log

# Filter by field
awk '$3 == "ERROR" {print}' /tmp/sample.log

# Count by type
awk '{print $3}' /tmp/sample.log | sort | uniq -c

# Calculate statistics
awk '/Slow query/ {gsub(/s/, "", $NF); sum+=$NF; count++}
     END {print "Average:", sum/count, "seconds"}' /tmp/sample.log

# Apache log analysis (create sample)
cat > /tmp/access.log << 'EOF'
192.168.1.100 - - [15/Jan/2024:10:00:00] "GET /index.html HTTP/1.1" 200 1234
192.168.1.101 - - [15/Jan/2024:10:00:01] "GET /about.html HTTP/1.1" 200 567
192.168.1.100 - - [15/Jan/2024:10:00:02] "POST /api/login HTTP/1.1" 401 89
192.168.1.102 - - [15/Jan/2024:10:00:03] "GET /admin HTTP/1.1" 403 45
192.168.1.100 - - [15/Jan/2024:10:00:04] "GET /images/logo.png HTTP/1.1" 200 5678
192.168.1.103 - - [15/Jan/2024:10:00:05] "GET /nonexistent HTTP/1.1" 404 23
EOF

# Top IPs
awk '{print $1}' /tmp/access.log | sort | uniq -c | sort -rn

# Status code distribution
awk '{print $9}' /tmp/access.log | sort | uniq -c

# Top URLs
awk '{print $7}' /tmp/access.log | sort | uniq -c | sort -rn

# Filter 4xx errors
awk '$9 ~ /^4/' /tmp/access.log
```

### Exercise 5: sed for Log Processing

```bash
# Remove timestamps
sed 's/^[0-9-]* [0-9:]*//' /tmp/sample.log

# Replace log levels
sed 's/ERROR/🔴 ERROR/g' /tmp/sample.log

# Extract between patterns
sed -n '/10:00:00/,/10:02:00/p' /tmp/sample.log

# Delete lines
sed '/DEBUG/d' /tmp/sample.log

# Multiple operations
sed -e 's/INFO/ℹ️ INFO/g' -e 's/ERROR/❌ ERROR/g' /tmp/sample.log
```

### Exercise 6: Log Monitoring Script

```bash
cat > ~/scripts/log_monitor.sh << 'EOF'
#!/bin/bash
set -euo pipefail

LOG_FILE=${1:-/var/log/syslog}
ALERT_PATTERN=${2:-"error|fail|critical"}
CHECK_INTERVAL=${3:-60}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

monitor_logs() {
    log "Starting log monitor for: $LOG_FILE"
    log "Alert pattern: $ALERT_PATTERN"
    log "Check interval: ${CHECK_INTERVAL}s"

    local last_size=0

    while true; do
        current_size=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)

        if [[ $current_size -gt $last_size ]]; then
            # Read new content
            tail -c +$((last_size + 1)) "$LOG_FILE" | \
                grep -iE "$ALERT_PATTERN" | while read -r line; do
                log "ALERT: $line"
            done
        fi

        last_size=$current_size
        sleep "$CHECK_INTERVAL"
    done
}

monitor_logs
EOF

chmod +x ~/scripts/log_monitor.sh
```

### Exercise 7: Auth Log Analysis

```bash
cat > ~/scripts/auth_report.sh << 'EOF'
#!/bin/bash
set -euo pipefail

AUTH_LOG="/var/log/auth.log"

echo "=== Authentication Report ==="
echo "Generated: $(date)"
echo ""

echo "--- Failed Login Attempts ---"
grep "Failed password" "$AUTH_LOG" 2>/dev/null | wc -l || echo "0"

echo ""
echo "--- Top 10 Failed IPs ---"
grep "Failed password" "$AUTH_LOG" 2>/dev/null | \
    grep -oP 'from \K[\d.]+' | \
    sort | uniq -c | sort -rn | head -10 || echo "None"

echo ""
echo "--- Successful Logins Today ---"
grep "Accepted" "$AUTH_LOG" 2>/dev/null | \
    grep "$(date +%b\ %d)" | wc -l || echo "0"

echo ""
echo "--- Users with Failed Attempts ---"
grep "Failed password" "$AUTH_LOG" 2>/dev/null | \
    grep -oP 'for (?:invalid user )?\K\w+' | \
    sort | uniq -c | sort -rn | head -10 || echo "None"
EOF

chmod +x ~/scripts/auth_report.sh
sudo ~/scripts/auth_report.sh
```

### Exercise 8: Log Rotation

```bash
# View logrotate config
cat /etc/logrotate.conf

# View service-specific configs
ls /etc/logrotate.d/

# Create custom logrotate config
sudo tee /etc/logrotate.d/myapp << 'EOF'
/var/log/myapp/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        systemctl reload myapp 2>/dev/null || true
    endscript
}
EOF

# Test logrotate
sudo logrotate -d /etc/logrotate.d/myapp
```

---

## Tier 2: Semi-Guided Exercises

### Exercise A: Comprehensive Log Analyzer

Create a script that analyzes multiple log types and generates an HTML report.

### Exercise B: Real-time Alert System

Create a monitoring system that watches logs and sends alerts via webhook.

### Exercise C: Log Aggregation

Set up a simple log aggregation from multiple sources into a single location.

---

## Tier 3: Challenge

Build a complete log analysis toolkit with:
1. Multi-format parser (syslog, JSON, Apache)
2. Statistical analysis
3. Anomaly detection
4. Automated reporting
5. Alert integration

---

## Key Takeaways

1. **Know your logs** - Location and format matter
2. **journalctl is powerful** - Learn its query language
3. **grep + awk + sed** - The log analysis trinity
4. **Automate analysis** - Scripts save time
5. **Set up rotation** - Prevent disk full issues

---

## Next Lab

[Lab 07: Network Configuration](lab-07-network-config-README.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- System Log Locations
- Journalctl Usage
- grep for Logs
- awk for Analysis

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The kernel manages processes."* |
| ✓ | *"A process is an entry in the kernel's task table with its own memory map and file-descriptor table. `fork()` copies it, `exec()` replaces the program inside it, and the parent must call `wait()` or the entry stays behind as a zombie."* |

**Trace it:** `ls -l /etc` → characters on your terminal. Name every syscall and every kernel structure between the keypress and the output.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [`man 7 namespaces`](https://man7.org/linux/man-pages/man7/namespaces.7.html) and the [LWN namespaces series](https://lwn.net/Articles/531114/) — the primary sources, not summaries of them.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#linux-networking)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
