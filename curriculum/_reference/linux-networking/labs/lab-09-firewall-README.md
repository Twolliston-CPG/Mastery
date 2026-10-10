# Lab 09: Firewall Configuration

## Overview

Configure Linux firewalls using iptables, nftables, and UFW to secure your servers. Firewalls are the first line of defense for network security, controlling what traffic can enter and leave your systems.

## Objectives

- Understand firewall concepts and chains
- Configure iptables rules
- Use UFW for simplified firewall management
- Implement nftables (modern replacement)
- Create firewall scripts and persistence

## Prerequisites

- Lab 08 completed
- SSH access to Linux VM
- Understanding of TCP/IP ports

## Time Estimate

- Guided: 2-3 hours
- Challenge: 1-2 hours

---

## Tier 1: Guided Instructions

### Exercise 1: Firewall Concepts

```bash
# Check current firewall status
sudo iptables -L -n -v

# Understanding chains:
# INPUT: Traffic coming TO this machine
# OUTPUT: Traffic going FROM this machine
# FORWARD: Traffic passing THROUGH this machine (routing)

# View detailed rules
sudo iptables -L INPUT -n -v --line-numbers
sudo iptables -L OUTPUT -n -v --line-numbers
sudo iptables -L FORWARD -n -v --line-numbers

# View NAT table
sudo iptables -t nat -L -n -v

# Check if nftables is available
nft --version 2>/dev/null || echo "nftables not available"

# Check UFW status (Ubuntu)
sudo ufw status verbose
```

### Exercise 2: iptables Basics

```bash
# WARNING: Be careful! Wrong rules can lock you out!
# Always have console access as backup

# View current rules
sudo iptables -L -n -v

# Set default policies (be careful!)
# Only run these if you understand the consequences
# sudo iptables -P INPUT DROP
# sudo iptables -P FORWARD DROP
# sudo iptables -P OUTPUT ACCEPT

# Allow loopback
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (IMPORTANT - don't lock yourself out!)
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow ICMP (ping)
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# View rules with line numbers
sudo iptables -L INPUT -n -v --line-numbers

# Delete specific rule by number
# sudo iptables -D INPUT 5

# Insert rule at specific position
# sudo iptables -I INPUT 1 -p tcp --dport 8080 -j ACCEPT
```

### Exercise 3: Advanced iptables Rules

```bash
# Rate limiting (prevent brute force)
sudo iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW \
    -m recent --set --name ssh --rsource
sudo iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW \
    -m recent --update --seconds 60 --hitcount 4 --name ssh --rsource -j DROP

# Allow from specific IP
sudo iptables -A INPUT -s 192.168.1.100 -j ACCEPT

# Allow from subnet
sudo iptables -A INPUT -s 192.168.1.0/24 -j ACCEPT

# Block specific IP
sudo iptables -A INPUT -s 10.10.10.10 -j DROP

# Log dropped packets
sudo iptables -A INPUT -j LOG --log-prefix "IPTables-Dropped: " --log-level 4

# Port range
sudo iptables -A INPUT -p tcp --dport 8000:8100 -j ACCEPT

# Multiple ports
sudo iptables -A INPUT -p tcp -m multiport --dports 80,443,8080 -j ACCEPT

# Time-based rules
sudo iptables -A INPUT -p tcp --dport 22 -m time --timestart 09:00 --timestop 17:00 --days Mon,Tue,Wed,Thu,Fri -j ACCEPT

# Connection limiting (per IP)
sudo iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 20 -j REJECT
```

### Exercise 4: iptables NAT and Port Forwarding

```bash
# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Masquerade (NAT for outgoing traffic)
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Port forwarding (DNAT)
# Forward port 8080 to internal server 192.168.1.100:80
sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.1.100:80
sudo iptables -A FORWARD -p tcp -d 192.168.1.100 --dport 80 -j ACCEPT

# View NAT rules
sudo iptables -t nat -L -n -v

# Redirect local port
sudo iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-port 8080
```

### Exercise 5: UFW (Uncomplicated Firewall)

```bash
# Enable UFW (careful - may disrupt connections!)
# First, ensure SSH is allowed
sudo ufw allow ssh
# Or by port
sudo ufw allow 22/tcp

# Enable UFW
sudo ufw enable

# Check status
sudo ufw status verbose
sudo ufw status numbered

# Allow services
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 'Apache Full'
sudo ufw allow 'Nginx Full'

# Allow specific port
sudo ufw allow 8080/tcp
sudo ufw allow 3000:3100/tcp  # Port range

# Allow from IP
sudo ufw allow from 192.168.1.100
sudo ufw allow from 192.168.1.0/24

# Allow from IP to specific port
sudo ufw allow from 192.168.1.100 to any port 22

# Deny rules
sudo ufw deny 23/tcp
sudo ufw deny from 10.10.10.10

# Delete rules
sudo ufw delete allow 8080/tcp
# Or by number
sudo ufw delete 3

# Rate limiting
sudo ufw limit ssh

# Logging
sudo ufw logging on
sudo ufw logging medium

# Application profiles
sudo ufw app list
sudo ufw app info 'Nginx Full'

# Reset firewall
# sudo ufw reset

# Disable UFW
# sudo ufw disable
```

### Exercise 6: nftables Configuration

```bash
# nftables is the modern replacement for iptables
# Check if installed
nft --version

# View current ruleset
sudo nft list ruleset

# Create basic firewall
sudo nft add table inet filter

# Create chains
sudo nft add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
sudo nft add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
sudo nft add chain inet filter output { type filter hook output priority 0 \; policy accept \; }

# Add rules
# Allow loopback
sudo nft add rule inet filter input iif lo accept

# Allow established connections
sudo nft add rule inet filter input ct state established,related accept

# Allow SSH
sudo nft add rule inet filter input tcp dport 22 accept

# Allow HTTP/HTTPS
sudo nft add rule inet filter input tcp dport { 80, 443 } accept

# Allow ICMP
sudo nft add rule inet filter input ip protocol icmp accept

# View ruleset
sudo nft list ruleset

# Save configuration
sudo nft list ruleset > /tmp/nftables.conf

# Create complete nftables config file
cat > /tmp/nftables-complete.conf << 'EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Allow loopback
        iif lo accept

        # Allow established/related connections
        ct state established,related accept

        # Allow ICMP
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept

        # Allow SSH
        tcp dport 22 accept

        # Allow HTTP/HTTPS
        tcp dport { 80, 443 } accept

        # Log dropped packets
        log prefix "nftables-dropped: " counter drop
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

# Apply configuration
# sudo nft -f /tmp/nftables-complete.conf
```

### Exercise 7: Firewall Script

```bash
cat > ~/scripts/firewall.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Firewall Configuration Script
# Usage: sudo ./firewall.sh [start|stop|status]

IPTABLES="/sbin/iptables"
ACTION=${1:-status}

start_firewall() {
    echo "Starting firewall..."

    # Flush existing rules
    $IPTABLES -F
    $IPTABLES -X
    $IPTABLES -t nat -F
    $IPTABLES -t nat -X
    $IPTABLES -t mangle -F
    $IPTABLES -t mangle -X

    # Set default policies
    $IPTABLES -P INPUT DROP
    $IPTABLES -P FORWARD DROP
    $IPTABLES -P OUTPUT ACCEPT

    # Allow loopback
    $IPTABLES -A INPUT -i lo -j ACCEPT
    $IPTABLES -A OUTPUT -o lo -j ACCEPT

    # Allow established connections
    $IPTABLES -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Anti-spoofing
    $IPTABLES -A INPUT -s 127.0.0.0/8 ! -i lo -j DROP
    $IPTABLES -A INPUT -s 0.0.0.0/8 -j DROP
    $IPTABLES -A INPUT -s 169.254.0.0/16 -j DROP
    $IPTABLES -A INPUT -s 224.0.0.0/4 -j DROP
    $IPTABLES -A INPUT -s 240.0.0.0/5 -j DROP

    # Allow SSH (with rate limiting)
    $IPTABLES -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW \
        -m recent --set --name ssh --rsource
    $IPTABLES -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW \
        -m recent --update --seconds 60 --hitcount 4 --name ssh --rsource -j DROP
    $IPTABLES -A INPUT -p tcp --dport 22 -j ACCEPT

    # Allow HTTP/HTTPS
    $IPTABLES -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT

    # Allow ICMP (ping)
    $IPTABLES -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT

    # Log dropped packets (limit to avoid log flooding)
    $IPTABLES -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables-dropped: " --log-level 4

    # Drop everything else
    $IPTABLES -A INPUT -j DROP

    echo "Firewall started."
}

stop_firewall() {
    echo "Stopping firewall..."

    # Flush all rules
    $IPTABLES -F
    $IPTABLES -X
    $IPTABLES -t nat -F
    $IPTABLES -t nat -X
    $IPTABLES -t mangle -F
    $IPTABLES -t mangle -X

    # Set default policies to ACCEPT
    $IPTABLES -P INPUT ACCEPT
    $IPTABLES -P FORWARD ACCEPT
    $IPTABLES -P OUTPUT ACCEPT

    echo "Firewall stopped."
}

status_firewall() {
    echo "=== Firewall Status ==="
    echo ""
    echo "--- INPUT Chain ---"
    $IPTABLES -L INPUT -n -v --line-numbers
    echo ""
    echo "--- OUTPUT Chain ---"
    $IPTABLES -L OUTPUT -n -v --line-numbers
    echo ""
    echo "--- FORWARD Chain ---"
    $IPTABLES -L FORWARD -n -v --line-numbers
}

save_firewall() {
    echo "Saving firewall rules..."
    if command -v iptables-save &>/dev/null; then
        iptables-save > /etc/iptables/rules.v4
        echo "Rules saved to /etc/iptables/rules.v4"
    else
        echo "iptables-save not found. Install iptables-persistent."
    fi
}

case "$ACTION" in
    start)
        start_firewall
        ;;
    stop)
        stop_firewall
        ;;
    restart)
        stop_firewall
        start_firewall
        ;;
    status)
        status_firewall
        ;;
    save)
        save_firewall
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|save}"
        exit 1
        ;;
esac
EOF

chmod +x ~/scripts/firewall.sh

# View status
sudo ~/scripts/firewall.sh status
```

### Exercise 8: Firewall Persistence

```bash
# Install iptables-persistent (Debian/Ubuntu)
sudo apt install iptables-persistent -y

# Save current rules
sudo netfilter-persistent save

# Rules are saved to:
# /etc/iptables/rules.v4
# /etc/iptables/rules.v6

# View saved rules
cat /etc/iptables/rules.v4

# Reload rules
sudo netfilter-persistent reload

# Alternative: Create systemd service for custom script
sudo tee /etc/systemd/system/custom-firewall.service << 'EOF'
[Unit]
Description=Custom Firewall Service
After=network.target

[Service]
Type=oneshot
ExecStart=/home/ubuntu/scripts/firewall.sh start
ExecStop=/home/ubuntu/scripts/firewall.sh stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable custom firewall service
# sudo systemctl enable custom-firewall
# sudo systemctl start custom-firewall
```

---

## Tier 2: Semi-Guided Exercises

### Exercise A: Multi-Zone Firewall

Create a firewall with multiple security zones:

1. **DMZ zone**: Web servers (ports 80, 443)
2. **Internal zone**: Application servers (limited ports)
3. **Management zone**: Admin access only (SSH, monitoring)
4. Configure zone-to-zone traffic rules
5. Implement logging for all cross-zone traffic

### Exercise B: Stateful Inspection Rules

Implement advanced stateful firewall rules:

1. Track FTP connections (active and passive)
2. Handle connection tracking helpers
3. Implement connection timeouts
4. Configure per-protocol states
5. Monitor connection tracking table

### Exercise C: Firewall with Fail2ban

Integrate Fail2ban with your firewall:

1. Install and configure Fail2ban
2. Set up jails for SSH, Apache, Nginx
3. Configure ban actions
4. Test with simulated attacks
5. Monitor and maintain ban lists

---

## Tier 3: Challenge

Build a complete network security solution:

1. **Perimeter Firewall**
   - DMZ configuration
   - NAT/PAT setup
   - Port forwarding rules
   - DDoS mitigation rules

2. **Host-Based Firewall**
   - Minimal open ports
   - Application-specific rules
   - Egress filtering
   - Process-based filtering

3. **Security Monitoring**
   - Log all dropped packets
   - Alert on attack patterns
   - Traffic analysis
   - Compliance reporting

4. **Automation**
   - Firewall deployment script
   - Configuration management
   - Backup and restore
   - Testing framework

---

## Validation Script

```bash
#!/bin/bash

echo "=== Firewall Lab Validation ==="

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

# Check iptables
check "sudo iptables -L -n" "iptables is available"

# Check UFW
check "sudo ufw status" "UFW is available"

# Check SSH is allowed
check "sudo iptables -L INPUT -n | grep -E 'dpt:22|dport 22' || sudo ufw status | grep '22/tcp'" "SSH port is allowed"

# Check firewall script exists
check "[ -f ~/scripts/firewall.sh ]" "Firewall script exists"
check "[ -x ~/scripts/firewall.sh ]" "Firewall script is executable"

# Check for default DROP policy or UFW enabled
check "sudo iptables -L INPUT | grep -q 'policy DROP' || sudo ufw status | grep -q 'Status: active'" "Firewall is protecting system"

echo ""
echo "Validation complete!"
```

---

## Key Takeaways

1. **Order matters** - Rules are processed in sequence
2. **Allow SSH first** - Don't lock yourself out!
3. **Use stateful rules** - ESTABLISHED,RELATED for efficiency
4. **Log dropped packets** - For troubleshooting and security
5. **Persist rules** - Survive reboots
6. **Test thoroughly** - Before applying in production

---

## Next Lab

[Lab 10: Web Server Setup](../lab-10-web-server/)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Firewall Concepts
- iptables Basics
- Advanced iptables Rules
- iptables NAT and Port Forwarding

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
