# Lab 11: Linux Troubleshooting

## Overview

Master systematic troubleshooting of Linux systems. This lab covers diagnostic techniques, common problems, and their solutions. Effective troubleshooting is one of the most valuable skills for DevOps engineers.

## Objectives

- Develop systematic troubleshooting methodology
- Diagnose common system issues
- Use diagnostic tools effectively
- Troubleshoot network connectivity
- Debug application issues
- Document and prevent issues

## Prerequisites

- Labs 01-10 completed
- Solid understanding of Linux fundamentals
- Access to system logs

## Time Estimate

- Guided: 3-4 hours
- Challenge: 2-3 hours

---

## Tier 1: Guided Instructions

### Exercise 1: Troubleshooting Methodology

```bash
# The Troubleshooting Process:
# 1. Identify the problem
# 2. Gather information
# 3. Form hypothesis
# 4. Test hypothesis
# 5. Implement solution
# 6. Document and prevent

# Quick system health check script
cat > ~/scripts/health_check.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "=== System Health Check ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo ""

# System uptime
echo "--- Uptime ---"
uptime

# Load average interpretation
load=$(cat /proc/loadavg | awk '{print $1}')
cpus=$(nproc)
echo "Load: $load (CPUs: $cpus)"
if (( $(echo "$load > $cpus" | bc -l) )); then
    echo "WARNING: High load detected!"
fi

# Memory usage
echo ""
echo "--- Memory ---"
free -h
mem_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
echo "Memory usage: ${mem_percent}%"
if [[ $mem_percent -gt 90 ]]; then
    echo "WARNING: High memory usage!"
fi

# Disk usage
echo ""
echo "--- Disk Usage ---"
df -h | grep -E '^/dev|^Filesystem'
disk_percent=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [[ $disk_percent -gt 90 ]]; then
    echo "WARNING: Disk space critical!"
fi

# Network connectivity
echo ""
echo "--- Network ---"
ip -br addr show
ping -c 1 8.8.8.8 &>/dev/null && echo "Internet: OK" || echo "Internet: FAILED"

# Service status
echo ""
echo "--- Critical Services ---"
for svc in ssh nginx apache2 mysql postgresql docker; do
    if systemctl is-active --quiet $svc 2>/dev/null; then
        echo "$svc: RUNNING"
    elif systemctl list-unit-files | grep -q "^$svc"; then
        echo "$svc: STOPPED"
    fi
done

# Recent errors
echo ""
echo "--- Recent System Errors ---"
sudo journalctl -p err -n 5 --no-pager 2>/dev/null || echo "Could not read journal"

echo ""
echo "=== Health Check Complete ==="
EOF

chmod +x ~/scripts/health_check.sh
~/scripts/health_check.sh
```

### Exercise 2: Performance Troubleshooting

```bash
# CPU Investigation
echo "=== CPU Troubleshooting ==="

# View load average
cat /proc/loadavg
uptime

# Top CPU consumers
ps aux --sort=-%cpu | head -10

# Real-time CPU monitoring
top -bn1 | head -20

# Per-CPU statistics
mpstat -P ALL 1 3 2>/dev/null || (sudo apt install sysstat -y && mpstat -P ALL 1 3)

# CPU wait times (I/O bottleneck indicator)
iostat -c 1 3

# Memory Investigation
echo ""
echo "=== Memory Troubleshooting ==="

# Memory overview
free -h
cat /proc/meminfo | head -20

# Top memory consumers
ps aux --sort=-%mem | head -10

# Memory by process
smem -tk 2>/dev/null || echo "smem not installed"

# Check for memory leaks (growing memory over time)
watch -n 5 'free -h; ps aux --sort=-%mem | head -5'
# Ctrl+C to exit

# Swap usage
swapon -s
cat /proc/swaps

# Disk I/O Investigation
echo ""
echo "=== Disk I/O Troubleshooting ==="

# I/O statistics
iostat -xz 1 3

# Top I/O processes
iotop -bn1 2>/dev/null || (sudo apt install iotop -y && sudo iotop -bn1)

# Disk latency
sudo ioping -c 10 / 2>/dev/null || echo "ioping not installed"
```

### Exercise 3: Disk Space Troubleshooting

```bash
# Find what's using disk space
echo "=== Disk Space Analysis ==="

# Overview
df -h

# Largest directories
sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head -20

# Find large files
sudo find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -20

# Find recently modified large files
sudo find / -type f -size +50M -mtime -7 2>/dev/null | head -20

# Check log sizes
sudo du -sh /var/log/*

# Check for deleted but open files (using disk but not visible)
sudo lsof +L1 2>/dev/null | head -20

# Inode usage (can run out even with free space)
df -i

# Find directories with many files
sudo find / -xdev -type f 2>/dev/null | cut -d "/" -f 2-3 | sort | uniq -c | sort -rn | head -20

# Cleanup script
cat > ~/scripts/disk_cleanup.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "=== Disk Cleanup ==="

# Clean apt cache
echo "Cleaning apt cache..."
sudo apt clean
sudo apt autoclean
sudo apt autoremove -y

# Clean old journal logs
echo "Cleaning old journals..."
sudo journalctl --vacuum-time=7d

# Clean old kernels (careful!)
# sudo apt purge $(dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d')

# Clean tmp files older than 7 days
echo "Cleaning old temp files..."
sudo find /tmp -type f -atime +7 -delete 2>/dev/null
sudo find /var/tmp -type f -atime +7 -delete 2>/dev/null

# Show results
df -h /
echo "Cleanup complete!"
EOF

chmod +x ~/scripts/disk_cleanup.sh
```

### Exercise 4: Network Troubleshooting

```bash
# Systematic network debugging
cat > ~/scripts/network_debug.sh << 'EOF'
#!/bin/bash
set -euo pipefail

TARGET=${1:-8.8.8.8}

echo "=== Network Troubleshooting ==="
echo "Target: $TARGET"
echo ""

# Step 1: Check interface status
echo "--- Step 1: Interface Status ---"
ip link show
ip addr show

# Step 2: Check local connectivity
echo ""
echo "--- Step 2: Local Connectivity ---"
ping -c 2 127.0.0.1

# Step 3: Check gateway
echo ""
echo "--- Step 3: Default Gateway ---"
ip route show default
GATEWAY=$(ip route | grep default | awk '{print $3}')
if [[ -n "$GATEWAY" ]]; then
    ping -c 2 "$GATEWAY" && echo "Gateway reachable" || echo "Gateway unreachable!"
fi

# Step 4: Check DNS
echo ""
echo "--- Step 4: DNS Resolution ---"
cat /etc/resolv.conf
nslookup google.com && echo "DNS working" || echo "DNS failed!"

# Step 5: Check target connectivity
echo ""
echo "--- Step 5: Target Connectivity ---"
ping -c 4 "$TARGET" && echo "Target reachable" || echo "Target unreachable!"

# Step 6: Trace route
echo ""
echo "--- Step 6: Route to Target ---"
traceroute -n "$TARGET" 2>/dev/null || tracepath "$TARGET"

# Step 7: Check for firewall blocks
echo ""
echo "--- Step 7: Firewall Status ---"
sudo iptables -L -n | head -20

# Step 8: Check listening ports
echo ""
echo "--- Step 8: Listening Services ---"
sudo ss -tlnp

# Step 9: Check connections
echo ""
echo "--- Step 9: Active Connections ---"
ss -tn state established | head -20

echo ""
echo "=== Troubleshooting Complete ==="
EOF

chmod +x ~/scripts/network_debug.sh
~/scripts/network_debug.sh

# Common network issues and fixes:
echo "
=== Common Network Issues ===

1. No IP Address:
   - Check: ip addr show
   - Fix: sudo dhclient eth0 or check netplan config

2. No Default Gateway:
   - Check: ip route show
   - Fix: sudo ip route add default via GATEWAY_IP

3. DNS Not Working:
   - Check: cat /etc/resolv.conf
   - Fix: Add 'nameserver 8.8.8.8' to /etc/resolv.conf

4. Firewall Blocking:
   - Check: sudo iptables -L -n
   - Fix: sudo iptables -I INPUT -p tcp --dport PORT -j ACCEPT

5. Service Not Listening:
   - Check: ss -tlnp | grep PORT
   - Fix: Check service config and restart
"
```

### Exercise 5: Service Troubleshooting

```bash
# Systematic service debugging
cat > ~/scripts/service_debug.sh << 'EOF'
#!/bin/bash
set -euo pipefail

SERVICE=${1:-nginx}

echo "=== Service Troubleshooting: $SERVICE ==="
echo ""

# Check if service exists
echo "--- Service Exists ---"
if ! systemctl list-unit-files | grep -q "^$SERVICE"; then
    echo "Service $SERVICE not found!"
    exit 1
fi
echo "$SERVICE found"

# Check service status
echo ""
echo "--- Service Status ---"
systemctl status "$SERVICE" --no-pager || true

# Check if enabled
echo ""
echo "--- Enabled Status ---"
systemctl is-enabled "$SERVICE" 2>/dev/null || echo "Not enabled"

# Check recent logs
echo ""
echo "--- Recent Logs ---"
sudo journalctl -u "$SERVICE" -n 20 --no-pager

# Check for errors
echo ""
echo "--- Errors Only ---"
sudo journalctl -u "$SERVICE" -p err -n 10 --no-pager 2>/dev/null || echo "No errors"

# Check configuration (if applicable)
echo ""
echo "--- Configuration Check ---"
case "$SERVICE" in
    nginx)
        sudo nginx -t
        ;;
    apache2)
        sudo apache2ctl configtest
        ;;
    sshd)
        sudo sshd -t
        ;;
    *)
        echo "No config test available for $SERVICE"
        ;;
esac

# Check port binding
echo ""
echo "--- Port Binding ---"
sudo ss -tlnp | grep "$SERVICE" || echo "No ports found for $SERVICE"

# Check process
echo ""
echo "--- Process Info ---"
pgrep -a "$SERVICE" || echo "Process not running"

echo ""
echo "=== Troubleshooting Complete ==="
EOF

chmod +x ~/scripts/service_debug.sh
~/scripts/service_debug.sh nginx
```

### Exercise 6: Log Analysis for Troubleshooting

```bash
# Log investigation techniques
echo "=== Log Analysis ==="

# System logs
echo "--- Recent System Events ---"
sudo journalctl -n 50 --no-pager | tail -20

# Errors only
echo ""
echo "--- System Errors ---"
sudo journalctl -p err -n 20 --no-pager

# Specific time range
echo ""
echo "--- Last Hour Events ---"
sudo journalctl --since "1 hour ago" -n 20 --no-pager

# Boot messages
echo ""
echo "--- Current Boot Issues ---"
sudo journalctl -b -p warning --no-pager | head -30

# Auth logs
echo ""
echo "--- Authentication Issues ---"
sudo grep -E "Failed|error|denied" /var/log/auth.log 2>/dev/null | tail -10

# Create log analysis script
cat > ~/scripts/log_analyzer.sh << 'EOF'
#!/bin/bash
set -euo pipefail

LOG_FILE=${1:-/var/log/syslog}
HOURS=${2:-1}

echo "=== Log Analysis ==="
echo "File: $LOG_FILE"
echo "Time range: Last $HOURS hour(s)"
echo ""

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Log file not found!"
    exit 1
fi

# Get timestamp for filtering
if [[ "$OSTYPE" == "darwin"* ]]; then
    START_TIME=$(date -v-${HOURS}H '+%b %d %H')
else
    START_TIME=$(date -d "$HOURS hours ago" '+%b %d %H')
fi

# Count by severity
echo "--- Message Counts ---"
for level in error warning notice info debug; do
    count=$(grep -ic "$level" "$LOG_FILE" 2>/dev/null || echo 0)
    echo "$level: $count"
done

# Most common messages
echo ""
echo "--- Most Common Messages ---"
cat "$LOG_FILE" | awk '{$1=$2=$3=""; print $0}' | sort | uniq -c | sort -rn | head -10

# Error patterns
echo ""
echo "--- Error Patterns ---"
grep -iE "error|fail|denied|refused|timeout" "$LOG_FILE" 2>/dev/null | \
    awk '{$1=$2=$3=""; print $0}' | sort | uniq -c | sort -rn | head -10

echo ""
echo "=== Analysis Complete ==="
EOF

chmod +x ~/scripts/log_analyzer.sh
```

### Exercise 7: Process Troubleshooting

```bash
# Process debugging techniques
echo "=== Process Troubleshooting ==="

# Find zombie processes
echo "--- Zombie Processes ---"
ps aux | awk '$8 ~ /Z/ {print}'

# Find defunct processes
ps aux | grep defunct | grep -v grep

# High CPU processes
echo ""
echo "--- High CPU Processes ---"
ps aux --sort=-%cpu | head -10

# Processes in uninterruptible sleep (D state)
echo ""
echo "--- Blocked Processes ---"
ps aux | awk '$8 ~ /D/ {print}'

# Process tree for specific process
echo ""
echo "--- Process Tree (init) ---"
pstree -p 1 | head -20

# Trace system calls
echo ""
echo "--- Strace Example ---"
# sudo strace -p PID -e trace=open,read,write -t
echo "Use: sudo strace -p PID to trace a process"

# Check open files by process
echo ""
echo "--- Open Files Example ---"
lsof -p $$ | head -10

# Create process monitor
cat > ~/scripts/process_monitor.sh << 'EOF'
#!/bin/bash
set -euo pipefail

THRESHOLD_CPU=${1:-80}
THRESHOLD_MEM=${2:-80}

echo "=== Process Monitor ==="
echo "CPU threshold: ${THRESHOLD_CPU}%"
echo "Memory threshold: ${THRESHOLD_MEM}%"
echo ""

# Check for high CPU
echo "--- High CPU Processes ---"
ps aux --no-headers | awk -v threshold="$THRESHOLD_CPU" '$3 > threshold {print "PID:", $2, "CPU:", $3"%", "CMD:", $11}'

# Check for high memory
echo ""
echo "--- High Memory Processes ---"
ps aux --no-headers | awk -v threshold="$THRESHOLD_MEM" '$4 > threshold {print "PID:", $2, "MEM:", $4"%", "CMD:", $11}'

# Check for zombie processes
echo ""
echo "--- Zombie Processes ---"
zombies=$(ps aux | awk '$8 ~ /Z/' | wc -l)
if [[ $zombies -gt 0 ]]; then
    echo "WARNING: $zombies zombie processes found!"
    ps aux | awk '$8 ~ /Z/'
else
    echo "No zombie processes"
fi

# Check process count
echo ""
echo "--- Process Count ---"
process_count=$(ps aux | wc -l)
echo "Total processes: $process_count"

# User with most processes
echo ""
echo "--- Processes by User ---"
ps aux | awk '{print $1}' | sort | uniq -c | sort -rn | head -5
EOF

chmod +x ~/scripts/process_monitor.sh
~/scripts/process_monitor.sh
```

### Exercise 8: Complete Troubleshooting Toolkit

```bash
# Master troubleshooting script
cat > ~/scripts/troubleshoot.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Comprehensive system troubleshooting script

REPORT_FILE="/tmp/troubleshoot-$(date +%Y%m%d-%H%M%S).txt"

log() {
    echo "$*" | tee -a "$REPORT_FILE"
}

section() {
    log ""
    log "============================================"
    log "$1"
    log "============================================"
}

# Header
log "System Troubleshooting Report"
log "Generated: $(date)"
log "Hostname: $(hostname)"
log "Kernel: $(uname -r)"

# System overview
section "SYSTEM OVERVIEW"
log "Uptime: $(uptime)"
log ""
log "Load Average:"
cat /proc/loadavg | tee -a "$REPORT_FILE"

# CPU
section "CPU STATUS"
log "CPU Count: $(nproc)"
log ""
log "Top CPU Processes:"
ps aux --sort=-%cpu | head -10 | tee -a "$REPORT_FILE"

# Memory
section "MEMORY STATUS"
free -h | tee -a "$REPORT_FILE"
log ""
log "Top Memory Processes:"
ps aux --sort=-%mem | head -10 | tee -a "$REPORT_FILE"

# Disk
section "DISK STATUS"
df -h | tee -a "$REPORT_FILE"
log ""
log "Inode Usage:"
df -i | tee -a "$REPORT_FILE"

# Network
section "NETWORK STATUS"
ip -br addr show | tee -a "$REPORT_FILE"
log ""
log "Routing Table:"
ip route show | tee -a "$REPORT_FILE"
log ""
log "Listening Ports:"
sudo ss -tlnp | tee -a "$REPORT_FILE"

# Services
section "SERVICE STATUS"
for svc in sshd nginx apache2 mysql postgresql docker; do
    if systemctl list-unit-files | grep -q "^$svc"; then
        status=$(systemctl is-active $svc 2>/dev/null || echo "inactive")
        log "$svc: $status"
    fi
done

# Recent errors
section "RECENT ERRORS"
sudo journalctl -p err -n 20 --no-pager 2>/dev/null | tee -a "$REPORT_FILE" || log "Could not read journal"

# Security
section "SECURITY CHECK"
log "Failed SSH attempts (last 10):"
sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10 | tee -a "$REPORT_FILE" || log "No auth.log access"

# Summary
section "SUMMARY"
log ""
log "Potential Issues Detected:"

# Check for issues
issues=0

# High load
load=$(cat /proc/loadavg | awk '{print $1}')
cpus=$(nproc)
if (( $(echo "$load > $cpus * 2" | bc -l) )); then
    log "- HIGH LOAD: $load (CPUs: $cpus)"
    ((issues++))
fi

# High memory
mem_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
if [[ $mem_percent -gt 90 ]]; then
    log "- HIGH MEMORY USAGE: ${mem_percent}%"
    ((issues++))
fi

# High disk
disk_percent=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [[ $disk_percent -gt 90 ]]; then
    log "- HIGH DISK USAGE: ${disk_percent}%"
    ((issues++))
fi

# Zombie processes
zombies=$(ps aux | awk '$8 ~ /Z/' | wc -l)
if [[ $zombies -gt 0 ]]; then
    log "- ZOMBIE PROCESSES: $zombies"
    ((issues++))
fi

if [[ $issues -eq 0 ]]; then
    log "No critical issues detected"
fi

log ""
log "Report saved to: $REPORT_FILE"

echo ""
echo "Troubleshooting complete. Report: $REPORT_FILE"
EOF

chmod +x ~/scripts/troubleshoot.sh
~/scripts/troubleshoot.sh
```

---

## Tier 2: Semi-Guided Exercises

### Exercise A: Application Crash Investigation

Investigate and resolve application crashes:

1. Analyze core dumps
2. Check application logs
3. Review system resource usage at crash time
4. Identify root cause
5. Implement monitoring to prevent recurrence

### Exercise B: Performance Degradation

Diagnose gradual system slowdown:

1. Establish baseline metrics
2. Compare current vs. historical performance
3. Identify resource bottlenecks
4. Find resource-heavy processes
5. Implement performance fixes

### Exercise C: Intermittent Network Issues

Troubleshoot sporadic connectivity problems:

1. Set up continuous monitoring
2. Capture packet traces during issues
3. Analyze patterns (time, load, specific targets)
4. Identify network layer of failure
5. Implement permanent fix

---

## Tier 3: Challenge

Scenario-based troubleshooting exercises:

### Scenario 1: Server Won't Boot

A server fails to boot after recent changes:
- Investigate boot process
- Check for disk/filesystem issues
- Review recent changes
- Restore to working state

### Scenario 2: Memory Leak Detection

Application memory usage grows over time:
- Identify the leaking process
- Analyze memory allocation patterns
- Implement monitoring
- Create automated restart if needed

### Scenario 3: Disk I/O Bottleneck

Database performance is poor due to disk I/O:
- Identify I/O-heavy processes
- Analyze disk performance metrics
- Optimize configuration
- Recommend hardware solutions

### Scenario 4: Complete Outage

Production server is unreachable:
- Systematic diagnosis from network to application
- Identify all failed components
- Restore services in correct order
- Document and prevent recurrence

---

## Key Takeaways

1. **Follow methodology** - Don't guess, investigate systematically
2. **Start broad, narrow down** - Check system health before specifics
3. **Check logs first** - They often tell you exactly what's wrong
4. **Document everything** - For yourself and others
5. **Know your baselines** - Understand normal vs. abnormal
6. **Automate detection** - Don't wait for users to report issues

---

## Next Lab

[Lab 12: Production Server Setup](../lab-12-production-server/)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Troubleshooting Methodology
- Performance Troubleshooting
- Disk Space Troubleshooting
- Network Troubleshooting

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
