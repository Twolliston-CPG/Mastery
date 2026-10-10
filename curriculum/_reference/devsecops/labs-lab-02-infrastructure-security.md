# Lab 2: Infrastructure Security and Hardening

## Objectives

- Implement CIS benchmark hardening for Linux systems
- Configure secure AWS infrastructure using Terraform
- Scan infrastructure for security misconfigurations
- Automate security compliance checks

## Prerequisites

- Linux administration experience
- Terraform installed (v1.5+)
- AWS CLI configured with credentials
- Docker installed

## Duration

3 hours

## Lab Environment Setup

```bash
# Create lab directory
mkdir -p ~/security-lab/infrastructure
cd ~/security-lab/infrastructure

# Clone lab resources
git clone https://github.com/lab-resources/infrastructure-security-lab.git .
```

## Part 1: Linux System Hardening (60 minutes)

### Task 1.1: Create CIS Hardening Script

Create an automated hardening script based on CIS benchmarks:

```bash
#!/bin/bash
# cis-hardening.sh - CIS Benchmark hardening for Ubuntu 22.04

set -e

echo "=== CIS Benchmark Hardening Script ==="

# 1. Filesystem Configuration
echo "[1/10] Configuring filesystem..."

# Disable unused filesystems
cat > /etc/modprobe.d/CIS.conf << EOF
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install vfat /bin/true
install usb-storage /bin/true
EOF

# Ensure /tmp is configured
if ! grep -q "/tmp" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,rw,nosuid,nodev,noexec,relatime 0 0" >> /etc/fstab
fi

# 2. Configure bootloader
echo "[2/10] Securing bootloader..."
chown root:root /boot/grub/grub.cfg
chmod og-rwx /boot/grub/grub.cfg

# 3. Process hardening
echo "[3/10] Configuring process hardening..."
cat > /etc/security/limits.d/CIS.conf << EOF
* hard core 0
EOF

cat >> /etc/sysctl.d/CIS.conf << EOF
# Disable core dumps
fs.suid_dumpable = 0

# Enable ASLR
kernel.randomize_va_space = 2

# Restrict access to kernel pointers
kernel.kptr_restrict = 1

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Restrict ptrace
kernel.yama.ptrace_scope = 1
EOF

# 4. Network hardening
echo "[4/10] Configuring network hardening..."
cat >> /etc/sysctl.d/CIS.conf << EOF
# Network security
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
EOF

sysctl --system

# 5. Configure SSH
echo "[5/10] Hardening SSH..."
cat > /etc/ssh/sshd_config.d/CIS.conf << EOF
Protocol 2
LogLevel VERBOSE
X11Forwarding no
MaxAuthTries 4
IgnoreRhosts yes
HostbasedAuthentication no
PermitRootLogin no
PermitEmptyPasswords no
PermitUserEnvironment no
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
ClientAliveInterval 300
ClientAliveCountMax 3
LoginGraceTime 60
Banner /etc/issue.net
AllowTcpForwarding no
MaxStartups 10:30:60
MaxSessions 4
EOF

# Create login banner
cat > /etc/issue.net << EOF
***************************************************************************
                            AUTHORIZED ACCESS ONLY
This system is for authorized users only. All activities may be monitored
and recorded. Unauthorized access or use is prohibited and may result in
criminal prosecution.
***************************************************************************
EOF

systemctl reload sshd

# 6. Configure PAM
echo "[6/10] Configuring PAM..."
apt-get install -y libpam-pwquality

cat > /etc/security/pwquality.conf << EOF
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
EOF

# 7. Configure audit
echo "[7/10] Configuring auditd..."
apt-get install -y auditd audispd-plugins

cat > /etc/audit/rules.d/CIS.rules << EOF
# Delete all rules
-D

# Buffer Size
-b 8192

# Failure Mode
-f 1

# Monitor time changes
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# Monitor user/group changes
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# Monitor network configuration
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/network -p wa -k system-locale

# Monitor login/logout events
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins

# Monitor session events
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k logins
-w /var/log/btmp -p wa -k logins

# Monitor privileged commands
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/su -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged

# Monitor file deletions
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete

# Make config immutable
-e 2
EOF

augenrules --load
systemctl enable auditd
systemctl start auditd

# 8. Remove unnecessary packages
echo "[8/10] Removing unnecessary packages..."
apt-get purge -y telnet rsh-client

# 9. Set file permissions
echo "[9/10] Setting secure file permissions..."
chmod 644 /etc/passwd
chmod 600 /etc/shadow
chmod 644 /etc/group
chmod 600 /etc/gshadow
chmod 600 /etc/ssh/sshd_config
chown root:root /etc/passwd /etc/shadow /etc/group /etc/gshadow

# 10. Enable firewall
echo "[10/10] Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw --force enable

echo "=== Hardening Complete ==="
echo "Please reboot the system to apply all changes."
```

### Task 1.2: Verify Hardening with Lynis

Run security audit with Lynis:

```bash
# Install Lynis
apt-get install -y lynis

# Run security audit
lynis audit system --quick

# Generate detailed report
lynis audit system > /var/log/lynis-audit.log

# View suggestions
grep "Suggestion" /var/log/lynis-report.dat
```

### Task 1.3: Create Ansible Hardening Playbook

```yaml
# ansible/hardening.yml
---
- name: CIS Benchmark Hardening
  hosts: all
  become: yes
  vars:
    ssh_allowed_users: ['deployer', 'admin']

  tasks:
    - name: Ensure permissions on /etc/passwd
      file:
        path: /etc/passwd
        owner: root
        group: root
        mode: '0644'

    - name: Ensure permissions on /etc/shadow
      file:
        path: /etc/shadow
        owner: root
        group: shadow
        mode: '0640'

    - name: Configure SSH daemon
      template:
        src: templates/sshd_config.j2
        dest: /etc/ssh/sshd_config
        owner: root
        group: root
        mode: '0600'
        validate: '/usr/sbin/sshd -t -f %s'
      notify: restart sshd

    - name: Set kernel parameters
      sysctl:
        name: "{{ item.name }}"
        value: "{{ item.value }}"
        state: present
        reload: yes
      loop:
        - { name: 'net.ipv4.ip_forward', value: '0' }
        - { name: 'net.ipv4.conf.all.accept_redirects', value: '0' }
        - { name: 'net.ipv4.conf.all.send_redirects', value: '0' }
        - { name: 'net.ipv4.conf.all.log_martians', value: '1' }
        - { name: 'kernel.randomize_va_space', value: '2' }

    - name: Install and configure auditd
      apt:
        name:
          - auditd
          - audispd-plugins
        state: present

    - name: Configure audit rules
      template:
        src: templates/audit.rules.j2
        dest: /etc/audit/rules.d/hardening.rules
      notify: reload auditd

  handlers:
    - name: restart sshd
      service:
        name: sshd
        state: restarted

    - name: reload auditd
      command: augenrules --load
```

## Part 2: AWS Infrastructure Security (60 minutes)

### Task 2.1: Secure VPC Configuration

```hcl
# terraform/main.tf

provider "aws" {
  region = "us-east-1"
}

# Secure VPC
resource "aws_vpc" "secure" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "secure-vpc"
    Environment = "production"
  }
}

# Public Subnets (for ALB only)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.secure.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "public-subnet-${count.index}"
    Tier = "public"
  }
}

# Private Subnets (for applications)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.secure.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index}"
    Tier = "private"
  }
}

# Database Subnets (isolated)
resource "aws_subnet" "database" {
  count             = 2
  vpc_id            = aws_vpc.secure.id
  cidr_block        = "10.0.${count.index + 20}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "database-subnet-${count.index}"
    Tier = "database"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.secure.id

  tags = {
    Name = "main-igw"
  }
}

# NAT Gateway (for private subnet internet access)
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "main-nat"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.secure.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.secure.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private-rt"
  }
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.secure.id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 90
}

resource "aws_iam_role" "flow_logs" {
  name = "vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}
```

### Task 2.2: Security Groups

```hcl
# terraform/security-groups.tf

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.secure.id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP redirect"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# Application Security Group
resource "aws_security_group" "app" {
  name        = "app-sg"
  description = "Security group for application instances"
  vpc_id      = aws_vpc.secure.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

# Database Security Group
resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "Security group for database"
  vpc_id      = aws_vpc.secure.id

  ingress {
    description     = "PostgreSQL from app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-sg"
  }
}

# Bastion Security Group
resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.secure.id

  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}
```

### Task 2.3: IAM Policies (Least Privilege)

```hcl
# terraform/iam.tf

# EC2 Instance Role
resource "aws_iam_role" "ec2_app" {
  name = "ec2-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Minimal permissions policy
resource "aws_iam_role_policy" "ec2_app" {
  name = "ec2-app-policy"
  role = aws_iam_role.ec2_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_data.arn,
          "${aws_s3_bucket.app_data.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:app/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.app.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_app" {
  name = "ec2-app-profile"
  role = aws_iam_role.ec2_app.name
}
```

## Part 3: Infrastructure Security Scanning (45 minutes)

### Task 3.1: Scan with Checkov

```bash
# Install Checkov
pip install checkov

# Scan Terraform configuration
checkov -d terraform/ --output-file checkov-results.json --output json

# Scan with specific frameworks
checkov -d terraform/ --framework terraform --check CKV_AWS_*

# View high severity findings
checkov -d terraform/ --check HIGH
```

### Task 3.2: Scan with tfsec

```bash
# Install tfsec
brew install tfsec  # macOS
# or
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Run tfsec
tfsec terraform/ --format json > tfsec-results.json

# Run with minimum severity
tfsec terraform/ --minimum-severity HIGH

# Generate SARIF output
tfsec terraform/ --format sarif > tfsec.sarif
```

### Task 3.3: AWS Security Hub

```hcl
# terraform/security-hub.tf

resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "cis" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/1.4.0"
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
}
```

## Verification

Complete the following checklist:

- [ ] Successfully ran CIS hardening script
- [ ] Verified hardening with Lynis (score > 70)
- [ ] Created secure VPC with proper segmentation
- [ ] Configured security groups following least privilege
- [ ] Created IAM policies with minimal permissions
- [ ] Ran Checkov and resolved critical findings
- [ ] Ran tfsec and resolved high severity issues
- [ ] Enabled VPC Flow Logs

## Challenge Tasks

1. **Implement AWS Config Rules**: Create custom Config rules to detect security misconfigurations

2. **GuardDuty Integration**: Enable GuardDuty and create SNS notifications for findings

3. **Automated Remediation**: Create Lambda functions to auto-remediate common findings

## Summary

In this lab, you:
- Implemented CIS benchmark hardening for Linux systems
- Created secure AWS infrastructure with proper network segmentation
- Applied least privilege IAM policies
- Scanned infrastructure for security misconfigurations
- Enabled security monitoring with Flow Logs and Security Hub

## Next Steps

- Lab 3: Container Security
- Review CIS AWS Foundations Benchmark
- Study AWS Well-Architected Security Pillar

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Linux System Hardening
- AWS Infrastructure Security
- Infrastructure Security Scanning
- Challenge Tasks

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
