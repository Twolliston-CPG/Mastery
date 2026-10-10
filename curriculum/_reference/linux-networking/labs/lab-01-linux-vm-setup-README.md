# Lab 01: Linux VM Setup on AWS and GCP

## Overview

This lab walks you through launching Linux virtual machines on both AWS and GCP. You'll learn to create, connect to, and manage cloud-based Linux servers—a fundamental skill for any DevOps engineer.

## Objectives

- Launch an EC2 instance on AWS
- Launch a Compute Engine instance on GCP
- Connect via SSH to both instances
- Understand instance types and pricing
- Practice instance lifecycle management

## Prerequisites

- AWS account with billing configured (Phase 0)
- GCP account with billing configured (Phase 0)
- SSH key pair generated
- AWS CLI and gcloud CLI configured

## Cost Warning

This lab uses cloud resources that may incur charges:
- AWS: t2.micro is free tier eligible (750 hours/month for 12 months)
- GCP: e2-micro is always free (1 instance per month, specific regions)

**Always terminate instances when not in use!**

---

## Tier 1: Guided Instructions

### Part A: Launch EC2 Instance on AWS

#### Step 1: Choose AMI and Instance Type

```bash
# List available Ubuntu AMIs in your region
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].[ImageId, Name]' \
  --output table

# Note the AMI ID (format: ami-xxxxxxxxxxxxxxxxx)
```

#### Step 2: Create Security Group

```bash
# Create security group
aws ec2 create-security-group \
  --group-name devops-lab-sg \
  --description "Security group for DevOps labs"

# Note the GroupId from output

# Allow SSH from your IP
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-name devops-lab-sg \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_IP}/32

# Verify
aws ec2 describe-security-groups \
  --group-names devops-lab-sg
```

#### Step 3: Create Key Pair (if not exists)

```bash
# Create key pair
aws ec2 create-key-pair \
  --key-name devops-lab-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/devops-lab-key.pem

# Set permissions
chmod 400 ~/.ssh/devops-lab-key.pem
```

#### Step 4: Launch Instance

```bash
# Set variables (replace AMI_ID with actual ID)
AMI_ID="ami-0c55b159cbfafe1f0"  # Ubuntu 22.04 (update for your region)

# Launch instance
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --key-name devops-lab-key \
  --security-groups devops-lab-sg \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=devops-lab-ec2}]' \
  --query 'Instances[0].InstanceId' \
  --output text

# Note the Instance ID
```

#### Step 5: Wait for Instance and Get Public IP

```bash
# Wait for running state
aws ec2 wait instance-running \
  --instance-ids i-xxxxxxxxxxxxxxxxx

# Get public IP
aws ec2 describe-instances \
  --instance-ids i-xxxxxxxxxxxxxxxxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

#### Step 6: Connect via SSH

```bash
# Connect to instance
ssh -i ~/.ssh/devops-lab-key.pem ubuntu@<PUBLIC_IP>

# Once connected, verify
uname -a
cat /etc/os-release
```

#### Step 7: Explore the Instance

```bash
# System information
hostnamectl
uptime
free -h
df -h

# Network information
ip addr
curl ifconfig.me  # Public IP

# Check cloud metadata (AWS specific)
curl http://169.254.169.254/latest/meta-data/
curl http://169.254.169.254/latest/meta-data/instance-id
curl http://169.254.169.254/latest/meta-data/instance-type
```

---

### Part B: Launch Compute Engine Instance on GCP

#### Step 1: Set Project and Zone

```bash
# Set default project
gcloud config set project YOUR_PROJECT_ID

# Set default zone
gcloud config set compute/zone us-central1-a

# Verify
gcloud config list
```

#### Step 2: Create Firewall Rule for SSH

```bash
# Create firewall rule (if not exists)
gcloud compute firewall-rules create allow-ssh \
  --allow tcp:22 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow SSH from anywhere"
```

#### Step 3: Launch Instance

```bash
# Create instance
gcloud compute instances create devops-lab-gce \
  --machine-type e2-micro \
  --image-family ubuntu-2204-lts \
  --image-project ubuntu-os-cloud \
  --boot-disk-size 20GB \
  --tags devops-lab

# View instance details
gcloud compute instances describe devops-lab-gce
```

#### Step 4: Connect via SSH

```bash
# GCP handles SSH keys automatically
gcloud compute ssh devops-lab-gce

# Once connected, verify
uname -a
cat /etc/os-release
```

#### Step 5: Explore GCP Metadata

```bash
# GCP metadata service
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/

# Get specific metadata
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/name
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/machine-type
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/zone
```

---

### Part C: Instance Management

#### Stop and Start Instances

```bash
# AWS
aws ec2 stop-instances --instance-ids i-xxxxxxxxxxxxxxxxx
aws ec2 start-instances --instance-ids i-xxxxxxxxxxxxxxxxx

# GCP
gcloud compute instances stop devops-lab-gce
gcloud compute instances start devops-lab-gce
```

#### Terminate/Delete Instances

```bash
# AWS - Terminate (permanent deletion)
aws ec2 terminate-instances --instance-ids i-xxxxxxxxxxxxxxxxx

# GCP - Delete
gcloud compute instances delete devops-lab-gce
```

#### List All Instances

```bash
# AWS
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# GCP
gcloud compute instances list
```

---

## Tier 2: Semi-Guided

Complete the following without step-by-step instructions:

### Exercise A: Custom Instance on AWS

1. Launch a t3.small instance with Amazon Linux 2
2. Add a 30GB EBS volume
3. Configure security group to allow SSH and HTTP
4. Connect and install Nginx
5. Access Nginx from browser
6. Terminate when done

### Exercise B: Custom Instance on GCP

1. Launch an e2-small instance with Debian 11
2. Add a 25GB persistent disk
3. Configure firewall for SSH and HTTPS
4. Connect and install Apache
5. Access Apache from browser
6. Delete when done

### Exercise C: Multi-Instance Setup

1. Launch 2 instances (one on each cloud)
2. Configure SSH access between them
3. Verify connectivity
4. Clean up both instances

---

## Tier 3: Challenge

Complete all tasks in 60 minutes:

### Challenge Tasks

1. **AWS Instance**
   - Launch Ubuntu 22.04 on t2.micro
   - Create custom security group allowing only your IP
   - Install and configure:
     - Docker
     - Git
     - Node.js
   - Create AMI from the instance
   - Terminate instance

2. **GCP Instance**
   - Launch Ubuntu 22.04 on e2-micro
   - Create custom firewall rules
   - Install same software as AWS
   - Create machine image
   - Delete instance

3. **Automation Script**
   - Write a script that:
     - Launches instance on chosen cloud
     - Waits for it to be ready
     - Installs specified packages
     - Outputs connection information

### Success Criteria

- [ ] Both instances launched successfully
- [ ] Can SSH to both instances
- [ ] Software installed correctly
- [ ] Images/AMIs created
- [ ] Instances terminated (no ongoing charges)
- [ ] Automation script works

---

## Validation Script

```bash
#!/bin/bash

echo "=== Linux VM Setup Lab Validation ==="

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Check AWS CLI
if aws sts get-caller-identity &>/dev/null; then
    echo -e "${GREEN}✓${NC} AWS CLI configured"
else
    echo -e "${RED}✗${NC} AWS CLI not configured"
fi

# Check GCP CLI
if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1; then
    echo -e "${GREEN}✓${NC} GCP CLI configured"
else
    echo -e "${RED}✗${NC} GCP CLI not configured"
fi

# Check SSH key
if [ -f ~/.ssh/devops-lab-key.pem ]; then
    echo -e "${GREEN}✓${NC} AWS SSH key exists"
else
    echo -e "${RED}✗${NC} AWS SSH key missing"
fi

# List running instances (info only)
echo ""
echo "--- AWS Instances ---"
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,PublicIpAddress]' \
  --output table 2>/dev/null || echo "No AWS instances or error"

echo ""
echo "--- GCP Instances ---"
gcloud compute instances list 2>/dev/null || echo "No GCP instances or error"
```

---

## Cost Cleanup Checklist

**Before ending the lab, verify:**

- [ ] AWS EC2 instance terminated (not just stopped)
- [ ] AWS EBS volumes deleted (if any)
- [ ] AWS security group can be kept (no cost)
- [ ] GCP instance deleted
- [ ] GCP disks deleted
- [ ] No other resources running

```bash
# AWS Cleanup
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text

# Terminate all (careful!)
# aws ec2 terminate-instances --instance-ids <ids>

# GCP Cleanup
gcloud compute instances list
# gcloud compute instances delete <name> --quiet
```

---

## Troubleshooting

### "Permission denied (publickey)"

```bash
# Check key permissions
ls -la ~/.ssh/devops-lab-key.pem
# Should be: -r-------- (400)

# Fix permissions
chmod 400 ~/.ssh/devops-lab-key.pem

# Check correct username
# AWS Ubuntu: ubuntu
# AWS Amazon Linux: ec2-user
# GCP: your Google username
```

### "Connection timed out"

```bash
# Check security group allows SSH
aws ec2 describe-security-groups --group-names devops-lab-sg

# Check instance is running
aws ec2 describe-instance-status --instance-ids i-xxx

# Check public IP exists
aws ec2 describe-instances --instance-ids i-xxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress'
```

### "Insufficient capacity"

```bash
# Try different availability zone
aws ec2 run-instances ... --placement AvailabilityZone=us-east-1b

# Or different instance type
aws ec2 run-instances ... --instance-type t3.micro
```

---

## Key Takeaways

1. **Instance types matter** - Choose based on workload, not just cost
2. **Security groups are stateful** - Return traffic is automatically allowed
3. **Metadata service** - Useful for instance self-discovery
4. **Always clean up** - Unused resources cost money
5. **SSH key management** - Critical for secure access

---

## Next Lab

[Lab 02: Filesystem Navigation](../lab-02-filesystem/)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Cost Warning
- Cost Cleanup Checklist
- Challenge Tasks
- "Permission denied (publickey)"

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
