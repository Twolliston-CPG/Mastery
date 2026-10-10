# Lab 03 -- Route 53 and Elastic Load Balancing

## Lab Overview

| Item | Detail |
|---|---|
| **Objective** | Configure a Route 53 hosted zone with health checks, set up an ALB with target groups |
| **Estimated time** | 90-120 minutes |
| **Cost** | ~$2-5 (ALB: ~$0.0225/hour, Hosted zone: $0.50/month, EC2 instances: Free Tier eligible) |
| **Prerequisites** | AWS CLI v2, Python 3.10+ with boto3, completed Lab 02 (or a VPC to work with) |
| **Cleanup required** | YES -- ALB and hosted zone charge per hour/month. Destroy when done. |

> **Note on domain names:** This lab creates a private hosted zone (free DNS queries) to avoid requiring a purchased domain. If you already own a domain, you can adapt the steps to use a public hosted zone.

---

## What You Will Build

1. Two EC2 instances running a simple web server in private subnets.
2. An Application Load Balancer (ALB) in public subnets.
3. A target group with both EC2 instances registered.
4. ALB health checks configured.
5. A Route 53 private hosted zone with an Alias record pointing to the ALB.
6. A Route 53 health check monitoring the ALB.

---

## Architecture

```
                          Internet
                              |
                       Route 53 (DNS)
                       lab.saa-study.internal
                              |
                        (Alias record)
                              |
                    Application Load Balancer
                    (public subnets, AZ-a + AZ-b)
                              |
                    +----+----+----+
                    |              |
               Target Group:
               Web Instance A    Web Instance B
               (private-a)       (private-b)
               10.0.11.x        10.0.12.x
```

---

## Part 1: Launch EC2 Instances (AWS CLI)

### Step 1.1 -- Find the Latest Amazon Linux 2023 AMI

```bash
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters \
    "Name=name,Values=al2023-ami-2023*-x86_64" \
    "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --profile saa-study)

echo "AMI ID: $AMI_ID"
```

### Step 1.2 -- Create a Key Pair (if you don't have one)

```bash
aws ec2 create-key-pair \
  --key-name saa-lab-key \
  --query 'KeyMaterial' \
  --output text \
  --profile saa-study > saa-lab-key.pem

chmod 400 saa-lab-key.pem
```

### Step 1.3 -- Create a User Data Script

Create a file called `user-data.sh`:

```bash
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo "<html><body><h1>Hello from SAA Study Lab!</h1><p>Instance: $INSTANCE_ID</p><p>AZ: $AZ</p></body></html>" > /var/www/html/index.html
```

### Step 1.4 -- Launch Instances in Private Subnets

```bash
# You need the VPC, subnet, and security group IDs from Lab 02.
# If you tore down Lab 02, rebuild the VPC first (use Terraform for speed).

# Launch Instance A in private-a
INSTANCE_A=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t2.micro \
  --key-name saa-lab-key \
  --subnet-id "$PRIV_SUBNET_A" \
  --security-group-ids "$APP_SG" \
  --user-data file://user-data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=saa-lab03-web-a},{Key=Project,Value=saa-study}]' \
  --query 'Instances[0].InstanceId' \
  --output text \
  --profile saa-study)

# Launch Instance B in private-b
INSTANCE_B=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t2.micro \
  --key-name saa-lab-key \
  --subnet-id "$PRIV_SUBNET_B" \
  --security-group-ids "$APP_SG" \
  --user-data file://user-data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=saa-lab03-web-b},{Key=Project,Value=saa-study}]' \
  --query 'Instances[0].InstanceId' \
  --output text \
  --profile saa-study)

echo "Instance A: $INSTANCE_A"
echo "Instance B: $INSTANCE_B"

# Wait for instances to be running
aws ec2 wait instance-running --instance-ids "$INSTANCE_A" "$INSTANCE_B" --profile saa-study
echo "Both instances are running."
```

---

## Part 2: Create the Application Load Balancer (AWS CLI)

### Step 2.1 -- Create ALB Security Group

```bash
ALB_SG=$(aws ec2 create-security-group \
  --group-name saa-lab03-alb-sg \
  --description "Allow HTTP/HTTPS from internet" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text \
  --profile saa-study)

# Allow HTTP from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id "$ALB_SG" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --profile saa-study

# Allow HTTPS from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id "$ALB_SG" \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --profile saa-study

echo "ALB SG: $ALB_SG"

# Update App SG to allow traffic from ALB SG (instead of VPC CIDR)
aws ec2 authorize-security-group-ingress \
  --group-id "$APP_SG" \
  --protocol tcp \
  --port 80 \
  --source-group "$ALB_SG" \
  --profile saa-study
```

### Step 2.2 -- Create the ALB

```bash
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name saa-lab03-alb \
  --subnets "$PUB_SUBNET_A" "$PUB_SUBNET_B" \
  --security-groups "$ALB_SG" \
  --scheme internet-facing \
  --type application \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text \
  --profile saa-study)

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].DNSName' \
  --output text \
  --profile saa-study)

ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].CanonicalHostedZoneId' \
  --output text \
  --profile saa-study)

echo "ALB ARN: $ALB_ARN"
echo "ALB DNS: $ALB_DNS"
echo "ALB Zone ID: $ALB_ZONE_ID"
```

### Step 2.3 -- Create a Target Group

```bash
TG_ARN=$(aws elbv2 create-target-group \
  --name saa-lab03-web-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id "$VPC_ID" \
  --health-check-protocol HTTP \
  --health-check-path "/index.html" \
  --health-check-interval-seconds 30 \
  --healthy-threshold-count 3 \
  --unhealthy-threshold-count 2 \
  --target-type instance \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text \
  --profile saa-study)

echo "Target Group ARN: $TG_ARN"
```

### Step 2.4 -- Register Targets

```bash
aws elbv2 register-targets \
  --target-group-arn "$TG_ARN" \
  --targets Id="$INSTANCE_A" Id="$INSTANCE_B" \
  --profile saa-study

echo "Registered instances in target group."
```

### Step 2.5 -- Create a Listener

```bash
aws elbv2 create-listener \
  --load-balancer-arn "$ALB_ARN" \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn="$TG_ARN" \
  --profile saa-study

echo "Listener created on port 80."
```

### Step 2.6 -- Test the ALB

```bash
# Wait a minute for health checks to pass, then:
echo "Testing ALB..."
curl -s "http://$ALB_DNS"

# Run multiple times to see traffic distributed across instances:
for i in {1..10}; do
  curl -s "http://$ALB_DNS" | grep "Instance"
  sleep 1
done
```

---

## Part 3: Configure Route 53 (AWS CLI)

### Step 3.1 -- Create a Private Hosted Zone

```bash
HOSTED_ZONE_ID=$(aws route53 create-hosted-zone \
  --name saa-study.internal \
  --caller-reference "lab03-$(date +%s)" \
  --vpc VPCRegion=us-east-1,VPCId="$VPC_ID" \
  --hosted-zone-config Comment="SAA Study Lab 03",PrivateZone=true \
  --query 'HostedZone.Id' \
  --output text \
  --profile saa-study)

echo "Hosted Zone ID: $HOSTED_ZONE_ID"
```

### Step 3.2 -- Create an Alias Record for the ALB

```bash
# Create a JSON change batch file
cat > route53-alias-record.json << EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "web.saa-study.internal",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_ZONE_ID",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch file://route53-alias-record.json \
  --profile saa-study

echo "Alias record created: web.saa-study.internal -> $ALB_DNS"
```

### Step 3.3 -- Create a Route 53 Health Check

```bash
HEALTH_CHECK_ID=$(aws route53 create-health-check \
  --caller-reference "lab03-hc-$(date +%s)" \
  --health-check-config '{
    "FullyQualifiedDomainName": "'"$ALB_DNS"'",
    "Port": 80,
    "Type": "HTTP",
    "ResourcePath": "/index.html",
    "RequestInterval": 30,
    "FailureThreshold": 3
  }' \
  --query 'HealthCheck.Id' \
  --output text \
  --profile saa-study)

echo "Health Check ID: $HEALTH_CHECK_ID"

# Check health status
aws route53 get-health-check-status \
  --health-check-id "$HEALTH_CHECK_ID" \
  --profile saa-study
```

### Step 3.4 -- Verify DNS Resolution (from within the VPC)

Since this is a private hosted zone, DNS resolution only works from within the associated VPC. If you have a bastion host or EC2 instance in the VPC:

```bash
# SSH into a bastion/public instance, then:
# dig web.saa-study.internal
# curl http://web.saa-study.internal
```

Alternatively, verify the record was created:

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --query 'ResourceRecordSets[?Name==`web.saa-study.internal.`]' \
  --output json \
  --profile saa-study
```

---

## Part 4: Build with Boto3 (Python)

```python
"""
Lab 03 - Route 53 + ALB with Boto3
Run with: python lab03_route53_elb_boto3.py
"""

import boto3
import json
import time

session = boto3.Session(profile_name='saa-study', region_name='us-east-1')
ec2_client = session.client('ec2')
elbv2 = session.client('elbv2')
route53 = session.client('route53')


def create_alb(name: str, subnets: list, security_groups: list) -> dict:
    """Create an internet-facing Application Load Balancer."""
    response = elbv2.create_load_balancer(
        Name=name,
        Subnets=subnets,
        SecurityGroups=security_groups,
        Scheme='internet-facing',
        Type='application',
        Tags=[
            {'Key': 'Project', 'Value': 'saa-study'},
            {'Key': 'Lab', 'Value': 'lab03'}
        ]
    )
    alb = response['LoadBalancers'][0]
    print(f"ALB created: {alb['DNSName']}")
    print(f"  ARN: {alb['LoadBalancerArn']}")
    print(f"  Zone ID: {alb['CanonicalHostedZoneId']}")
    return alb


def create_target_group(name: str, vpc_id: str) -> str:
    """Create a target group with HTTP health checks."""
    response = elbv2.create_target_group(
        Name=name,
        Protocol='HTTP',
        Port=80,
        VpcId=vpc_id,
        HealthCheckProtocol='HTTP',
        HealthCheckPath='/index.html',
        HealthCheckIntervalSeconds=30,
        HealthyThresholdCount=3,
        UnhealthyThresholdCount=2,
        TargetType='instance',
        Tags=[
            {'Key': 'Project', 'Value': 'saa-study'},
            {'Key': 'Lab', 'Value': 'lab03'}
        ]
    )
    tg_arn = response['TargetGroups'][0]['TargetGroupArn']
    print(f"Target group created: {tg_arn}")
    return tg_arn


def register_targets(tg_arn: str, instance_ids: list):
    """Register EC2 instances in the target group."""
    targets = [{'Id': iid} for iid in instance_ids]
    elbv2.register_targets(TargetGroupArn=tg_arn, Targets=targets)
    print(f"Registered {len(instance_ids)} targets in target group.")


def create_listener(alb_arn: str, tg_arn: str):
    """Create an HTTP listener that forwards to the target group."""
    elbv2.create_listener(
        LoadBalancerArn=alb_arn,
        Protocol='HTTP',
        Port=80,
        DefaultActions=[{
            'Type': 'forward',
            'TargetGroupArn': tg_arn
        }]
    )
    print("HTTP listener created on port 80.")


def create_private_hosted_zone(domain: str, vpc_id: str, region: str) -> str:
    """Create a private hosted zone associated with a VPC."""
    response = route53.create_hosted_zone(
        Name=domain,
        CallerReference=f"lab03-{int(time.time())}",
        VPC={
            'VPCRegion': region,
            'VPCId': vpc_id
        },
        HostedZoneConfig={
            'Comment': 'SAA Study Lab 03 - Private Hosted Zone',
            'PrivateZone': True
        }
    )
    zone_id = response['HostedZone']['Id']
    print(f"Private hosted zone created: {domain}")
    print(f"  Zone ID: {zone_id}")
    return zone_id


def create_alias_record(zone_id: str, record_name: str, alb_dns: str, alb_zone_id: str):
    """Create an Alias A record pointing to the ALB."""
    route53.change_resource_record_sets(
        HostedZoneId=zone_id,
        ChangeBatch={
            'Changes': [{
                'Action': 'CREATE',
                'ResourceRecordSet': {
                    'Name': record_name,
                    'Type': 'A',
                    'AliasTarget': {
                        'HostedZoneId': alb_zone_id,
                        'DNSName': alb_dns,
                        'EvaluateTargetHealth': True
                    }
                }
            }]
        }
    )
    print(f"Alias record created: {record_name} -> {alb_dns}")


def create_health_check(fqdn: str, path: str = '/index.html') -> str:
    """Create a Route 53 health check for the ALB."""
    response = route53.create_health_check(
        CallerReference=f"lab03-hc-{int(time.time())}",
        HealthCheckConfig={
            'FullyQualifiedDomainName': fqdn,
            'Port': 80,
            'Type': 'HTTP',
            'ResourcePath': path,
            'RequestInterval': 30,
            'FailureThreshold': 3
        }
    )
    hc_id = response['HealthCheck']['Id']
    print(f"Health check created: {hc_id}")
    return hc_id


def check_target_health(tg_arn: str):
    """Check the health status of targets in a target group."""
    response = elbv2.describe_target_health(TargetGroupArn=tg_arn)
    print("\nTarget Health:")
    for target in response['TargetHealthDescriptions']:
        print(f"  {target['Target']['Id']}: {target['TargetHealth']['State']}")


# --- Main execution ---
# Uncomment and fill in your resource IDs from Lab 02:
#
# VPC_ID = 'vpc-xxxxxxxx'
# PUB_SUBNET_A = 'subnet-xxxxxxxx'
# PUB_SUBNET_B = 'subnet-xxxxxxxx'
# ALB_SG = 'sg-xxxxxxxx'
# INSTANCE_A = 'i-xxxxxxxx'
# INSTANCE_B = 'i-xxxxxxxx'
#
# alb = create_alb('saa-lab03-alb', [PUB_SUBNET_A, PUB_SUBNET_B], [ALB_SG])
# tg_arn = create_target_group('saa-lab03-web-tg', VPC_ID)
# register_targets(tg_arn, [INSTANCE_A, INSTANCE_B])
# create_listener(alb['LoadBalancerArn'], tg_arn)
#
# # Wait for ALB to be active
# print("Waiting for ALB to be active...")
# waiter = elbv2.get_waiter('load_balancer_available')
# waiter.wait(LoadBalancerArns=[alb['LoadBalancerArn']])
# print("ALB is active!")
#
# zone_id = create_private_hosted_zone('saa-study.internal', VPC_ID, 'us-east-1')
# create_alias_record(zone_id, 'web.saa-study.internal', alb['DNSName'], alb['CanonicalHostedZoneId'])
# hc_id = create_health_check(alb['DNSName'])
#
# # Check target health
# time.sleep(60)  # Wait for health checks
# check_target_health(tg_arn)
```

---

## Part 5: Experiment with Routing Policies

### Experiment A: Weighted Routing (Simulated)

Even with a private hosted zone, you can create weighted records to understand the concept:

```bash
# Create two weighted A records pointing to different IPs
cat > route53-weighted.json << 'EOF'
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "weighted.saa-study.internal",
        "Type": "A",
        "SetIdentifier": "primary",
        "Weight": 70,
        "TTL": 60,
        "ResourceRecords": [{"Value": "10.0.11.10"}]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "weighted.saa-study.internal",
        "Type": "A",
        "SetIdentifier": "secondary",
        "Weight": 30,
        "TTL": 60,
        "ResourceRecords": [{"Value": "10.0.12.10"}]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch file://route53-weighted.json \
  --profile saa-study
```

### Experiment B: Failover Routing (Simulated)

```bash
cat > route53-failover.json << 'EOF'
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "failover.saa-study.internal",
        "Type": "A",
        "SetIdentifier": "primary",
        "Failover": "PRIMARY",
        "TTL": 60,
        "ResourceRecords": [{"Value": "10.0.11.10"}]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "failover.saa-study.internal",
        "Type": "A",
        "SetIdentifier": "secondary",
        "Failover": "SECONDARY",
        "TTL": 60,
        "ResourceRecords": [{"Value": "10.0.12.10"}]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch file://route53-failover.json \
  --profile saa-study
```

---

## Part 6: Cleanup

**IMPORTANT:** Clean up in this order to avoid dependency errors.

```bash
# 1. Delete Route 53 health check
aws route53 delete-health-check --health-check-id "$HEALTH_CHECK_ID" --profile saa-study

# 2. Delete Route 53 records (you must delete non-default records before the hosted zone)
#    List all records and delete non-NS/SOA records:
aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --profile saa-study
# Delete each custom record using change-resource-record-sets with Action: DELETE

# 3. Delete the hosted zone
aws route53 delete-hosted-zone --id "$HOSTED_ZONE_ID" --profile saa-study

# 4. Delete ALB listener (deleted automatically with ALB)
# 5. Delete ALB
aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --profile saa-study
echo "Waiting for ALB to delete..."
sleep 30

# 6. Delete target group
aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --profile saa-study

# 7. Terminate EC2 instances
aws ec2 terminate-instances --instance-ids "$INSTANCE_A" "$INSTANCE_B" --profile saa-study

# 8. Delete ALB security group (after ALB is fully deleted)
sleep 30
aws ec2 delete-security-group --group-id "$ALB_SG" --profile saa-study

# 9. Clean up VPC resources from Lab 02 if you haven't already
# (NAT Gateway, EIP, subnets, route tables, IGW, SGs, VPC)

echo "Cleanup complete!"
```

---

## Cost Summary

| Resource | Rate | Duration | Estimated Cost |
|---|---|---|---|
| ALB | $0.0225/hour | 2 hours | $0.045 |
| EC2 t2.micro x2 | Free Tier | 2 hours | $0.00 |
| Private Hosted Zone | $0.50/month (prorated) | 1 day | ~$0.02 |
| Route 53 Health Check | $0.50/month (prorated) | 1 day | ~$0.02 |
| NAT Gateway (if from Lab 02) | $0.045/hour | 2 hours | $0.09 |
| **Total** | | | **~$0.18** |

---

## Reflection Questions

1. What is the difference between an Alias record and a CNAME record? Why did we use an Alias record for the ALB?
2. Why can't Route 53 health checks directly monitor the EC2 instances in private subnets?
3. What happens to traffic if one of the two target instances fails its health check?
4. If you needed to route 80% of traffic to Instance A and 20% to Instance B, what Route 53 routing policy would you use?
5. Why does the ALB need to be in public subnets while the EC2 instances are in private subnets?

[TODO: Add answer key for reflection questions]

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Launch EC2 Instances (AWS CLI)
- Create the Application Load Balancer (AWS CLI)
- Configure Route 53 (AWS CLI)
- Build with Boto3 (Python)

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
