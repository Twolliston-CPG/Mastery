# Lab 07: Network Configuration

## Overview

Configure and troubleshoot network interfaces, routing, and DNS on Linux systems. Understanding network configuration is essential for managing servers and troubleshooting connectivity issues.

## Objectives

- Configure network interfaces
- Set up static and dynamic IP addressing
- Configure routing tables
- Manage DNS resolution
- Troubleshoot network connectivity

## Prerequisites

- Lab 06 completed
- Basic networking knowledge
- AWS/GCP VM with network access

## Time Estimate

- Guided: 2-3 hours
- Challenge: 1-2 hours

---

## Tier 1: Guided Instructions

### Exercise 1: Network Interface Basics

```bash
# View all interfaces
ip link show
ip -br link show

# View interface details
ip addr show
ip -br addr show

# View specific interface
ip addr show eth0

# Traditional commands (deprecated but useful)
ifconfig -a 2>/dev/null || sudo apt install net-tools -y && ifconfig -a

# View interface statistics
ip -s link show eth0

# View interface driver info
ethtool eth0 2>/dev/null || sudo apt install ethtool -y
sudo ethtool eth0
```

### Exercise 2: IP Address Configuration

```bash
# View current IP configuration
ip addr show eth0

# Add IP address (temporary - lost on reboot)
sudo ip addr add 192.168.100.10/24 dev eth0
ip addr show eth0

# Remove IP address
sudo ip addr del 192.168.100.10/24 dev eth0

# Bring interface down/up
sudo ip link set eth0 down
sudo ip link set eth0 up

# View network configuration files (Ubuntu/Debian with Netplan)
cat /etc/netplan/*.yaml

# Example Netplan configuration for static IP
cat > /tmp/netplan-example.yaml << 'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF

cat /tmp/netplan-example.yaml

# Example Netplan for DHCP
cat > /tmp/netplan-dhcp.yaml << 'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
EOF

cat /tmp/netplan-dhcp.yaml
```

### Exercise 3: Routing

```bash
# View routing table
ip route show
ip route list

# Traditional command
route -n 2>/dev/null || netstat -rn

# View default gateway
ip route show default

# Add static route (temporary)
sudo ip route add 10.0.0.0/8 via 192.168.1.1 dev eth0
ip route show

# Remove route
sudo ip route del 10.0.0.0/8 via 192.168.1.1 dev eth0

# Add default gateway
# sudo ip route add default via 192.168.1.1 dev eth0

# View routing to specific destination
ip route get 8.8.8.8

# Enable IP forwarding (for routing between interfaces)
cat /proc/sys/net/ipv4/ip_forward
# Enable temporarily
sudo sysctl -w net.ipv4.ip_forward=1

# Enable permanently
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.d/99-ip-forward.conf
sudo sysctl -p /etc/sysctl.d/99-ip-forward.conf
```

### Exercise 4: DNS Configuration

```bash
# View current DNS configuration
cat /etc/resolv.conf

# On systemd-resolved systems
resolvectl status
systemd-resolve --status 2>/dev/null || resolvectl status

# Test DNS resolution
nslookup google.com
dig google.com
host google.com

# Query specific DNS server
nslookup google.com 8.8.8.8
dig @8.8.8.8 google.com

# View DNS cache (systemd-resolved)
resolvectl statistics

# Flush DNS cache
sudo resolvectl flush-caches
resolvectl statistics

# Check /etc/hosts
cat /etc/hosts

# Add local hostname resolution
echo "192.168.1.100 myserver.local myserver" | sudo tee -a /etc/hosts
ping -c 2 myserver.local

# Remove the test entry
sudo sed -i '/myserver.local/d' /etc/hosts
```

### Exercise 5: Network Troubleshooting Tools

```bash
# Test connectivity
ping -c 4 8.8.8.8
ping -c 4 google.com

# Trace route
traceroute google.com 2>/dev/null || sudo apt install traceroute -y && traceroute google.com
# Alternative
tracepath google.com

# MTR (combines ping and traceroute)
mtr --report --report-cycles 5 google.com 2>/dev/null || \
    sudo apt install mtr -y && mtr --report --report-cycles 5 google.com

# Check open ports locally
ss -tuln
netstat -tuln 2>/dev/null

# Check listening services
sudo ss -tulnp
sudo netstat -tulnp 2>/dev/null

# Test port connectivity
nc -zv google.com 443
nc -zv google.com 80

# Test with timeout
timeout 5 bash -c 'cat < /dev/tcp/google.com/443 && echo "Port open"' 2>/dev/null && echo "Connected" || echo "Failed"

# Check ARP table
ip neigh show
arp -n 2>/dev/null
```

### Exercise 6: Network Namespaces

```bash
# List network namespaces
ip netns list

# Create network namespace
sudo ip netns add testns
ip netns list

# Run command in namespace
sudo ip netns exec testns ip link show

# Create virtual ethernet pair
sudo ip link add veth0 type veth peer name veth1

# Move one end to namespace
sudo ip link set veth1 netns testns

# Configure interfaces
sudo ip addr add 192.168.100.1/24 dev veth0
sudo ip link set veth0 up

sudo ip netns exec testns ip addr add 192.168.100.2/24 dev veth1
sudo ip netns exec testns ip link set veth1 up
sudo ip netns exec testns ip link set lo up

# Test connectivity
sudo ip netns exec testns ping -c 3 192.168.100.1
ping -c 3 192.168.100.2

# View namespace routing
sudo ip netns exec testns ip route

# Cleanup
sudo ip netns delete testns
sudo ip link delete veth0 2>/dev/null
```

### Exercise 7: Network Monitoring Script

```bash
cat > ~/scripts/network_monitor.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Network Monitoring Script

LOG_FILE="/tmp/network_monitor.log"
TARGETS=("8.8.8.8" "1.1.1.1" "google.com")
CHECK_INTERVAL=${1:-30}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_connectivity() {
    local target=$1
    local result

    if ping -c 1 -W 2 "$target" &>/dev/null; then
        result="UP"
    else
        result="DOWN"
    fi

    log "Target: $target - Status: $result"
    echo "$result"
}

check_dns() {
    local domain=$1
    local result

    if nslookup "$domain" &>/dev/null; then
        result="OK"
    else
        result="FAIL"
    fi

    log "DNS: $domain - Status: $result"
    echo "$result"
}

get_interface_stats() {
    local interface=${1:-eth0}

    if [[ -d /sys/class/net/$interface ]]; then
        local rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes)
        local tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes)

        log "Interface $interface - RX: $(numfmt --to=iec $rx_bytes) TX: $(numfmt --to=iec $tx_bytes)"
    fi
}

main() {
    log "=== Network Monitor Started ==="
    log "Check interval: ${CHECK_INTERVAL}s"

    while true; do
        log "--- Check Cycle ---"

        for target in "${TARGETS[@]}"; do
            check_connectivity "$target"
        done

        check_dns "google.com"
        get_interface_stats "eth0"

        sleep "$CHECK_INTERVAL"
    done
}

# Run for limited time in demo
timeout 60 bash -c "$(declare -f log check_connectivity check_dns get_interface_stats main); TARGETS=(${TARGETS[*]}); CHECK_INTERVAL=10; main" || true
EOF

chmod +x ~/scripts/network_monitor.sh
```

### Exercise 8: Network Configuration Backup

```bash
cat > ~/scripts/backup_network_config.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Backup network configuration

BACKUP_DIR="/tmp/network-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "=== Network Configuration Backup ==="
echo "Backup directory: $BACKUP_DIR"

# Backup Netplan configuration
if [[ -d /etc/netplan ]]; then
    cp -r /etc/netplan "$BACKUP_DIR/"
    echo "✓ Netplan configuration backed up"
fi

# Backup interface configuration
if [[ -d /etc/network ]]; then
    cp -r /etc/network "$BACKUP_DIR/"
    echo "✓ /etc/network backed up"
fi

# Backup DNS configuration
cp /etc/resolv.conf "$BACKUP_DIR/"
echo "✓ resolv.conf backed up"

# Backup hosts file
cp /etc/hosts "$BACKUP_DIR/"
echo "✓ hosts file backed up"

# Export current configuration
{
    echo "=== IP Configuration ==="
    ip addr show

    echo ""
    echo "=== Routing Table ==="
    ip route show

    echo ""
    echo "=== DNS Configuration ==="
    cat /etc/resolv.conf

    echo ""
    echo "=== Active Connections ==="
    ss -tuln
} > "$BACKUP_DIR/current-config.txt"

echo "✓ Current configuration exported"

# Create restore script
cat > "$BACKUP_DIR/restore.sh" << 'RESTORE'
#!/bin/bash
# Network configuration restore script
# WARNING: Review before running!

echo "This script needs to be customized for your environment"
echo "Review the backed up files in this directory"
echo "Then manually restore the configuration"

# Example commands (uncomment and modify as needed):
# sudo cp netplan/* /etc/netplan/
# sudo netplan apply

# For /etc/network/interfaces:
# sudo cp network/interfaces /etc/network/interfaces
# sudo systemctl restart networking
RESTORE

chmod +x "$BACKUP_DIR/restore.sh"

echo ""
echo "Backup complete!"
echo "Contents:"
ls -la "$BACKUP_DIR"
EOF

chmod +x ~/scripts/backup_network_config.sh
~/scripts/backup_network_config.sh
```

---

## Tier 2: Semi-Guided Exercises

### Exercise A: Multi-Interface Configuration

Configure a server with multiple network interfaces:

1. Set up primary interface with static IP
2. Set up secondary interface with different subnet
3. Configure routing between interfaces
4. Test connectivity from both networks
5. Create a script to switch between configurations

### Exercise B: Network Bonding/Teaming

Set up network interface bonding for high availability:

1. Create a bonded interface with two NICs
2. Configure active-backup mode
3. Test failover scenarios
4. Monitor bond status
5. Configure LACP bonding mode

### Exercise C: VLAN Configuration

Configure VLANs on a Linux server:

1. Install vlan package
2. Create VLAN interfaces
3. Configure VLAN tagging
4. Set up inter-VLAN routing
5. Test VLAN isolation

---

## Tier 3: Challenge

Build a complete network configuration toolkit with:

1. **Network Audit Script**
   - Inventory all interfaces and configurations
   - Check for common misconfigurations
   - Validate DNS and routing
   - Generate compliance report

2. **Automated Network Setup**
   - Script to configure server from scratch
   - Support for static and DHCP
   - Configure DNS, routing, firewall
   - Apply security hardening

3. **Network Troubleshooting Tool**
   - Diagnose connectivity issues
   - Test all network layers
   - Generate diagnostic report
   - Suggest fixes

4. **High Availability Setup**
   - Multiple interfaces
   - Failover routing
   - Health checks
   - Automatic recovery

---

## Key Takeaways

1. **ip command is modern** - Use instead of ifconfig
2. **Netplan is Ubuntu standard** - Learn YAML syntax
3. **Routing matters** - Understand default gateway
4. **DNS is critical** - Know how to troubleshoot
5. **Network namespaces** - Foundation for containers
6. **Always backup** - Before making network changes

---

## Next Lab

[Lab 08: SSH Hardening](../lab-08-ssh-hardening/)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Network Interface Basics
- IP Address Configuration
- Routing
- DNS Configuration

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
