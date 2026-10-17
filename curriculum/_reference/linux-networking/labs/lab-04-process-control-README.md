# Lab 04: Process Control

## Overview

Learn to monitor, manage, and control processes and services on Linux. Understanding process management is critical for system administration and troubleshooting.

## Objectives

- Monitor running processes
- Manage process lifecycle
- Control services with systemd
- Create custom systemd services
- Handle signals and job control

## Prerequisites

- Lab 03 completed
- SSH access to Linux VM

## Time Estimate

- Guided: 2-3 hours
- Challenge: 1-2 hours

---

## Tier 1: Guided Instructions

### Exercise 1: Viewing Processes

```bash
# View all processes
ps aux
ps -ef

# View process tree
ps auxf
pstree

# View specific user's processes
ps -u ubuntu

# Custom format
ps -eo pid,ppid,user,%cpu,%mem,stat,cmd --sort=-%cpu | head

# View by name
ps aux | grep nginx
pgrep -a nginx

# Continuous monitoring
top
# Press: M (sort by memory), P (sort by CPU), k (kill), q (quit)

# Enhanced monitoring
htop
# If not installed: sudo apt install htop
```

### Exercise 2: Process Details

```bash
# Start a long-running process
sleep 1000 &
echo "PID: $!"

# View process information
PID=$!
cat /proc/$PID/status
cat /proc/$PID/cmdline
cat /proc/$PID/limits

# View file descriptors
ls -l /proc/$PID/fd

# View memory map
cat /proc/$PID/maps | head

# View environment
cat /proc/$PID/environ | tr '\0' '\n'
```

### Exercise 3: Signals

```bash
# Create test processes
sleep 1000 &
PID1=$!
sleep 1000 &
PID2=$!

echo "Process 1: $PID1"
echo "Process 2: $PID2"

# Send SIGTERM (graceful)
kill $PID1
ps aux | grep $PID1

# Send SIGKILL (force)
kill -9 $PID2
ps aux | grep $PID2

# Kill by name
sleep 1000 &
killall sleep

# Kill by pattern
sleep 1000 &
sleep 2000 &
pkill -f "sleep"

# View available signals
kill -l
```

### Exercise 4: Job Control

```bash
# Start foreground job
sleep 100
# Press Ctrl+Z to suspend

# View jobs
jobs
jobs -l

# Resume in background
bg %1

# View jobs again
jobs

# Start background job
sleep 200 &

# Bring to foreground
fg %2

# Ctrl+C to terminate

# Run immune to hangup
nohup sleep 1000 &
# Check nohup.out
cat nohup.out
```

### Exercise 5: Systemd Basics

```bash
# View service status
systemctl status ssh
systemctl status nginx 2>/dev/null || sudo apt install nginx -y

# Start/stop services
sudo systemctl stop nginx
sudo systemctl status nginx
sudo systemctl start nginx

# Restart and reload
sudo systemctl restart nginx
sudo systemctl reload nginx

# Enable/disable at boot
sudo systemctl is-enabled nginx
sudo systemctl disable nginx
sudo systemctl enable nginx

# View all services
systemctl list-units --type=service
systemctl list-units --type=service --state=running
systemctl list-units --type=service --state=failed

# View service configuration
systemctl cat nginx
```

### Exercise 6: Systemd Service Analysis

```bash
# Show dependencies
systemctl list-dependencies nginx

# Show reverse dependencies
systemctl list-dependencies --reverse nginx

# View service logs
sudo journalctl -u nginx
sudo journalctl -u nginx -f    # Follow
sudo journalctl -u nginx --since "1 hour ago"

# Check boot time
systemd-analyze
systemd-analyze blame | head
```

### Exercise 7: Create Custom Service

```bash
# Create application script
sudo mkdir -p /opt/myapp
sudo tee /opt/myapp/server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import os

PORT = int(os.environ.get('PORT', 8080))
Handler = http.server.SimpleHTTPRequestHandler

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"Serving on port {PORT}")
    httpd.serve_forever()
EOF
sudo chmod +x /opt/myapp/server.py

# Create systemd service file
sudo tee /etc/systemd/system/myapp.service << 'EOF'
[Unit]
Description=My Python Web Application
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/myapp
Environment=PORT=8080
ExecStart=/usr/bin/python3 /opt/myapp/server.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
sudo systemctl daemon-reload

# Start and enable service
sudo systemctl start myapp
sudo systemctl enable myapp

# Verify
sudo systemctl status myapp
curl http://localhost:8080

# View logs
sudo journalctl -u myapp -f
```

### Exercise 8: Process Priority

```bash
# View nice values
ps -eo pid,ni,comm | head

# Start with nice value
nice -n 10 sleep 100 &
nice -n -10 sleep 100 &  # Requires root

# Change running process priority
sleep 1000 &
PID=$!
sudo renice 10 -p $PID
ps -o pid,ni,comm -p $PID

# ionice for I/O priority
ionice -c2 -n7 -p $PID
```

---

## Tier 2: Semi-Guided Exercises

### Exercise A: Process Monitor Script

Create a script that:
1. Monitors system processes
2. Alerts when CPU or memory exceeds threshold
3. Logs top consumers
4. Runs as a systemd service

Requirements:
- Check every 30 seconds
- Log to /var/log/process-monitor.log
- Alert if any process uses > 80% CPU
- Alert if memory usage > 90%

### Exercise B: Service Dependencies

Create a multi-service application:
1. Database service (simulated with a script)
2. Application service that requires database
3. Web frontend that requires application

Configure proper systemd dependencies:
- Frontend waits for Application
- Application waits for Database
- All start on boot
- Restart on failure

### Exercise C: Resource Limits

Configure systemd to limit service resources:
1. Memory limit: 512MB
2. CPU limit: 50%
3. Maximum 100 processes
4. I/O bandwidth limit

Test that limits are enforced.

---

## Tier 3: Challenge

Complete all tasks in 60 minutes:

### Challenge Tasks

1. **Process Investigation**
   - Find the 10 most memory-intensive processes
   - Find zombie processes (if any exist)
   - Identify process hierarchy for sshd
   - Calculate total memory used by a specific user

2. **Complex Service Setup**
   - Create a service that:
     - Runs as a specific user
     - Uses environment file
     - Has pre-start and post-start actions
     - Limits resources (memory, CPU, files)
     - Logs to a custom location
     - Restarts intelligently on failure

3. **Monitoring System**
   - Create monitoring service that:
     - Tracks system metrics every minute
     - Writes to log file with rotation
     - Alerts on threshold breach (write to file)
     - Can be controlled via systemctl

4. **Stress Testing**
   - Install stress-ng
   - Create workload that:
     - Uses 80% CPU
     - Uses 500MB memory
   - Monitor with top/htop
   - Kill gracefully with timeout

### Success Criteria

- [ ] Can identify and kill problem processes
- [ ] Custom systemd service running correctly
- [ ] Dependencies working as configured
- [ ] Resource limits enforced
- [ ] Monitoring service operational

---

## Validation Script

```bash
#!/bin/bash

echo "=== Process Control Lab Validation ==="

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

check() {
    if eval "$1" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $2"
        return 0
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

# Check basic commands
check "ps aux | head -1" "ps command works"
check "pgrep -x systemd" "pgrep works"

# Check systemd knowledge
check "systemctl is-active nginx" "nginx service is active"
check "systemctl is-enabled nginx" "nginx is enabled"

# Check custom service
check "[ -f /etc/systemd/system/myapp.service ]" "myapp service file exists"
check "systemctl is-active myapp" "myapp service is running"

# Check service endpoint
check "curl -s http://localhost:8080 >/dev/null" "myapp is responding"

echo ""
echo "Validation complete!"
```

---

## Cleanup

```bash
# Stop and remove custom service
sudo systemctl stop myapp
sudo systemctl disable myapp
sudo rm /etc/systemd/system/myapp.service
sudo rm -rf /opt/myapp
sudo systemctl daemon-reload

# Kill any remaining test processes
killall sleep 2>/dev/null
```

---

## Key Takeaways

1. **Processes have hierarchy** - Parent/child relationships matter
2. **Signals control processes** - SIGTERM first, SIGKILL last resort
3. **Systemd manages everything** - Modern Linux service management
4. **Create proper service files** - Dependencies, restart policies, limits
5. **Monitor continuously** - Know your normal state
6. **Resource limits protect systems** - Prevent runaway processes

---

## Next Lab

[Lab 05: Shell Script Automation](lab-05-shell-automation-README.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Viewing Processes
- Process Details
- Signals
- Job Control

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
