# Module 10: Network Troubleshooting

## Introduction

Network issues can be among the most challenging problems to diagnose. This module provides a systematic approach to network troubleshooting, covering essential diagnostic tools and techniques used by DevOps engineers.

## Learning Objectives

After completing this module, you will be able to:
- Follow a systematic troubleshooting methodology
- Use network diagnostic tools effectively
- Analyze network traffic
- Debug common network issues

## Troubleshooting Methodology

### The OSI Model Approach

**Bottom-up troubleshooting**

Start at the physical layer and work up. Each layer is only worth testing once the one below it
works.

| | Layer | Check | Tools |
|---|---|---|---|
| 7 | Application | Does the protocol respond correctly? | `curl` · `dig` · `telnet` |
| 6 | Presentation | Encryption, compression | `openssl s_client` |
| 5 | Session | Session establishment | — |
| 4 | Transport | Is the port open, is the connection established? | `ss` · `netstat` · `nc` |
| 3 | Network | Addressing and routing | `ping` · `traceroute` · `ip route` |
| 2 | Data link | MAC resolution, switching | `arp` · `ip neigh` |
| 1 | **Physical** | Link up, cable, NIC | `ethtool` · `ip link` |

**Start at the bottom.** It feels slower and it is faster: debugging a TLS handshake for twenty
minutes on a host whose interface is down is the single most common way to lose an afternoon. One
`ip link` first would have said so.

The exception is when the failure is *intermittent* — then start at the layer that reports the error,
because a working `ping` proves nothing about the moment the request failed.

### Basic Troubleshooting Steps

```bash
# 1. Check local interface
ip link show
ip addr show

# 2. Check connectivity to gateway
ip route show
ping -c 3 $(ip route | grep default | awk '{print $3}')

# 3. Check DNS resolution
cat /etc/resolv.conf
dig google.com

# 4. Check connectivity to destination
ping -c 3 destination_host
traceroute destination_host

# 5. Check service availability
nc -zv destination_host port
curl -v http://destination_host
```

## Essential Diagnostic Tools

### ping - ICMP Connectivity

```bash
# Basic ping
ping google.com

# Specific count
ping -c 5 google.com

# Set interval
ping -i 0.5 google.com

# Set packet size
ping -s 1500 google.com

# Flood ping (root, for testing)
sudo ping -f google.com

# Set source interface
ping -I eth0 google.com

# Interpreting results
# 64 bytes from 172.217.14.110: icmp_seq=1 ttl=115 time=10.5 ms
# - 64 bytes: Response size
# - icmp_seq: Sequence number
# - ttl: Time to Live (hops)
# - time: Round-trip time
```

### traceroute/tracepath - Path Analysis

```bash
# Basic traceroute
traceroute google.com

# Use ICMP instead of UDP
traceroute -I google.com

# Use TCP
traceroute -T -p 443 google.com

# Set max hops
traceroute -m 20 google.com

# tracepath (no root required)
tracepath google.com

# MTR - combines ping and traceroute
mtr google.com
mtr --report google.com
mtr --report-cycles 10 google.com
```

### netstat/ss - Socket Statistics

```bash
# List all connections
ss -a

# List listening sockets
ss -l
ss -lt   # TCP only
ss -lu   # UDP only

# Show process information
ss -ltp

# Show timer information
ss -o

# Filter by state
ss state established
ss state listening

# Filter by port
ss -lt sport = :80
ss -t dst :443

# Show statistics
ss -s

# Legacy netstat equivalents
netstat -tulpn  # Listen TCP/UDP with process
netstat -an     # All connections numeric
```

### ip Command Suite

```bash
# Show interfaces
ip link show
ip link show eth0

# Show IP addresses
ip addr show
ip -4 addr show  # IPv4 only
ip -6 addr show  # IPv6 only

# Show routing table
ip route show
ip route get 8.8.8.8

# Show ARP/neighbor cache
ip neigh show

# Add/remove IP
sudo ip addr add 192.168.1.100/24 dev eth0
sudo ip addr del 192.168.1.100/24 dev eth0

# Enable/disable interface
sudo ip link set eth0 up
sudo ip link set eth0 down

# Add route
sudo ip route add 10.0.0.0/8 via 192.168.1.1
```

### nc (netcat) - Network Swiss Army Knife

```bash
# Test TCP port connectivity
nc -zv host 80
nc -zv host 22-25   # Port range

# Test UDP port
nc -zu host 53

# Simple chat/transfer
# Server: nc -l 1234
# Client: nc host 1234

# Port scanning
nc -zv host 1-1000

# Banner grabbing
echo "" | nc -v host 80

# HTTP request
echo -e "GET / HTTP/1.1\nHost: example.com\n\n" | nc example.com 80
```

### tcpdump - Packet Capture

```bash
# Capture on interface
sudo tcpdump -i eth0

# Capture specific host
sudo tcpdump host 192.168.1.1

# Capture specific port
sudo tcpdump port 80
sudo tcpdump port 443 or port 80

# Capture specific protocol
sudo tcpdump tcp
sudo tcpdump udp
sudo tcpdump icmp

# Show packet contents
sudo tcpdump -X port 80

# Write to file
sudo tcpdump -w capture.pcap

# Read from file
tcpdump -r capture.pcap

# Useful filters
sudo tcpdump 'tcp[tcpflags] & (tcp-syn) != 0'  # SYN packets
sudo tcpdump 'tcp[tcpflags] & (tcp-rst) != 0'  # RST packets

# Limit output
sudo tcpdump -c 100  # Stop after 100 packets
```

### nmap - Network Scanner

```bash
# Ping scan (host discovery)
nmap -sn 192.168.1.0/24

# Port scan
nmap 192.168.1.1
nmap -p 80,443 192.168.1.1
nmap -p 1-1000 192.168.1.1
nmap -p- 192.168.1.1  # All ports

# Service version detection
nmap -sV 192.168.1.1

# OS detection
sudo nmap -O 192.168.1.1

# Aggressive scan
nmap -A 192.168.1.1

# UDP scan
sudo nmap -sU 192.168.1.1

# Scan types
nmap -sT  # TCP connect
nmap -sS  # TCP SYN (stealth)
nmap -sU  # UDP
```

## Common Network Issues

### DNS Resolution Failures

```bash
# Symptoms
ping hostname        # Fails
ping IP_address      # Works

# Diagnostics
cat /etc/resolv.conf
dig hostname
dig @8.8.8.8 hostname

# Solutions
# 1. Check DNS server configuration
# 2. Test alternate DNS servers
# 3. Clear DNS cache
sudo systemd-resolve --flush-caches
# 4. Check /etc/hosts for overrides
# 5. Verify network connectivity to DNS server
```

### Connection Refused

```bash
# Symptoms
curl: (7) Failed to connect: Connection refused
nc: Connection refused

# Diagnostics
ss -lt | grep port     # Is service listening?
sudo netstat -tlpn     # Show listening services
systemctl status service_name

# Solutions
# 1. Start the service
# 2. Check it's listening on correct port/interface
# 3. Check firewall rules
sudo iptables -L -n
```

### Connection Timeout

```bash
# Symptoms
curl: (28) Connection timed out
ssh: connect to host: Connection timed out

# Diagnostics
traceroute hostname    # Where does it fail?
ping hostname          # Basic connectivity
telnet hostname port   # Port-specific test

# Common causes
# 1. Firewall blocking traffic
# 2. Routing issues
# 3. Network ACLs
# 4. Service not running
# 5. Wrong IP/port
```

### Packet Loss

```bash
# Detection
ping -c 100 hostname | tail -3
# 100 packets transmitted, 95 received, 5% packet loss

mtr --report hostname

# Common causes
# 1. Network congestion
# 2. Hardware issues
# 3. MTU problems
# 4. Duplex mismatch

# MTU troubleshooting
ping -M do -s 1472 hostname  # Test MTU
```

### High Latency

```bash
# Detection
ping hostname
# Look for high 'time=' values

mtr hostname
# Look for high avg times

# Diagnostics
traceroute hostname  # Find slow hop

# Common causes
# 1. Geographic distance
# 2. Congested links
# 3. Routing inefficiency
# 4. QoS configuration
```

## Troubleshooting Scripts

### Comprehensive Network Check

```bash
#!/bin/bash
# network-diagnostics.sh

TARGET=${1:-google.com}
echo "=== Network Diagnostics for $TARGET ==="

echo -e "\n--- Local Interface ---"
ip addr show | grep -E "^[0-9]:|inet "

echo -e "\n--- Default Gateway ---"
ip route | grep default

echo -e "\n--- DNS Configuration ---"
cat /etc/resolv.conf | grep -v "^#"

echo -e "\n--- DNS Resolution ---"
dig +short $TARGET

echo -e "\n--- Ping Test ---"
ping -c 3 $TARGET

echo -e "\n--- Traceroute ---"
traceroute -m 15 $TARGET 2>/dev/null || tracepath $TARGET

echo -e "\n--- Port 80 Check ---"
nc -zv $TARGET 80 2>&1

echo -e "\n--- Port 443 Check ---"
nc -zv $TARGET 443 2>&1
```

### Service Connectivity Test

```bash
#!/bin/bash
# test-services.sh

declare -A SERVICES=(
  ["DNS"]="8.8.8.8:53"
  ["HTTP"]="google.com:80"
  ["HTTPS"]="google.com:443"
)

for service in "${!SERVICES[@]}"; do
  IFS=':' read -r host port <<< "${SERVICES[$service]}"
  if nc -zw3 "$host" "$port" 2>/dev/null; then
    echo "✓ $service ($host:$port) - OK"
  else
    echo "✗ $service ($host:$port) - FAILED"
  fi
done
```

## Summary

Key troubleshooting concepts:

1. **Systematic approach** using OSI model layers
2. **ping/traceroute** for connectivity testing
3. **ss/netstat** for socket analysis
4. **tcpdump** for packet capture
5. **nc/nmap** for port testing

## Knowledge Check

1. What is the OSI model and how does it help troubleshooting?
2. How do you test if a specific port is open?
3. What causes "Connection refused" vs "Connection timeout"?
4. How do you capture network traffic for analysis?
5. How do you diagnose packet loss issues?

## Next Module

Continue to [Module 11: Firewalls & Security](./11-firewalls-security.md) for network security.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Troubleshooting Methodology
- Essential Diagnostic Tools
- Common Network Issues
- Troubleshooting Scripts

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
