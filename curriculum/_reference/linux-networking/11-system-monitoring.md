# System Monitoring

## Overview

System monitoring is essential for maintaining healthy systems and quickly identifying issues. This module covers tools and techniques for monitoring CPU, memory, disk, network, and application performance.

## Learning Objectives

By the end of this module, you will be able to:
- Monitor system resources in real-time
- Analyze system logs effectively
- Set up basic monitoring and alerting
- Troubleshoot performance issues
- Collect and interpret system metrics

---

## CPU Monitoring

### Understanding CPU Metrics

**CPU Metrics Explained:**

```
  User (us)     - CPU time spent on user processes
  System (sy)   - CPU time spent on kernel processes
  Nice (ni)     - CPU time on low-priority processes
  Idle (id)     - CPU time spent idle
  Wait (wa)     - CPU time waiting for I/O
  Hardware (hi) - CPU time on hardware interrupts
  Software (si) - CPU time on software interrupts
  Steal (st)    - CPU time stolen by hypervisor (VMs)

Load Average: 1.50, 1.25, 1.00
             1min  5min 15min

- Load < CPU cores: System is healthy
- Load = CPU cores: System is fully utilized
- Load > CPU cores: System is overloaded
```


### CPU Monitoring Commands

```bash
# View CPU info
cat /proc/cpuinfo
nproc                    # Number of CPUs
lscpu                    # CPU architecture info

# Real-time monitoring
top                      # Classic process viewer
htop                     # Enhanced process viewer
atop                     # Advanced system monitor

# CPU statistics
mpstat                   # Per-CPU statistics
mpstat 1 5               # Every 1 second, 5 times
mpstat -P ALL            # All CPUs

# Load average
uptime
cat /proc/loadavg
w                        # Who's logged in + load

# Process CPU usage
ps aux --sort=-%cpu | head -10
pidstat 1 5              # Per-process statistics
```

---

## Memory Monitoring

### Understanding Memory Metrics

**Memory layout, as `free -h` reports it**

| Column | What it counts |
|---|---|
| `used` | Applications, plus buffers and cache |
| `free` | Genuinely untouched — and on a healthy machine this is *small* |
| `available` | An estimate of what a new process could get without swapping, including reclaimable cache |

**Read `available`, not `free`.** Linux deliberately fills unused memory with page cache, because
unused RAM is wasted RAM. A server showing 200 MB free and 12 GB available is not short of memory;
it is doing its job. Cache is handed back the moment an application asks for it.

The number that actually signals trouble is swap activity (`si`/`so` in `vmstat`) or an entry from
the OOM killer in `dmesg` — not a low `free`.

### Memory Monitoring Commands

```bash
# Memory information
free -h                  # Human-readable
free -m                  # In megabytes
cat /proc/meminfo

# Memory usage
vmstat 1 5               # Every 1 second, 5 times
vmstat -s                # Summary statistics

# Per-process memory
ps aux --sort=-%mem | head -10
pmap PID                 # Memory map of process
smem                     # Detailed memory usage

# Memory pressure
cat /proc/pressure/memory

# OOM (Out of Memory) killer logs
dmesg | grep -i "out of memory"
journalctl | grep -i "oom"
```

---

## Disk Monitoring

### Disk Space and Usage

```bash
# Disk space usage
df -h                    # Human-readable
df -i                    # Inode usage
df -hT                   # Include filesystem type

# Directory size
du -sh /var/*
du -sh * | sort -hr | head -10
ncdu /var                # Interactive disk usage

# Find large files
find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null
find / -type f -size +1G 2>/dev/null
```

### Disk I/O Monitoring

```bash
# I/O statistics
iostat                   # Basic I/O stats
iostat -x 1 5            # Extended stats, every 1 second
iostat -dxz 1            # Per-device extended stats

# Understanding iostat output:
# %util - How busy the device is
# await - Average wait time (ms)
# r/s, w/s - Reads/writes per second
# rMB/s, wMB/s - MB read/written per second

# I/O by process
iotop                    # Top-like I/O monitor
iotop -o                 # Only show active I/O

# Block device info
lsblk                    # Block device list
blkid                    # Block device IDs

# Disk health (requires smartmontools)
sudo smartctl -a /dev/sda
```

---

## Network Monitoring

### Network Statistics

```bash
# Interface statistics
ip -s link               # Interface statistics
cat /proc/net/dev        # Raw network stats
nstat                    # Network statistics

# Connection monitoring
ss -tuln                 # Listening ports
ss -tunp                 # Connections with processes
ss -s                    # Socket summary

# Real-time bandwidth
iftop                    # Interface bandwidth
nethogs                  # Per-process bandwidth
nload                    # Network load graph

# Packet counts
netstat -i               # Interface statistics
ethtool -S eth0          # Driver statistics
```

### Network Troubleshooting

```bash
# Connectivity
ping -c 4 8.8.8.8
traceroute 8.8.8.8
mtr 8.8.8.8              # Continuous traceroute

# DNS
dig example.com
nslookup example.com
host example.com

# Packet capture
sudo tcpdump -i eth0 port 80
sudo tcpdump -i any -n host 10.0.0.1

# Connection quality
ping -c 100 8.8.8.8 | tail -1
# Shows packet loss and timing statistics
```

---

## Process Monitoring

### top and htop

```bash
# top interactive commands
top
# Inside top:
# h     - Help
# k     - Kill process
# r     - Renice
# M     - Sort by memory
# P     - Sort by CPU
# c     - Show full command
# 1     - Show all CPUs
# q     - Quit

# htop (enhanced)
htop
# F1-F10 for various functions
# Arrow keys to navigate
# Space to tag processes
# F9 to kill
```

### ps Command

```bash
# Process listing
ps aux                   # All processes, BSD style
ps -ef                   # All processes, Unix style

# Custom format
ps -eo pid,ppid,user,%cpu,%mem,stat,cmd --sort=-%cpu
ps -eo pid,ppid,user,%cpu,%mem,etime,cmd

# Process tree
ps auxf
pstree
pstree -p                # With PIDs

# Find specific process
ps aux | grep nginx
pgrep -a nginx           # Process ID and command
```

### /proc Filesystem

```bash
# Process information
cat /proc/PID/status     # Process status
cat /proc/PID/cmdline    # Command line
cat /proc/PID/environ    # Environment
cat /proc/PID/fd         # File descriptors
cat /proc/PID/limits     # Resource limits

# System information
cat /proc/cpuinfo
cat /proc/meminfo
cat /proc/loadavg
cat /proc/uptime
cat /proc/version
```

---

## Log Analysis

### System Logs

```bash
# Log locations
/var/log/syslog          # System log (Debian/Ubuntu)
/var/log/messages        # System log (RHEL/CentOS)
/var/log/auth.log        # Authentication log
/var/log/kern.log        # Kernel log
/var/log/dmesg           # Boot messages
/var/log/apt/            # Package manager logs
/var/log/nginx/          # Application logs

# View logs
tail -f /var/log/syslog
tail -100 /var/log/syslog
less /var/log/syslog
```

### journalctl (Systemd Logs)

```bash
# View all logs
journalctl

# Follow logs in real-time
journalctl -f

# Specific unit
journalctl -u nginx
journalctl -u nginx -f

# Specific time range
journalctl --since "1 hour ago"
journalctl --since "2024-01-15" --until "2024-01-16"
journalctl --since "today"

# Filter by priority
journalctl -p err        # Errors and above
journalctl -p warning

# Kernel messages
journalctl -k
journalctl --dmesg

# Boot logs
journalctl -b            # Current boot
journalctl -b -1         # Previous boot
journalctl --list-boots

# Output formats
journalctl -o json
journalctl -o short-precise

# Disk usage
journalctl --disk-usage
sudo journalctl --vacuum-size=100M
sudo journalctl --vacuum-time=7d
```

### Log Analysis Tools

```bash
# Search logs
grep "error" /var/log/syslog
grep -i "failed" /var/log/auth.log
grep -E "error|warning|critical" /var/log/syslog

# Count occurrences
grep -c "error" /var/log/syslog
grep "Failed password" /var/log/auth.log | wc -l

# Extract patterns
grep -oP 'from \K[\d.]+' /var/log/auth.log | sort | uniq -c | sort -rn

# Log analysis with awk
awk '/error/ {print $0}' /var/log/syslog
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head
```

---

## System Tools

### sar (System Activity Report)

```bash
# Install sysstat
sudo apt install sysstat
# Enable data collection in /etc/default/sysstat

# CPU statistics
sar -u 1 5               # CPU every 1 second, 5 times
sar -u                   # CPU from collected data

# Memory
sar -r 1 5               # Memory statistics
sar -r                   # From collected data

# Disk I/O
sar -b 1 5               # I/O statistics
sar -d                   # Per-disk statistics

# Network
sar -n DEV 1 5           # Network interfaces
sar -n TCP               # TCP statistics

# Historical data
sar -f /var/log/sysstat/sa15   # Specific day
sar -u -f /var/log/sysstat/sa15 -s 10:00:00 -e 12:00:00
```

### Performance Tools

```bash
# perf (Linux performance tool)
sudo perf top            # Live profiling
sudo perf stat command   # Statistics for command
sudo perf record command # Record profile
sudo perf report         # Analyze recording

# strace (system call tracing)
strace command           # Trace system calls
strace -c command        # Summary of calls
strace -p PID            # Attach to process

# lsof (list open files)
lsof                     # All open files
lsof -i :80              # Files on port 80
lsof -u username         # Files by user
lsof -p PID              # Files by process
lsof +D /var/log         # Files in directory
```

---

## Basic Alerting

### Watch Command

```bash
# Repeat command and show changes
watch -n 5 df -h                    # Every 5 seconds
watch -d free -m                    # Highlight differences
watch -n 1 'ss -tuln | grep LISTEN' # Monitor ports
```

### Simple Monitoring Script

```bash
#!/bin/bash
# Simple system monitor with alerts

THRESHOLD_CPU=80
THRESHOLD_MEM=90
THRESHOLD_DISK=85
ALERT_EMAIL="admin@example.com"

alert() {
    local message="$1"
    echo "[$(date)] ALERT: $message"
    # echo "$message" | mail -s "System Alert" $ALERT_EMAIL
}

check_cpu() {
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
    if [ "$cpu" -gt "$THRESHOLD_CPU" ]; then
        alert "CPU usage is ${cpu}%"
    fi
}

check_memory() {
    local mem=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
    if [ "$mem" -gt "$THRESHOLD_MEM" ]; then
        alert "Memory usage is ${mem}%"
    fi
}

check_disk() {
    df -h | awk 'NR>1 {print $5 " " $6}' | while read usage mount; do
        usage_num=${usage%\%}
        if [ "$usage_num" -gt "$THRESHOLD_DISK" ]; then
            alert "Disk usage on $mount is $usage"
        fi
    done
}

# Run checks
check_cpu
check_memory
check_disk
```

---

## Practical Exercises

### Exercise 1: System Health Check

```bash
#!/bin/bash
# Comprehensive system health check

echo "=== System Health Check ==="
echo "Date: $(date)"
echo ""

echo "--- System Info ---"
uname -a
uptime

echo ""
echo "--- CPU Usage ---"
mpstat 1 1

echo ""
echo "--- Memory Usage ---"
free -h

echo ""
echo "--- Disk Usage ---"
df -h | grep -v tmpfs

echo ""
echo "--- Top Processes (CPU) ---"
ps aux --sort=-%cpu | head -6

echo ""
echo "--- Top Processes (Memory) ---"
ps aux --sort=-%mem | head -6

echo ""
echo "--- Network Connections ---"
ss -tuln | head -10

echo ""
echo "--- Recent Errors ---"
journalctl -p err --since "1 hour ago" --no-pager | tail -10
```

### Exercise 2: Log Analyzer

```bash
#!/bin/bash
# Analyze auth logs for failed logins

LOG_FILE="/var/log/auth.log"

echo "=== Authentication Log Analysis ==="
echo ""

echo "--- Failed Login Attempts ---"
grep "Failed password" "$LOG_FILE" 2>/dev/null | wc -l

echo ""
echo "--- Top 10 Source IPs ---"
grep "Failed password" "$LOG_FILE" 2>/dev/null | \
    grep -oP 'from \K[\d.]+' | \
    sort | uniq -c | sort -rn | head -10

echo ""
echo "--- Top 10 Target Users ---"
grep "Failed password" "$LOG_FILE" 2>/dev/null | \
    grep -oP 'for (?:invalid user )?\K\w+' | \
    sort | uniq -c | sort -rn | head -10

echo ""
echo "--- Successful Logins Today ---"
grep "Accepted" "$LOG_FILE" 2>/dev/null | \
    grep "$(date +%b\ %d)" | wc -l
```

### Exercise 3: Resource Monitor

```bash
#!/bin/bash
# Continuous resource monitor

while true; do
    clear
    echo "=== Resource Monitor === $(date '+%H:%M:%S')"
    echo ""

    # CPU
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.1f", $2}')
    echo "CPU: ${cpu}%"

    # Memory
    mem=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}')
    echo "Memory: ${mem}%"

    # Disk
    disk=$(df / | awk 'NR==2 {print $5}')
    echo "Disk (/): $disk"

    # Load
    load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    echo "Load: $load"

    # Network
    echo ""
    echo "--- Network Connections ---"
    ss -t state established | wc -l | xargs echo "Established:"

    # Top processes
    echo ""
    echo "--- Top CPU ---"
    ps aux --sort=-%cpu | awk 'NR<=4 {printf "%-10s %5s %5s %s\n", $1, $3, $4, $11}'

    sleep 5
done
```

---

## Key Takeaways

1. **Know your baseline** - Understand normal system behavior
2. **Monitor proactively** - Don't wait for problems
3. **Use multiple metrics** - CPU, memory, disk, network together
4. **Check logs regularly** - They tell the story
5. **Automate alerts** - Be notified of issues
6. **Historical data matters** - Use sar for trending

---

## Next Module

[Security Hardening](./12-security-hardening.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- CPU Monitoring
- Memory Monitoring
- Disk Monitoring
- Network Monitoring

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The kernel manages processes."* |
| ✓ | *"A process is an entry in the kernel's task table with its own memory map and file-descriptor table. `fork()` copies it, `exec()` replaces the program inside it, and the parent must call `wait()` or the entry stays behind as a zombie."* |

**Trace it:** `ls -l /etc` → characters on your terminal. Name every syscall and every kernel structure between the keypress and the output.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [`man 7 namespaces`](https://man7.org/linux/man-pages/man7/namespaces.7.html) and the [LWN namespaces series](https://lwn.net/Articles/531114/) — the primary sources, not summaries of them.
Full list per domain: [`SOURCES.md`](../SOURCES.md#linux-networking)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
