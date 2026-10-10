# Lab 08: SSH Hardening

## Overview

Secure SSH access to your servers with proper configuration, key management, and access controls. SSH is the primary remote access method for Linux servers, making its security critical.

## Objectives

- Configure SSH key-based authentication
- Harden SSH server configuration
- Set up SSH tunneling and port forwarding
- Implement SSH bastion/jump hosts
- Configure SSH client for convenience and security

## Prerequisites

- Lab 07 completed
- Two VMs (server and bastion host)
- Basic SSH familiarity

## Time Estimate

- Guided: 2-3 hours
- Challenge: 1-2 hours

---

## Tier 1: Guided Instructions

### Exercise 1: SSH Key Management

```bash
# Generate SSH key pair (on local machine)
ssh-keygen -t ed25519 -C "devops-lab-key" -f ~/.ssh/devops_ed25519
# Ed25519 is modern and secure

# Generate RSA key (wider compatibility)
ssh-keygen -t rsa -b 4096 -C "devops-lab-rsa" -f ~/.ssh/devops_rsa

# View public key
cat ~/.ssh/devops_ed25519.pub

# List keys
ls -la ~/.ssh/

# View key fingerprint
ssh-keygen -lf ~/.ssh/devops_ed25519.pub

# Copy key to server (from local machine)
ssh-copy-id -i ~/.ssh/devops_ed25519.pub ubuntu@<SERVER_IP>

# Manual method (on server)
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Test key authentication
ssh -i ~/.ssh/devops_ed25519 ubuntu@<SERVER_IP>
```

### Exercise 2: SSH Server Configuration

```bash
# View current SSH server config
sudo cat /etc/ssh/sshd_config

# Backup original config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Create hardened configuration
sudo tee /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
# SSH Hardening Configuration

# Authentication
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 60

# Protocol and Algorithms
Protocol 2
KexAlgorithms curve25519-sha256@libssh.org,curve25519-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# Network
Port 22
AddressFamily inet
ListenAddress 0.0.0.0
TCPKeepAlive yes
ClientAliveInterval 300
ClientAliveCountMax 2

# Security
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no
UseDNS no
Compression no

# Logging
LogLevel VERBOSE
SyslogFacility AUTH

# Access Control
AllowUsers ubuntu
# AllowGroups sshusers
# DenyUsers baduser
# DenyGroups badgroup
EOF

# Test configuration
sudo sshd -t

# If test passes, reload SSH
sudo systemctl reload sshd

# Verify service is running
sudo systemctl status sshd
```

### Exercise 3: SSH Access Control

```bash
# Create SSH users group
sudo groupadd sshusers

# Add user to SSH group
sudo usermod -aG sshusers ubuntu

# Configure group-based access
echo "AllowGroups sshusers" | sudo tee -a /etc/ssh/sshd_config.d/hardening.conf

# Configure per-user settings
sudo tee -a /etc/ssh/sshd_config.d/users.conf << 'EOF'
# User-specific configuration
Match User developer
    PasswordAuthentication no
    AllowTcpForwarding yes
    X11Forwarding no

Match Group sftp-only
    ChrootDirectory /var/sftp/%u
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF

# Test and reload
sudo sshd -t && sudo systemctl reload sshd
```

### Exercise 4: SSH Client Configuration

```bash
# Create SSH client config
mkdir -p ~/.ssh
cat > ~/.ssh/config << 'EOF'
# Global defaults
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes
    IdentitiesOnly yes
    HashKnownHosts yes

# Production server
Host prod
    HostName 10.0.1.100
    User ubuntu
    IdentityFile ~/.ssh/devops_ed25519
    Port 22

# Development server
Host dev
    HostName 10.0.2.100
    User ubuntu
    IdentityFile ~/.ssh/devops_ed25519

# Bastion/Jump host
Host bastion
    HostName bastion.example.com
    User ubuntu
    IdentityFile ~/.ssh/bastion_key
    ForwardAgent no

# Access internal server via bastion
Host internal
    HostName 10.0.1.50
    User ubuntu
    IdentityFile ~/.ssh/internal_key
    ProxyJump bastion

# Multiple hop example
Host deep-internal
    HostName 192.168.1.100
    User admin
    ProxyJump bastion,internal
EOF

chmod 600 ~/.ssh/config

# Now you can connect with:
# ssh prod
# ssh dev
# ssh internal (via bastion)
```

### Exercise 5: SSH Agent

```bash
# Start SSH agent
eval "$(ssh-agent -s)"

# Add key to agent
ssh-add ~/.ssh/devops_ed25519

# List keys in agent
ssh-add -l

# Remove specific key
ssh-add -d ~/.ssh/devops_ed25519

# Remove all keys
ssh-add -D

# Add key with timeout (expires after 1 hour)
ssh-add -t 3600 ~/.ssh/devops_ed25519

# Lock agent (requires password to unlock)
ssh-add -x

# Unlock agent
ssh-add -X

# Configure agent forwarding (use with caution)
# In ~/.ssh/config:
# Host trusted-server
#     ForwardAgent yes
```

### Exercise 6: SSH Tunneling

```bash
# Local port forwarding
# Access remote service on local port
# ssh -L local_port:remote_host:remote_port user@ssh_server

# Example: Access remote MySQL on local port 3307
ssh -L 3307:localhost:3306 ubuntu@database-server
# Now connect to localhost:3307 to reach database-server:3306

# Remote port forwarding
# Expose local service on remote server
# ssh -R remote_port:local_host:local_port user@ssh_server

# Example: Expose local web server to remote
ssh -R 8080:localhost:80 ubuntu@remote-server
# Now remote-server:8080 reaches your local port 80

# Dynamic port forwarding (SOCKS proxy)
ssh -D 1080 ubuntu@proxy-server
# Configure browser to use SOCKS5 proxy localhost:1080

# Persistent tunnel with autossh
sudo apt install autossh -y

# Create persistent tunnel
autossh -M 0 -f -N -L 3307:localhost:3306 ubuntu@database-server \
    -o "ServerAliveInterval 30" \
    -o "ServerAliveCountMax 3"

# Create tunnel as systemd service
sudo tee /etc/systemd/system/ssh-tunnel.service << 'EOF'
[Unit]
Description=SSH Tunnel to Database
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/usr/bin/ssh -N -L 3307:localhost:3306 -i /home/ubuntu/.ssh/tunnel_key ubuntu@database-server -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

### Exercise 7: Bastion Host Setup

```bash
# On Bastion Host - create restricted configuration
sudo tee /etc/ssh/sshd_config.d/bastion.conf << 'EOF'
# Bastion Host Configuration

# Only key authentication
PasswordAuthentication no
PubkeyAuthentication yes

# Allow TCP forwarding for jump connections
AllowTcpForwarding yes
GatewayPorts no

# Disable unnecessary features
X11Forwarding no
AllowAgentForwarding no

# Short session timeout
ClientAliveInterval 120
ClientAliveCountMax 2

# Detailed logging
LogLevel VERBOSE

# Restrict users
AllowGroups bastion-users
EOF

# Create bastion users group
sudo groupadd bastion-users
sudo usermod -aG bastion-users ubuntu

# Apply and reload
sudo sshd -t && sudo systemctl reload sshd

# On Client - configure jump host
cat >> ~/.ssh/config << 'EOF'

# Bastion jump configuration
Host bastion-jump
    HostName BASTION_PUBLIC_IP
    User ubuntu
    IdentityFile ~/.ssh/bastion_key
    ForwardAgent no
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600

Host private-*
    ProxyJump bastion-jump
    User ubuntu
    IdentityFile ~/.ssh/private_key

Host private-web
    HostName 10.0.1.10

Host private-db
    HostName 10.0.1.20

Host private-app
    HostName 10.0.1.30
EOF

# Create socket directory
mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh/sockets
```

### Exercise 8: SSH Audit and Monitoring

```bash
# Create SSH audit script
cat > ~/scripts/ssh_audit.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "=== SSH Security Audit ==="
echo "Date: $(date)"
echo ""

# Check SSH version
echo "--- SSH Version ---"
ssh -V 2>&1

# Check server configuration
echo ""
echo "--- Critical Settings ---"
for setting in PermitRootLogin PasswordAuthentication PubkeyAuthentication; do
    value=$(sudo sshd -T 2>/dev/null | grep -i "^$setting " || echo "Not found")
    echo "$setting: $value"
done

# Check for weak keys
echo ""
echo "--- SSH Host Keys ---"
for key in /etc/ssh/ssh_host_*_key.pub; do
    if [[ -f "$key" ]]; then
        echo "$(ssh-keygen -lf "$key")"
    fi
done

# Check authorized_keys permissions
echo ""
echo "--- Authorized Keys Check ---"
for home in /home/*; do
    if [[ -d "$home/.ssh" ]]; then
        user=$(basename "$home")
        auth_keys="$home/.ssh/authorized_keys"
        if [[ -f "$auth_keys" ]]; then
            perms=$(stat -c %a "$auth_keys")
            key_count=$(wc -l < "$auth_keys")
            echo "User $user: $key_count keys, permissions: $perms"
            if [[ "$perms" != "600" ]]; then
                echo "  WARNING: Should be 600!"
            fi
        fi
    fi
done

# Check recent SSH logins
echo ""
echo "--- Recent SSH Logins (last 10) ---"
last -a | grep -E "pts/|ssh" | head -10 || echo "No SSH logins found"

# Check failed login attempts
echo ""
echo "--- Failed SSH Attempts (last 10) ---"
sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10 || echo "No failures found"

# Check for suspicious activity
echo ""
echo "--- Potentially Suspicious Activity ---"
sudo grep -E "Invalid user|Failed password|Connection closed by" /var/log/auth.log 2>/dev/null | \
    awk '{print $1, $2, $3, $9, $11}' | sort | uniq -c | sort -rn | head -10 || echo "None found"

echo ""
echo "=== Audit Complete ==="
EOF

chmod +x ~/scripts/ssh_audit.sh
~/scripts/ssh_audit.sh
```

---

## Tier 2: Semi-Guided Exercises

### Exercise A: Certificate-Based Authentication

Set up SSH certificate authentication:

1. Create SSH CA key pair
2. Sign user public keys with CA
3. Configure server to trust CA
4. Test certificate-based login
5. Implement certificate revocation

### Exercise B: Two-Factor Authentication

Configure 2FA for SSH:

1. Install Google Authenticator PAM module
2. Configure PAM for SSH
3. Set up TOTP on mobile device
4. Test 2FA login
5. Configure backup codes

### Exercise C: SSH Honeypot

Deploy an SSH honeypot for security monitoring:

1. Set up Cowrie or similar honeypot
2. Configure logging and alerts
3. Analyze attack patterns
4. Generate security report
5. Integrate with SIEM

---

## Tier 3: Challenge

Build a complete SSH infrastructure with:

1. **Central SSH CA**
   - Generate and secure CA keys
   - Automate certificate signing
   - Implement expiration policies
   - Certificate revocation system

2. **Bastion Architecture**
   - High-availability bastion pair
   - Session recording
   - Access control by time/user/target
   - Audit trail

3. **Automated Key Rotation**
   - Rotate SSH keys periodically
   - Deploy new keys automatically
   - Revoke old keys
   - Alert on rotation failures

4. **Security Monitoring**
   - Real-time login alerts
   - Failed attempt tracking
   - Anomaly detection
   - Compliance reporting

---

## Validation Script

```bash
#!/bin/bash

echo "=== SSH Hardening Lab Validation ==="

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

# Check SSH service
check "systemctl is-active sshd" "SSH service is running"

# Check key authentication configured
check "sudo sshd -T | grep -qi 'pubkeyauthentication yes'" "Public key authentication enabled"

# Check password authentication disabled
check "sudo sshd -T | grep -qi 'passwordauthentication no'" "Password authentication disabled"

# Check root login disabled
check "sudo sshd -T | grep -qi 'permitrootlogin no'" "Root login disabled"

# Check SSH client config exists
check "[ -f ~/.ssh/config ]" "SSH client config exists"

# Check authorized_keys permissions
check "[ $(stat -c %a ~/.ssh/authorized_keys 2>/dev/null) = '600' ]" "authorized_keys has correct permissions"

# Check audit script exists
check "[ -f ~/scripts/ssh_audit.sh ]" "SSH audit script exists"

echo ""
echo "Validation complete!"
```

---

## Cleanup

```bash
# Restore original SSH config (if needed)
# sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
# sudo rm /etc/ssh/sshd_config.d/hardening.conf
# sudo systemctl reload sshd

# WARNING: Be careful not to lock yourself out!
# Always test config before applying
# Always have console access as backup
```

---

## Key Takeaways

1. **Keys over passwords** - Always use key-based authentication
2. **Disable root login** - Use sudo instead
3. **Harden defaults** - Disable unused features
4. **Use bastion hosts** - For accessing private networks
5. **Audit regularly** - Monitor for unauthorized access
6. **Test before applying** - Use sshd -t to validate config

---

## Next Lab

[Lab 09: Firewall Configuration](../lab-09-firewall/)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- SSH Key Management
- SSH Server Configuration
- SSH Access Control
- SSH Client Configuration

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
