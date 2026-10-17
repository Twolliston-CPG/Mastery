# Lab 12: Production Server Setup

## Overview

Set up a complete production-ready Linux server from scratch, applying all skills learned in previous labs. This capstone lab simulates real-world server deployment scenarios.

## Objectives

- Deploy a hardened Linux server
- Configure all essential services
- Implement security best practices
- Set up monitoring and alerting
- Create operational documentation

## Prerequisites

- All previous labs completed
- Clean AWS/GCP VM instance
- Domain name (optional)

## Time Estimate

- Guided: 4-5 hours
- Challenge: 3-4 hours

---

## Tier 1: Guided Instructions

### Exercise 1: Initial Server Setup

```bash
# Connect to fresh server
ssh -i ~/.ssh/your-key.pem ubuntu@YOUR_SERVER_IP

# Update system
sudo apt update && sudo apt upgrade -y

# Set hostname
sudo hostnamectl set-hostname prod-server-01
echo "127.0.0.1 prod-server-01" | sudo tee -a /etc/hosts

# Set timezone
sudo timedatectl set-timezone UTC
timedatectl

# Configure NTP
sudo apt install chrony -y
sudo systemctl enable chrony
sudo systemctl start chrony
chronyc tracking

# Create operational user
sudo useradd -m -s /bin/bash -c "Operations User" opsuser
sudo usermod -aG sudo opsuser

# Set up SSH key for ops user
sudo mkdir -p /home/opsuser/.ssh
sudo cp ~/.ssh/authorized_keys /home/opsuser/.ssh/
sudo chown -R opsuser:opsuser /home/opsuser/.ssh
sudo chmod 700 /home/opsuser/.ssh
sudo chmod 600 /home/opsuser/.ssh/authorized_keys

# Install essential packages
sudo apt install -y \
    vim \
    htop \
    iotop \
    net-tools \
    curl \
    wget \
    git \
    unzip \
    jq \
    tree \
    ncdu \
    tmux \
    fail2ban \
    ufw \
    logrotate
```

### Exercise 2: Security Hardening

```bash
# SSH Hardening
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

sudo tee /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
# Security Settings
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 60
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no

# Allowed users
AllowUsers ubuntu opsuser
EOF

# Test and reload
sudo sshd -t && sudo systemctl reload sshd

# Configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable
sudo ufw status verbose

# Configure Fail2ban
sudo tee /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd

# Kernel hardening
sudo tee /etc/sysctl.d/99-security.conf << 'EOF'
# Network security
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

sudo sysctl -p /etc/sysctl.d/99-security.conf
```

### Exercise 3: Web Server Setup

```bash
# Install Nginx
sudo apt install nginx -y

# Create web directories
sudo mkdir -p /var/www/production/html
sudo mkdir -p /var/www/production/logs

# Set ownership
sudo chown -R www-data:www-data /var/www/production

# Create Nginx configuration
sudo tee /etc/nginx/sites-available/production << 'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/production/html;
    index index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Logging
    access_log /var/www/production/logs/access.log;
    error_log /var/www/production/logs/error.log;

    # Locations
    location / {
        try_files $uri $uri/ =404;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # Deny hidden files
    location ~ /\. {
        deny all;
    }

    # Deny sensitive files
    location ~* \.(env|git|htaccess|htpasswd)$ {
        deny all;
    }
}
EOF

# Enable site
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/production /etc/nginx/sites-enabled/

# Create landing page
sudo tee /var/www/production/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Production Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; }
        .status { color: green; }
    </style>
</head>
<body>
    <h1>Production Server</h1>
    <p class="status">Server is operational</p>
    <p>Hostname: <span id="hostname"></span></p>
    <script>
        document.getElementById('hostname').textContent = location.hostname;
    </script>
</body>
</html>
EOF

# Test and start
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

# Test
curl http://localhost
curl http://localhost/health
```

### Exercise 4: SSL/TLS Setup

```bash
# For production, use Let's Encrypt
# For this lab, we'll create self-signed certs

# Create SSL directory
sudo mkdir -p /etc/nginx/ssl

# Generate self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.crt \
    -subj "/C=US/ST=State/L=City/O=Org/CN=$(hostname)"

# Generate DH parameters (takes a few minutes)
sudo openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048

# Create SSL configuration
sudo tee /etc/nginx/conf.d/ssl.conf << 'EOF'
# SSL Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;
ssl_dhparam /etc/nginx/ssl/dhparam.pem;
ssl_stapling off;  # Enable with real certs
EOF

# Update site config for HTTPS
sudo tee /etc/nginx/sites-available/production << 'EOF'
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name _;

    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    root /var/www/production/html;
    index index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    access_log /var/www/production/logs/access.log;
    error_log /var/www/production/logs/error.log;

    location / {
        try_files $uri $uri/ =404;
    }

    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    location ~ /\. {
        deny all;
    }
}
EOF

sudo nginx -t
sudo systemctl reload nginx

# Allow HTTPS in firewall
sudo ufw allow https

# Test
curl -k https://localhost
curl -k https://localhost/health
```

### Exercise 5: Log Management

```bash
# Configure log rotation for application logs
sudo tee /etc/logrotate.d/production << 'EOF'
/var/www/production/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 $(cat /var/run/nginx.pid)
    endscript
}
EOF

# Test logrotate
sudo logrotate -d /etc/logrotate.d/production

# Configure journald
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/retention.conf << 'EOF'
[Journal]
SystemMaxUse=500M
SystemKeepFree=1G
MaxRetentionSec=30day
EOF

sudo systemctl restart systemd-journald

# Create log monitoring script
sudo tee /opt/scripts/log_alert.sh << 'EOF'
#!/bin/bash
# Monitor logs for errors and alert

LOG_FILES=(
    "/var/log/syslog"
    "/var/log/auth.log"
    "/var/www/production/logs/error.log"
)

ALERT_PATTERNS="error|failed|denied|critical|emergency"

for log in "${LOG_FILES[@]}"; do
    if [[ -f "$log" ]]; then
        errors=$(tail -100 "$log" | grep -iE "$ALERT_PATTERNS" | wc -l)
        if [[ $errors -gt 10 ]]; then
            echo "ALERT: High error count in $log: $errors errors"
            # Add notification here (email, slack, etc.)
        fi
    fi
done
EOF

sudo chmod +x /opt/scripts/log_alert.sh

# Add to cron
echo "*/15 * * * * /opt/scripts/log_alert.sh" | sudo tee -a /var/spool/cron/crontabs/root
```

### Exercise 6: Monitoring Setup

```bash
# Create scripts directory
sudo mkdir -p /opt/scripts

# System monitoring script
sudo tee /opt/scripts/system_monitor.sh << 'EOF'
#!/bin/bash
set -euo pipefail

METRICS_FILE="/var/log/system_metrics.log"
ALERT_FILE="/var/log/system_alerts.log"

# Thresholds
CPU_THRESHOLD=80
MEM_THRESHOLD=85
DISK_THRESHOLD=90

timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# CPU usage
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d. -f1)

# Memory usage
mem_usage=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')

# Disk usage
disk_usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

# Log metrics
echo "$timestamp CPU:${cpu_usage}% MEM:${mem_usage}% DISK:${disk_usage}%" >> "$METRICS_FILE"

# Check thresholds and alert
alerts=""
if [[ $cpu_usage -gt $CPU_THRESHOLD ]]; then
    alerts+="HIGH_CPU:${cpu_usage}% "
fi
if [[ $mem_usage -gt $MEM_THRESHOLD ]]; then
    alerts+="HIGH_MEM:${mem_usage}% "
fi
if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
    alerts+="HIGH_DISK:${disk_usage}% "
fi

if [[ -n "$alerts" ]]; then
    echo "$timestamp ALERT: $alerts" >> "$ALERT_FILE"
    # Send notification (email, webhook, etc.)
fi
EOF

sudo chmod +x /opt/scripts/system_monitor.sh

# Add to cron (every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/scripts/system_monitor.sh") | sudo crontab -

# Create status page script
sudo tee /opt/scripts/generate_status.sh << 'EOF'
#!/bin/bash
# Generate status page

STATUS_FILE="/var/www/production/html/status.json"

# Gather metrics
uptime_seconds=$(cat /proc/uptime | awk '{print $1}' | cut -d. -f1)
load=$(cat /proc/loadavg | awk '{print $1}')
mem_free=$(free -m | awk '/^Mem:/ {print $4}')
disk_free=$(df -h / | awk 'NR==2 {print $4}')
nginx_status=$(systemctl is-active nginx)

# Generate JSON
cat > "$STATUS_FILE" << JSON
{
  "status": "operational",
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "metrics": {
    "uptime_seconds": $uptime_seconds,
    "load_average": $load,
    "memory_free_mb": $mem_free,
    "disk_free": "$disk_free"
  },
  "services": {
    "nginx": "$nginx_status"
  }
}
JSON

chmod 644 "$STATUS_FILE"
EOF

sudo chmod +x /opt/scripts/generate_status.sh
sudo /opt/scripts/generate_status.sh

# Add to cron (every minute)
(crontab -l 2>/dev/null; echo "* * * * * /opt/scripts/generate_status.sh") | sudo crontab -

# View status
curl -s https://localhost/status.json -k | jq .
```

### Exercise 7: Backup Configuration

```bash
# Create backup script
sudo tee /opt/scripts/backup.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Configuration
BACKUP_DIR="/var/backups/production"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d-%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup configurations
tar -czf "$BACKUP_DIR/config-$DATE.tar.gz" \
    /etc/nginx \
    /etc/ssh/sshd_config \
    /etc/fail2ban \
    /opt/scripts \
    2>/dev/null || true

# Backup web content
tar -czf "$BACKUP_DIR/www-$DATE.tar.gz" \
    /var/www/production/html \
    2>/dev/null || true

# Remove old backups
find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete

# Log
echo "$(date): Backup completed" >> /var/log/backup.log

# List backups
echo "Current backups:"
ls -lh "$BACKUP_DIR"
EOF

sudo chmod +x /opt/scripts/backup.sh

# Run backup
sudo /opt/scripts/backup.sh

# Schedule daily backup
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/scripts/backup.sh") | sudo crontab -
```

### Exercise 8: Documentation and Runbook

````bash
# Create server documentation
sudo mkdir -p /opt/docs

sudo tee /opt/docs/SERVER_INFO.md << 'EOF'
# Production Server Documentation

## Server Information

- **Hostname**: prod-server-01
- **OS**: Ubuntu 22.04 LTS
- **Purpose**: Web application server
- **Created**: $(date +%Y-%m-%d)

## Access Information

- SSH Port: 22
- SSH Users: ubuntu, opsuser
- Authentication: SSH keys only

## Services

| Service | Port | Status Command |
|---------|------|----------------|
| SSH | 22 | systemctl status sshd |
| Nginx | 80, 443 | systemctl status nginx |
| Fail2ban | - | fail2ban-client status |

## Important Paths

- Web root: /var/www/production/html
- Nginx config: /etc/nginx/sites-available/production
- Logs: /var/www/production/logs/
- Backups: /var/backups/production/
- Scripts: /opt/scripts/

## Monitoring

- System metrics: /var/log/system_metrics.log
- Alerts: /var/log/system_alerts.log
- Status endpoint: https://SERVER_IP/status.json

## Maintenance Tasks

### Update System
```bash
sudo apt update && sudo apt upgrade -y
sudo systemctl reload nginx
```

### Check Logs
```bash
sudo tail -f /var/www/production/logs/access.log
sudo journalctl -f -u nginx
```

### Backup Manually
```bash
sudo /opt/scripts/backup.sh
```

### Check Security
```bash
sudo fail2ban-client status sshd
sudo ufw status
```

## Emergency Procedures

### Service Not Responding
1. Check service status: `sudo systemctl status nginx`
2. Check logs: `sudo journalctl -u nginx -n 50`
3. Restart service: `sudo systemctl restart nginx`

### High Resource Usage
1. Run health check: `/opt/scripts/system_monitor.sh`
2. Check processes: `htop`
3. Check disk: `df -h`
4. Check logs for errors

### Security Incident
1. Check fail2ban: `sudo fail2ban-client status`
2. Check auth log: `sudo tail -100 /var/log/auth.log`
3. Block IP if needed: `sudo ufw deny from IP`
EOF

cat /opt/docs/SERVER_INFO.md

# Create final validation script
sudo tee /opt/scripts/validate_server.sh << 'EOF'
#!/bin/bash

echo "=== Server Validation ==="
echo ""

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

# System checks
echo "--- System ---"
check "[ $(timedatectl show -p NTP --value) = 'yes' ]" "NTP synchronized"
check "[ -f /etc/sysctl.d/99-security.conf ]" "Kernel hardening configured"

# Security checks
echo ""
echo "--- Security ---"
check "sudo sshd -T | grep -qi 'passwordauthentication no'" "Password auth disabled"
check "sudo sshd -T | grep -qi 'permitrootlogin no'" "Root login disabled"
check "sudo ufw status | grep -q 'Status: active'" "Firewall active"
check "systemctl is-active --quiet fail2ban" "Fail2ban running"

# Web server checks
echo ""
echo "--- Web Server ---"
check "systemctl is-active --quiet nginx" "Nginx running"
check "curl -s -o /dev/null -w '%{http_code}' http://localhost | grep -q '301\|200'" "HTTP responding"
check "curl -sk -o /dev/null -w '%{http_code}' https://localhost | grep -q '200'" "HTTPS responding"
check "curl -sk https://localhost/health | grep -q 'OK'" "Health endpoint working"

# Monitoring checks
echo ""
echo "--- Monitoring ---"
check "[ -x /opt/scripts/system_monitor.sh ]" "Monitoring script exists"
check "[ -x /opt/scripts/backup.sh ]" "Backup script exists"
check "crontab -l | grep -q system_monitor" "Monitoring cron configured"
check "crontab -l | grep -q backup" "Backup cron configured"

# Documentation checks
echo ""
echo "--- Documentation ---"
check "[ -f /opt/docs/SERVER_INFO.md ]" "Server documentation exists"

echo ""
echo "=== Validation Complete ==="
EOF

sudo chmod +x /opt/scripts/validate_server.sh
sudo /opt/scripts/validate_server.sh
````

---

## Tier 2: Semi-Guided Exercises

### Exercise A: High Availability Setup

Extend the setup for high availability:

1. Deploy second server with identical configuration
2. Set up floating IP between servers
3. Configure health check-based failover
4. Test failover scenarios
5. Document HA procedures

### Exercise B: Application Deployment

Deploy a real application:

1. Set up Node.js or Python application
2. Configure as systemd service
3. Set up reverse proxy
4. Configure environment variables
5. Implement zero-downtime deployment

### Exercise C: Centralized Logging

Set up centralized log management:

1. Install Elasticsearch or Loki
2. Configure log shipping
3. Create dashboards
4. Set up alerts
5. Implement log retention policies

---

## Tier 3: Challenge

Build a complete production infrastructure:

1. **Multi-Server Setup**
   - Load balancer
   - Multiple web servers
   - Database server
   - Monitoring server

2. **Security Implementation**
   - WAF configuration
   - Intrusion detection
   - Security scanning
   - Compliance checking

3. **Automation**
   - Infrastructure as Code
   - Configuration management
   - Automated deployments
   - Auto-scaling

4. **Operations**
   - Complete runbooks
   - Incident response procedures
   - Disaster recovery plan
   - SLA monitoring

---

## Final Validation

```bash
# Run complete validation
echo "=== Production Server Final Check ==="

# Security audit
sudo /opt/scripts/validate_server.sh

# Performance check
uptime
free -h
df -h

# Service status
systemctl is-active nginx fail2ban

# Test endpoints
curl -sk https://localhost/health
curl -sk https://localhost/status.json | jq .

echo ""
echo "Server setup complete!"
echo "Documentation: /opt/docs/SERVER_INFO.md"
```

---

## Key Takeaways

1. **Security first** - Harden before deploying
2. **Automate everything** - Scripts for all common tasks
3. **Monitor proactively** - Don't wait for users to report issues
4. **Document thoroughly** - Future you will thank you
5. **Backup regularly** - Test restores too
6. **Plan for failure** - Everything will break eventually

---

## Phase 1 Complete!

Congratulations! You've completed Phase 1: Linux & Networking. You now have:

- Strong Linux administration skills
- Network configuration knowledge
- Security hardening experience
- Troubleshooting capabilities
- Production server management skills

Next: Phase 2: Containers & Orchestration

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Server Information
- Access Information
- Services
- Important Paths

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
