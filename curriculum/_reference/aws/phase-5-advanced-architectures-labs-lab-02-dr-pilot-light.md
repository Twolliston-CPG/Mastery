# Lab 02: Pilot Light Disaster Recovery Simulation

## Objective

Simulate a pilot light DR architecture with a primary region (us-east-1) running an EC2 instance with an RDS database, and a secondary region (us-west-2) with an RDS read replica and AMI ready for failover. Use Route 53 failover routing to simulate automatic DNS failover.

## Estimated Cost

- **$5-10 for a few hours.** RDS instances in two regions, EC2 instances, ALB, and Route 53 health checks all incur hourly charges. **Tear down immediately after the lab.**

## Architecture

```
PRIMARY REGION (us-east-1)                    DR REGION (us-west-2)
+---------------------------+                 +---------------------------+
|  VPC (10.0.0.0/16)       |                 |  VPC (10.1.0.0/16)       |
|                           |                 |                           |
|  +-------+  +----------+ |  Async          |            +----------+   |
|  | ALB   |  | RDS      | |  Replication    |            | RDS Read |   |
|  |       |  | (MySQL   | | ------------->  |            | Replica  |   |
|  +---+---+  | Primary) | |                 |            | (MySQL)  |   |
|      |      +----------+ |                 |            +----------+   |
|  +---+---+               |                 |                           |
|  | EC2   |               |                 |  AMI stored               |
|  | (web  |               |                 |  Launch template ready    |
|  | server)|              |                 |  ALB NOT created yet      |
|  +-------+               |                 |  EC2 NOT running          |
+---------------------------+                 +---------------------------+
        ^                                            ^
        |            Route 53 Failover               |
        +--------------------------------------------+
        (Primary - Active)           (Secondary - Passive)
```

---

## Important Notes Before Starting

- This lab creates resources in TWO AWS regions. Both regions incur charges.
- RDS instances are the most expensive component (~$0.02/hour for db.t3.micro).
- Set a timer for 2-3 hours. Tear down everything when done.
- We use the smallest instance sizes possible (db.t3.micro, t3.micro).

---

## Part 1: Set Up Primary Region (us-east-1) with CLI

### Step 1: Create VPC in Primary Region

```bash
PRIMARY_REGION="us-east-1"

# Create VPC
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --region $PRIMARY_REGION \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=dr-lab-primary-vpc}]' \
    --query 'Vpc.VpcId' --output text)

# Create public subnet
PUB_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone ${PRIMARY_REGION}a \
    --region $PRIMARY_REGION \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=dr-lab-public-1a}]' \
    --query 'Subnet.SubnetId' --output text)

PUB_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone ${PRIMARY_REGION}b \
    --region $PRIMARY_REGION \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=dr-lab-public-1b}]' \
    --query 'Subnet.SubnetId' --output text)

# Create and attach Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --region $PRIMARY_REGION \
    --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $PRIMARY_REGION

# Create route table with internet route
RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $PRIMARY_REGION --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $PRIMARY_REGION
aws ec2 associate-route-table --route-table-id $RTB_ID --subnet-id $PUB_SUBNET_1 --region $PRIMARY_REGION
aws ec2 associate-route-table --route-table-id $RTB_ID --subnet-id $PUB_SUBNET_2 --region $PRIMARY_REGION

echo "Primary VPC: $VPC_ID"
```

### Step 2: Create Security Groups

```bash
# EC2 Security Group (allow HTTP from anywhere)
EC2_SG=$(aws ec2 create-security-group \
    --group-name dr-lab-ec2-sg \
    --description "DR Lab EC2 SG" \
    --vpc-id $VPC_ID \
    --region $PRIMARY_REGION \
    --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $EC2_SG --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $PRIMARY_REGION

# RDS Security Group (allow MySQL from EC2 SG)
RDS_SG=$(aws ec2 create-security-group \
    --group-name dr-lab-rds-sg \
    --description "DR Lab RDS SG" \
    --vpc-id $VPC_ID \
    --region $PRIMARY_REGION \
    --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $RDS_SG --protocol tcp --port 3306 --source-group $EC2_SG --region $PRIMARY_REGION
```

### Step 3: Create RDS Instance in Primary Region

```bash
# Create DB subnet group
aws rds create-db-subnet-group \
    --db-subnet-group-name dr-lab-primary-db-subnet \
    --db-subnet-group-description "DR Lab Primary DB Subnet Group" \
    --subnet-ids $PUB_SUBNET_1 $PUB_SUBNET_2 \
    --region $PRIMARY_REGION

# Create RDS MySQL instance (smallest possible)
aws rds create-db-instance \
    --db-instance-identifier dr-lab-primary-db \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --engine-version 8.0 \
    --master-username admin \
    --master-user-password LabPassword123! \
    --allocated-storage 20 \
    --db-subnet-group-name dr-lab-primary-db-subnet \
    --vpc-security-group-ids $RDS_SG \
    --backup-retention-period 1 \
    --no-multi-az \
    --region $PRIMARY_REGION

echo "Waiting for RDS instance to be available (5-10 minutes)..."
aws rds wait db-instance-available --db-instance-identifier dr-lab-primary-db --region $PRIMARY_REGION
echo "RDS primary instance is ready."

# Get the RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier dr-lab-primary-db \
    --region $PRIMARY_REGION \
    --query 'DBInstances[0].Endpoint.Address' --output text)
echo "RDS Endpoint: $RDS_ENDPOINT"
```

### Step 4: Launch EC2 in Primary Region

```bash
# Get latest Amazon Linux 2023 AMI
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023*-x86_64" "Name=state,Values=available" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text \
    --region $PRIMARY_REGION)

# Launch EC2 with a simple web server user data
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t3.micro \
    --subnet-id $PUB_SUBNET_1 \
    --security-group-ids $EC2_SG \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=dr-lab-primary-web}]' \
    --user-data '#!/bin/bash
yum install -y httpd
systemctl start httpd
systemctl enable httpd
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo "<html><body><h1>DR Lab - Primary Region</h1><p>Instance: $INSTANCE_ID</p><p>AZ: $AZ</p><p>Region: us-east-1</p></body></html>" > /var/www/html/index.html' \
    --region $PRIMARY_REGION \
    --query 'Instances[0].InstanceId' --output text)

echo "Primary EC2: $INSTANCE_ID"
```

### Step 5: Create AMI for DR Region

```bash
# Wait for instance to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $PRIMARY_REGION

# Create AMI from primary instance
AMI_DR=$(aws ec2 create-image \
    --instance-id $INSTANCE_ID \
    --name "dr-lab-web-server-ami" \
    --description "AMI for DR failover" \
    --region $PRIMARY_REGION \
    --query 'ImageId' --output text)

echo "Waiting for AMI to be available..."
aws ec2 wait image-available --image-ids $AMI_DR --region $PRIMARY_REGION

# Copy AMI to DR region
DR_AMI=$(aws ec2 copy-image \
    --source-image-id $AMI_DR \
    --source-region $PRIMARY_REGION \
    --region us-west-2 \
    --name "dr-lab-web-server-ami-copy" \
    --query 'ImageId' --output text)

echo "AMI copied to us-west-2: $DR_AMI"
```

---

## Part 2: Set Up DR Region (us-west-2)

### Step 6: Create VPC in DR Region

```bash
DR_REGION="us-west-2"

# Create VPC in DR region (similar to primary, abbreviated)
DR_VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.1.0.0/16 \
    --region $DR_REGION \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=dr-lab-dr-vpc}]' \
    --query 'Vpc.VpcId' --output text)

DR_SUBNET_1=$(aws ec2 create-subnet --vpc-id $DR_VPC_ID --cidr-block 10.1.1.0/24 \
    --availability-zone ${DR_REGION}a --region $DR_REGION \
    --query 'Subnet.SubnetId' --output text)

DR_SUBNET_2=$(aws ec2 create-subnet --vpc-id $DR_VPC_ID --cidr-block 10.1.2.0/24 \
    --availability-zone ${DR_REGION}b --region $DR_REGION \
    --query 'Subnet.SubnetId' --output text)

# Internet Gateway for DR VPC
DR_IGW=$(aws ec2 create-internet-gateway --region $DR_REGION --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $DR_IGW --vpc-id $DR_VPC_ID --region $DR_REGION

DR_RTB=$(aws ec2 create-route-table --vpc-id $DR_VPC_ID --region $DR_REGION --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $DR_RTB --destination-cidr-block 0.0.0.0/0 --gateway-id $DR_IGW --region $DR_REGION
aws ec2 associate-route-table --route-table-id $DR_RTB --subnet-id $DR_SUBNET_1 --region $DR_REGION
aws ec2 associate-route-table --route-table-id $DR_RTB --subnet-id $DR_SUBNET_2 --region $DR_REGION

echo "DR VPC: $DR_VPC_ID"
```

### Step 7: Create RDS Read Replica in DR Region

```bash
# Create DB subnet group in DR region
DR_RDS_SG=$(aws ec2 create-security-group \
    --group-name dr-lab-rds-sg \
    --description "DR Lab RDS SG" \
    --vpc-id $DR_VPC_ID \
    --region $DR_REGION \
    --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $DR_RDS_SG --protocol tcp --port 3306 --cidr 10.1.0.0/16 --region $DR_REGION

aws rds create-db-subnet-group \
    --db-subnet-group-name dr-lab-dr-db-subnet \
    --db-subnet-group-description "DR Lab DR DB Subnet Group" \
    --subnet-ids $DR_SUBNET_1 $DR_SUBNET_2 \
    --region $DR_REGION

# Create cross-region read replica
aws rds create-db-instance-read-replica \
    --db-instance-identifier dr-lab-dr-replica \
    --source-db-instance-identifier arn:aws:rds:${PRIMARY_REGION}:$(aws sts get-caller-identity --query Account --output text):db:dr-lab-primary-db \
    --db-instance-class db.t3.micro \
    --db-subnet-group-name dr-lab-dr-db-subnet \
    --vpc-security-group-ids $DR_RDS_SG \
    --region $DR_REGION

echo "Waiting for read replica (this takes 10-15 minutes)..."
aws rds wait db-instance-available --db-instance-identifier dr-lab-dr-replica --region $DR_REGION
echo "Read replica is ready in $DR_REGION"
```

---

## Part 3: Simulate Failover

### Step 8: Simulate a Disaster (Conceptual)

In a real pilot light DR scenario, the failover process would be:

```
1. Route 53 health check detects primary region failure.
2. DNS automatically fails over to secondary region.
3. Operations team (or automation) performs these steps:

   a. PROMOTE the RDS read replica to standalone instance:
      aws rds promote-read-replica \
          --db-instance-identifier dr-lab-dr-replica \
          --region us-west-2

   b. LAUNCH EC2 instances from the copied AMI:
      aws ec2 run-instances \
          --image-id $DR_AMI \
          --instance-type t3.micro \
          --subnet-id $DR_SUBNET_1 \
          --region us-west-2

   c. UPDATE application configuration to point to new RDS endpoint.

   d. VERIFY the application is working in the DR region.
```

**Note:** We will NOT execute the actual failover promotion in this lab to avoid additional costs and complexity. The purpose is to verify that the DR infrastructure (read replica, AMI, VPC) is in place and ready.

### Step 9: Verify DR Readiness

```bash
# Verify RDS read replica exists and is available
aws rds describe-db-instances \
    --db-instance-identifier dr-lab-dr-replica \
    --region $DR_REGION \
    --query 'DBInstances[0].{Status:DBInstanceStatus,Engine:Engine,Endpoint:Endpoint.Address}' \
    --output table

# Verify AMI exists in DR region
aws ec2 describe-images \
    --image-ids $DR_AMI \
    --region $DR_REGION \
    --query 'Images[0].{State:State,Name:Name}' \
    --output table

# Verify VPC and subnets exist in DR region
aws ec2 describe-vpcs --vpc-ids $DR_VPC_ID --region $DR_REGION \
    --query 'Vpcs[0].{VpcId:VpcId,CidrBlock:CidrBlock,State:State}' \
    --output table
```

---

## Part 4: Route 53 Failover Configuration (Conceptual)

If you have a Route 53 hosted zone and domain, you would configure failover routing like this:

```bash
# NOTE: This requires a registered domain and hosted zone.
# The commands below are for reference only.

# Create health check for primary region ALB
# aws route53 create-health-check --caller-reference primary-hc-$(date +%s) \
#     --health-check-config Type=HTTP,FullyQualifiedDomainName=primary-alb.us-east-1.elb.amazonaws.com,Port=80,RequestInterval=30,FailureThreshold=3

# Create failover record for primary
# aws route53 change-resource-record-sets --hosted-zone-id Z1234567890 \
#     --change-batch '{
#         "Changes": [{
#             "Action": "CREATE",
#             "ResourceRecordSet": {
#                 "Name": "app.example.com",
#                 "Type": "A",
#                 "SetIdentifier": "primary",
#                 "Failover": "PRIMARY",
#                 "AliasTarget": {
#                     "HostedZoneId": "Z35SXDOTRQ7X7K",
#                     "DNSName": "primary-alb.us-east-1.elb.amazonaws.com",
#                     "EvaluateTargetHealth": true
#                 },
#                 "HealthCheckId": "health-check-id"
#             }
#         }]
#     }'

# Create failover record for secondary
# (Similar, with Failover: "SECONDARY")
```

---

## Cleanup (CRITICAL -- Do This Now)

**Multi-region resources cost money every hour. Clean up immediately.**

```bash
# ---- DR Region (us-west-2) ----
# Delete RDS read replica
aws rds delete-db-instance --db-instance-identifier dr-lab-dr-replica --skip-final-snapshot --region us-west-2
echo "Waiting for DR replica deletion..."
aws rds wait db-instance-deleted --db-instance-identifier dr-lab-dr-replica --region us-west-2

# Delete DR DB subnet group
aws rds delete-db-subnet-group --db-subnet-group-name dr-lab-dr-db-subnet --region us-west-2

# Delete DR security group
aws ec2 delete-security-group --group-id $DR_RDS_SG --region us-west-2

# Delete DR subnets, IGW, route table, VPC
aws ec2 delete-subnet --subnet-id $DR_SUBNET_1 --region us-west-2
aws ec2 delete-subnet --subnet-id $DR_SUBNET_2 --region us-west-2
aws ec2 disassociate-route-table --association-id $(aws ec2 describe-route-tables --route-table-ids $DR_RTB --region us-west-2 --query 'RouteTables[0].Associations[?!Main].RouteTableAssociationId' --output text) --region us-west-2 2>/dev/null
aws ec2 delete-route-table --route-table-id $DR_RTB --region us-west-2
aws ec2 detach-internet-gateway --internet-gateway-id $DR_IGW --vpc-id $DR_VPC_ID --region us-west-2
aws ec2 delete-internet-gateway --internet-gateway-id $DR_IGW --region us-west-2
aws ec2 delete-vpc --vpc-id $DR_VPC_ID --region us-west-2

# Deregister copied AMI
aws ec2 deregister-image --image-id $DR_AMI --region us-west-2

# ---- Primary Region (us-east-1) ----
# Terminate EC2
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region us-east-1

# Delete RDS
aws rds delete-db-instance --db-instance-identifier dr-lab-primary-db --skip-final-snapshot --region us-east-1
echo "Waiting for primary RDS deletion..."
aws rds wait db-instance-deleted --db-instance-identifier dr-lab-primary-db --region us-east-1

# Delete primary DB subnet group
aws rds delete-db-subnet-group --db-subnet-group-name dr-lab-primary-db-subnet --region us-east-1

# Deregister AMI
aws ec2 deregister-image --image-id $AMI_DR --region us-east-1

# Delete security groups, subnets, IGW, VPC
aws ec2 delete-security-group --group-id $EC2_SG --region us-east-1
aws ec2 delete-security-group --group-id $RDS_SG --region us-east-1
aws ec2 delete-subnet --subnet-id $PUB_SUBNET_1 --region us-east-1
aws ec2 delete-subnet --subnet-id $PUB_SUBNET_2 --region us-east-1
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region us-east-1
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region us-east-1
aws ec2 delete-vpc --vpc-id $VPC_ID --region us-east-1

echo "All resources cleaned up."
```

---

## What You Learned

1. How pilot light DR works: core data replicated, compute ready but not running.
2. How to create a cross-region RDS read replica.
3. How to copy an AMI to a DR region for rapid instance launch.
4. The failover process: promote replica, launch compute, update DNS.
5. Why pilot light is cost-effective: you only pay for the RDS read replica and storage, not for idle compute.
6. The importance of tearing down multi-region resources to control costs.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Important Notes Before Starting
- Set Up Primary Region (us-east-1) with CLI
- Set Up DR Region (us-west-2)
- Simulate Failover

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
