# Lab 02 -- Build a Multi-Tier VPC from Scratch

## Lab Overview

| Item | Detail |
|---|---|
| **Objective** | Build a production-style multi-tier VPC with public and private subnets, Internet Gateway, NAT Gateway, route tables, security groups, and NACLs |
| **Estimated time** | 90-120 minutes |
| **Cost** | ~$1-3 (NAT Gateway: ~$0.045/hour. Tear down within 2 hours to minimize cost.) |
| **Prerequisites** | AWS CLI v2, Python 3.10+ with boto3, Terraform >= 1.5, completed Lab 01 |
| **Cleanup required** | YES -- NAT Gateway charges per hour. Destroy all resources immediately when done. |

---

## Architecture

```
                           Internet
                              |
                        Internet Gateway
                              |
                    +---------+---------+
                    |                   |
              Public Subnet        Public Subnet
              10.0.1.0/24         10.0.2.0/24
                (AZ-a)               (AZ-b)
                    |                   |
               NAT Gateway         (no NAT GW --
               (with EIP)          cost savings for lab)
                    |
                    |
                    +-------------------+
                    |                   |
             Private Subnet       Private Subnet
             10.0.11.0/24        10.0.12.0/24
               (AZ-a)              (AZ-b)
```

**VPC CIDR:** `10.0.0.0/16`

| Subnet | CIDR | AZ | Type | Purpose |
|---|---|---|---|---|
| public-a | 10.0.1.0/24 | us-east-1a | Public | NAT Gateway, bastion host, ALB |
| public-b | 10.0.2.0/24 | us-east-1b | Public | ALB (multi-AZ) |
| private-a | 10.0.11.0/24 | us-east-1a | Private | Application servers |
| private-b | 10.0.12.0/24 | us-east-1b | Private | Application servers |

---

## Part 1: Build with AWS CLI

### Step 1.1 -- Create the VPC

```bash
# Create the VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --query 'Vpc.VpcId' \
  --output text \
  --profile saa-study)

echo "VPC ID: $VPC_ID"

# Enable DNS hostnames (required for private hosted zones and some services)
aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames '{"Value": true}' \
  --profile saa-study

# Tag the VPC
aws ec2 create-tags \
  --resources "$VPC_ID" \
  --tags Key=Name,Value=saa-lab02-vpc Key=Project,Value=saa-study \
  --profile saa-study
```

### Step 1.2 -- Create Subnets

```bash
# Public subnet in AZ-a
PUB_SUBNET_A=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --query 'Subnet.SubnetId' \
  --output text \
  --profile saa-study)

# Enable auto-assign public IP for public subnet
aws ec2 modify-subnet-attribute \
  --subnet-id "$PUB_SUBNET_A" \
  --map-public-ip-on-launch \
  --profile saa-study

aws ec2 create-tags \
  --resources "$PUB_SUBNET_A" \
  --tags Key=Name,Value=saa-lab02-public-a \
  --profile saa-study

# Public subnet in AZ-b
PUB_SUBNET_B=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1b \
  --query 'Subnet.SubnetId' \
  --output text \
  --profile saa-study)

aws ec2 modify-subnet-attribute \
  --subnet-id "$PUB_SUBNET_B" \
  --map-public-ip-on-launch \
  --profile saa-study

aws ec2 create-tags \
  --resources "$PUB_SUBNET_B" \
  --tags Key=Name,Value=saa-lab02-public-b \
  --profile saa-study

# Private subnet in AZ-a
PRIV_SUBNET_A=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.11.0/24 \
  --availability-zone us-east-1a \
  --query 'Subnet.SubnetId' \
  --output text \
  --profile saa-study)

aws ec2 create-tags \
  --resources "$PRIV_SUBNET_A" \
  --tags Key=Name,Value=saa-lab02-private-a \
  --profile saa-study

# Private subnet in AZ-b
PRIV_SUBNET_B=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.12.0/24 \
  --availability-zone us-east-1b \
  --query 'Subnet.SubnetId' \
  --output text \
  --profile saa-study)

aws ec2 create-tags \
  --resources "$PRIV_SUBNET_B" \
  --tags Key=Name,Value=saa-lab02-private-b \
  --profile saa-study

echo "Subnets: $PUB_SUBNET_A, $PUB_SUBNET_B, $PRIV_SUBNET_A, $PRIV_SUBNET_B"
```

### Step 1.3 -- Create and Attach Internet Gateway

```bash
# Create the Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text \
  --profile saa-study)

# Attach to VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID" \
  --profile saa-study

aws ec2 create-tags \
  --resources "$IGW_ID" \
  --tags Key=Name,Value=saa-lab02-igw \
  --profile saa-study

echo "IGW ID: $IGW_ID"
```

### Step 1.4 -- Create NAT Gateway

```bash
# Allocate an Elastic IP for the NAT Gateway
EIP_ALLOC=$(aws ec2 allocate-address \
  --domain vpc \
  --query 'AllocationId' \
  --output text \
  --profile saa-study)

# Create NAT Gateway in the public subnet (AZ-a)
NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id "$PUB_SUBNET_A" \
  --allocation-id "$EIP_ALLOC" \
  --query 'NatGateway.NatGatewayId' \
  --output text \
  --profile saa-study)

aws ec2 create-tags \
  --resources "$NAT_GW_ID" \
  --tags Key=Name,Value=saa-lab02-nat-gw \
  --profile saa-study

echo "NAT GW ID: $NAT_GW_ID"
echo "*** NAT Gateway costs ~$0.045/hour. Remember to tear down! ***"

# Wait for NAT Gateway to become available (takes 1-2 minutes)
aws ec2 wait nat-gateway-available \
  --nat-gateway-ids "$NAT_GW_ID" \
  --profile saa-study

echo "NAT Gateway is now available."
```

### Step 1.5 -- Create Route Tables

```bash
# --- Public Route Table ---
PUB_RT=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' \
  --output text \
  --profile saa-study)

# Add route to Internet Gateway
aws ec2 create-route \
  --route-table-id "$PUB_RT" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID" \
  --profile saa-study

# Associate with public subnets
aws ec2 associate-route-table \
  --route-table-id "$PUB_RT" \
  --subnet-id "$PUB_SUBNET_A" \
  --profile saa-study

aws ec2 associate-route-table \
  --route-table-id "$PUB_RT" \
  --subnet-id "$PUB_SUBNET_B" \
  --profile saa-study

aws ec2 create-tags \
  --resources "$PUB_RT" \
  --tags Key=Name,Value=saa-lab02-public-rt \
  --profile saa-study

# --- Private Route Table ---
PRIV_RT=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' \
  --output text \
  --profile saa-study)

# Add route to NAT Gateway
aws ec2 create-route \
  --route-table-id "$PRIV_RT" \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id "$NAT_GW_ID" \
  --profile saa-study

# Associate with private subnets
aws ec2 associate-route-table \
  --route-table-id "$PRIV_RT" \
  --subnet-id "$PRIV_SUBNET_A" \
  --profile saa-study

aws ec2 associate-route-table \
  --route-table-id "$PRIV_RT" \
  --subnet-id "$PRIV_SUBNET_B" \
  --profile saa-study

aws ec2 create-tags \
  --resources "$PRIV_RT" \
  --tags Key=Name,Value=saa-lab02-private-rt \
  --profile saa-study

echo "Route tables: Public=$PUB_RT, Private=$PRIV_RT"
```

### Step 1.6 -- Create Security Groups

```bash
# --- Bastion / SSH Security Group ---
BASTION_SG=$(aws ec2 create-security-group \
  --group-name saa-lab02-bastion-sg \
  --description "Allow SSH from my IP" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text \
  --profile saa-study)

# Get your public IP (replace if this doesn't work for you)
MY_IP=$(curl -s https://checkip.amazonaws.com)/32

aws ec2 authorize-security-group-ingress \
  --group-id "$BASTION_SG" \
  --protocol tcp \
  --port 22 \
  --cidr "$MY_IP" \
  --profile saa-study

# --- Application Security Group ---
APP_SG=$(aws ec2 create-security-group \
  --group-name saa-lab02-app-sg \
  --description "Allow HTTP from ALB and SSH from bastion" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text \
  --profile saa-study)

# Allow SSH from bastion SG
aws ec2 authorize-security-group-ingress \
  --group-id "$APP_SG" \
  --protocol tcp \
  --port 22 \
  --source-group "$BASTION_SG" \
  --profile saa-study

# Allow HTTP from within VPC (ALB will be in VPC)
aws ec2 authorize-security-group-ingress \
  --group-id "$APP_SG" \
  --protocol tcp \
  --port 80 \
  --cidr 10.0.0.0/16 \
  --profile saa-study

echo "Security Groups: Bastion=$BASTION_SG, App=$APP_SG"
```

### Step 1.7 -- Create a Network ACL for Private Subnets

```bash
# Create custom NACL for private subnets
PRIV_NACL=$(aws ec2 create-network-acl \
  --vpc-id "$VPC_ID" \
  --query 'NetworkAcl.NetworkAclId' \
  --output text \
  --profile saa-study)

# Inbound: Allow HTTP from VPC
aws ec2 create-network-acl-entry \
  --network-acl-id "$PRIV_NACL" \
  --rule-number 100 \
  --protocol tcp \
  --port-range From=80,To=80 \
  --cidr-block 10.0.0.0/16 \
  --rule-action allow \
  --ingress \
  --profile saa-study

# Inbound: Allow SSH from VPC (bastion access)
aws ec2 create-network-acl-entry \
  --network-acl-id "$PRIV_NACL" \
  --rule-number 110 \
  --protocol tcp \
  --port-range From=22,To=22 \
  --cidr-block 10.0.0.0/16 \
  --rule-action allow \
  --ingress \
  --profile saa-study

# Inbound: Allow ephemeral ports (return traffic from internet via NAT GW)
aws ec2 create-network-acl-entry \
  --network-acl-id "$PRIV_NACL" \
  --rule-number 120 \
  --protocol tcp \
  --port-range From=1024,To=65535 \
  --cidr-block 0.0.0.0/0 \
  --rule-action allow \
  --ingress \
  --profile saa-study

# Outbound: Allow HTTP to internet (via NAT GW)
aws ec2 create-network-acl-entry \
  --network-acl-id "$PRIV_NACL" \
  --rule-number 100 \
  --protocol tcp \
  --port-range From=80,To=80 \
  --cidr-block 0.0.0.0/0 \
  --rule-action allow \
  --egress \
  --profile saa-study

# Outbound: Allow HTTPS to internet
aws ec2 create-network-acl-entry \
  --network-acl-id "$PRIV_NACL" \
  --rule-number 110 \
  --protocol tcp \
  --port-range From=443,To=443 \
  --cidr-block 0.0.0.0/0 \
  --rule-action allow \
  --egress \
  --profile saa-study

# Outbound: Allow ephemeral ports to VPC (response to inbound SSH/HTTP)
aws ec2 create-network-acl-entry \
  --network-acl-id "$PRIV_NACL" \
  --rule-number 120 \
  --protocol tcp \
  --port-range From=1024,To=65535 \
  --cidr-block 10.0.0.0/16 \
  --rule-action allow \
  --egress \
  --profile saa-study

aws ec2 create-tags \
  --resources "$PRIV_NACL" \
  --tags Key=Name,Value=saa-lab02-private-nacl \
  --profile saa-study

echo "Private NACL: $PRIV_NACL"
echo "NOTE: Associate this NACL with private subnets using replace-network-acl-association"
```

---

## Part 2: Build with Boto3 (Python)

```python
"""
Lab 02 - Build a Multi-Tier VPC with Boto3
Run with: python lab02_vpc_boto3.py
"""

import boto3
import time
from botocore.exceptions import ClientError

session = boto3.Session(profile_name='saa-study', region_name='us-east-1')
ec2 = session.resource('ec2')
ec2_client = session.client('ec2')

TAGS_BASE = [{'Key': 'Project', 'Value': 'saa-study'}, {'Key': 'Lab', 'Value': 'lab02'}]


def tag(name: str) -> list:
    """Build a tag list with a Name tag."""
    return TAGS_BASE + [{'Key': 'Name', 'Value': name}]


def build_vpc():
    """Build the complete multi-tier VPC."""

    # --- VPC ---
    vpc = ec2.create_vpc(CidrBlock='10.0.0.0/16')
    vpc.wait_until_available()
    vpc.create_tags(Tags=tag('saa-lab02-vpc'))
    vpc.modify_attribute(EnableDnsHostnames={'Value': True})
    print(f"VPC: {vpc.id}")

    # --- Subnets ---
    public_a = vpc.create_subnet(CidrBlock='10.0.1.0/24', AvailabilityZone='us-east-1a')
    public_a.create_tags(Tags=tag('saa-lab02-public-a'))
    ec2_client.modify_subnet_attribute(SubnetId=public_a.id, MapPublicIpOnLaunch={'Value': True})

    public_b = vpc.create_subnet(CidrBlock='10.0.2.0/24', AvailabilityZone='us-east-1b')
    public_b.create_tags(Tags=tag('saa-lab02-public-b'))
    ec2_client.modify_subnet_attribute(SubnetId=public_b.id, MapPublicIpOnLaunch={'Value': True})

    private_a = vpc.create_subnet(CidrBlock='10.0.11.0/24', AvailabilityZone='us-east-1a')
    private_a.create_tags(Tags=tag('saa-lab02-private-a'))

    private_b = vpc.create_subnet(CidrBlock='10.0.12.0/24', AvailabilityZone='us-east-1b')
    private_b.create_tags(Tags=tag('saa-lab02-private-b'))

    print(f"Subnets: {public_a.id}, {public_b.id}, {private_a.id}, {private_b.id}")

    # --- Internet Gateway ---
    igw = ec2.create_internet_gateway()
    igw.create_tags(Tags=tag('saa-lab02-igw'))
    igw.attach_to_vpc(VpcId=vpc.id)
    print(f"IGW: {igw.id}")

    # --- Elastic IP and NAT Gateway ---
    eip = ec2_client.allocate_address(Domain='vpc')
    nat_gw = ec2_client.create_nat_gateway(
        SubnetId=public_a.id,
        AllocationId=eip['AllocationId'],
        TagSpecifications=[{
            'ResourceType': 'natgateway',
            'Tags': tag('saa-lab02-nat-gw')
        }]
    )
    nat_gw_id = nat_gw['NatGateway']['NatGatewayId']
    print(f"NAT GW: {nat_gw_id} (waiting for it to become available...)")

    # Wait for NAT GW
    waiter = ec2_client.get_waiter('nat_gateway_available')
    waiter.wait(NatGatewayIds=[nat_gw_id])
    print("NAT GW is available.")

    # --- Public Route Table ---
    public_rt = vpc.create_route_table()
    public_rt.create_tags(Tags=tag('saa-lab02-public-rt'))
    public_rt.create_route(DestinationCidrBlock='0.0.0.0/0', GatewayId=igw.id)
    public_rt.associate_with_subnet(SubnetId=public_a.id)
    public_rt.associate_with_subnet(SubnetId=public_b.id)
    print(f"Public RT: {public_rt.id}")

    # --- Private Route Table ---
    private_rt = vpc.create_route_table()
    private_rt.create_tags(Tags=tag('saa-lab02-private-rt'))
    private_rt.create_route(DestinationCidrBlock='0.0.0.0/0', NatGatewayId=nat_gw_id)
    private_rt.associate_with_subnet(SubnetId=private_a.id)
    private_rt.associate_with_subnet(SubnetId=private_b.id)
    print(f"Private RT: {private_rt.id}")

    # --- Security Groups ---
    bastion_sg = vpc.create_security_group(
        GroupName='saa-lab02-bastion-sg',
        Description='Allow SSH from anywhere (lab only -- restrict in production)'
    )
    bastion_sg.create_tags(Tags=tag('saa-lab02-bastion-sg'))
    bastion_sg.authorize_ingress(
        IpProtocol='tcp', FromPort=22, ToPort=22,
        CidrIpv4='0.0.0.0/0'  # Lab only! Restrict to your IP in production.
    )

    app_sg = vpc.create_security_group(
        GroupName='saa-lab02-app-sg',
        Description='Allow HTTP from VPC, SSH from bastion'
    )
    app_sg.create_tags(Tags=tag('saa-lab02-app-sg'))
    app_sg.authorize_ingress(
        IpPermissions=[
            {
                'IpProtocol': 'tcp', 'FromPort': 22, 'ToPort': 22,
                'UserIdGroupPairs': [{'GroupId': bastion_sg.id}]
            },
            {
                'IpProtocol': 'tcp', 'FromPort': 80, 'ToPort': 80,
                'IpRanges': [{'CidrIp': '10.0.0.0/16'}]
            }
        ]
    )

    print(f"Security Groups: Bastion={bastion_sg.id}, App={app_sg.id}")

    # --- Summary ---
    print("\n" + "=" * 60)
    print("VPC BUILD COMPLETE")
    print("=" * 60)
    print(f"  VPC:          {vpc.id}")
    print(f"  Public-A:     {public_a.id} (10.0.1.0/24)")
    print(f"  Public-B:     {public_b.id} (10.0.2.0/24)")
    print(f"  Private-A:    {private_a.id} (10.0.11.0/24)")
    print(f"  Private-B:    {private_b.id} (10.0.12.0/24)")
    print(f"  IGW:          {igw.id}")
    print(f"  NAT GW:       {nat_gw_id}")
    print(f"  Public RT:    {public_rt.id}")
    print(f"  Private RT:   {private_rt.id}")
    print(f"  Bastion SG:   {bastion_sg.id}")
    print(f"  App SG:       {app_sg.id}")
    print(f"\n*** REMEMBER: NAT GW costs ~$0.045/hour. Tear down when done! ***")

    return vpc.id


if __name__ == '__main__':
    build_vpc()
```

---

## Part 3: Build with Terraform

### Directory Setup

Create a directory `lab02-terraform/` with the following files:

### `main.tf`

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "saa-study"

  default_tags {
    tags = {
      Project = "saa-study"
      Lab     = "lab02"
    }
  }
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-vpc" }
}

# --- Subnets ---
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-${count.index}" }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = { Name = "${var.project_name}-private-${count.index}" }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# --- Elastic IP for NAT Gateway ---
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

# --- NAT Gateway ---
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = { Name = "${var.project_name}-nat-gw" }

  depends_on = [aws_internet_gateway.main]
}

# --- Public Route Table ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private Route Table ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- Security Groups ---
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere (restrict in production)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-bastion-sg" }
}

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Allow HTTP from VPC and SSH from bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-app-sg" }
}
```

### `variables.tf`

```hcl
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging"
  type        = string
  default     = "saa-lab02"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
```

### `outputs.tf`

```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.main.id
}

output "bastion_sg_id" {
  description = "Bastion Security Group ID"
  value       = aws_security_group.bastion.id
}

output "app_sg_id" {
  description = "Application Security Group ID"
  value       = aws_security_group.app.id
}
```

### Deploy and Destroy

```bash
cd lab02-terraform/

# Initialize Terraform
terraform init

# Preview the changes
terraform plan

# Apply (type 'yes' when prompted)
terraform apply

# IMPORTANT: Destroy everything when done (to stop NAT GW charges)
terraform destroy
```

---

## Part 4: Verification

### Verify VPC Structure

```bash
# Describe VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=saa-lab02-vpc" \
  --query 'Vpcs[0].{VpcId:VpcId,CidrBlock:CidrBlock,State:State}' \
  --output table \
  --profile saa-study

# Describe subnets
aws ec2 describe-subnets \
  --filters "Name=tag:Project,Values=saa-study" "Name=tag:Lab,Values=lab02" \
  --query 'Subnets[].{Name:Tags[?Key==`Name`]|[0].Value,SubnetId:SubnetId,CidrBlock:CidrBlock,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch}' \
  --output table \
  --profile saa-study

# Describe route tables
aws ec2 describe-route-tables \
  --filters "Name=tag:Project,Values=saa-study" "Name=tag:Lab,Values=lab02" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`]|[0].Value,RTId:RouteTableId,Routes:Routes[].{Dest:DestinationCidrBlock,Target:GatewayId||NatGatewayId}}' \
  --output json \
  --profile saa-study
```

### Verification Checklist

- [ ] VPC exists with CIDR 10.0.0.0/16 and DNS hostnames enabled.
- [ ] 4 subnets exist in 2 AZs (2 public, 2 private).
- [ ] Public subnets have auto-assign public IP enabled.
- [ ] Internet Gateway is attached to the VPC.
- [ ] NAT Gateway exists in the first public subnet with an Elastic IP.
- [ ] Public route table has a route to the IGW (0.0.0.0/0 -> igw-xxx).
- [ ] Private route table has a route to the NAT GW (0.0.0.0/0 -> nat-xxx).
- [ ] Bastion SG allows SSH inbound.
- [ ] App SG allows HTTP from VPC and SSH from Bastion SG.

---

## Part 5: Cleanup

### AWS CLI Cleanup

```bash
# Delete NAT Gateway first (takes a minute to delete)
aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_GW_ID" --profile saa-study
echo "Waiting for NAT Gateway to delete..."
sleep 60

# Release Elastic IP
aws ec2 release-address --allocation-id "$EIP_ALLOC" --profile saa-study

# Delete subnets
for SUBNET_ID in $PUB_SUBNET_A $PUB_SUBNET_B $PRIV_SUBNET_A $PRIV_SUBNET_B; do
  aws ec2 delete-subnet --subnet-id "$SUBNET_ID" --profile saa-study
done

# Delete route table associations and route tables (custom only)
# First, disassociate, then delete
# [You may need to list associations first with describe-route-tables]

# Detach and delete Internet Gateway
aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --profile saa-study
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --profile saa-study

# Delete security groups (non-default)
aws ec2 delete-security-group --group-id "$BASTION_SG" --profile saa-study
aws ec2 delete-security-group --group-id "$APP_SG" --profile saa-study

# Delete VPC
aws ec2 delete-vpc --vpc-id "$VPC_ID" --profile saa-study

echo "Cleanup complete!"
```

### Terraform Cleanup (much simpler!)

```bash
cd lab02-terraform/
terraform destroy -auto-approve
```

---

## Cost Summary

| Resource | Rate | Duration | Estimated Cost |
|---|---|---|---|
| NAT Gateway | $0.045/hour | 2 hours | $0.09 |
| NAT Gateway data processing | $0.045/GB | Minimal | ~$0.00 |
| Elastic IP (associated) | Free | 2 hours | $0.00 |
| VPC, subnets, IGW, route tables, SGs, NACLs | Free | N/A | $0.00 |
| **Total** | | | **~$0.10** |

---

## Reflection Questions

1. Why does the NAT Gateway need to be in a public subnet?
2. What happens if the single NAT Gateway goes down? How would you make it highly available?
3. Why did we create separate route tables for public and private subnets?
4. What is the difference between the NACL's stateless behavior and the Security Group's stateful behavior in practice?
5. Why is Terraform's `terraform destroy` so much simpler than the CLI cleanup?

[TODO: Add answer key for reflection questions]

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Build with AWS CLI
- Build with Boto3 (Python)
- Build with Terraform
- Cost Summary

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The security group allows the traffic."* |
| ✓ | *"A security group is a stateful allow-list attached to an ENI. Traffic matching an inbound rule is permitted and the reply is permitted automatically, because the connection is tracked — which is why you never write an outbound rule for a reply."* |

**Trace it:** A request from the internet to an instance in a private subnet. Name every hop, every route-table lookup, and every rule evaluated, in order.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — 15 minutes from the AWS Builders' Library, and it changes how you write every client you touch afterwards.
Full list per domain: [`SOURCES.md`](../SOURCES.md#aws)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
