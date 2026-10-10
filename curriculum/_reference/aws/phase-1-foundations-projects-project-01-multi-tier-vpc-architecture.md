# Capstone Project 01 -- Production-Ready Multi-Tier VPC Architecture

## Project Overview

| Item | Detail |
|---|---|
| **Objective** | Design and deploy a production-ready multi-tier VPC with bastion host, ALB, private application instances, NAT Gateway, and VPC Flow Logs |
| **Estimated time** | 4-6 hours |
| **Cost** | ~$3-7 (NAT GW + ALB + EC2. Tear down within 4-6 hours.) |
| **Prerequisites** | Completed all Phase 1 notes and Labs 01-03 |
| **Deliverables** | Working infrastructure, architecture diagram, Terraform code, Boto3 validation script |
| **Cleanup required** | YES -- Destroy everything immediately after completing the acceptance criteria |

---

## Scenario

You are a solutions architect at a startup building a web application. The CTO has asked you to design and deploy the networking foundation for a three-tier architecture (web, application, database) that meets the following requirements:

1. High availability across two Availability Zones.
2. Public-facing load balancer for incoming web traffic.
3. Application servers in private subnets with no direct internet access.
4. Database tier in isolated subnets with no internet access (not even outbound).
5. A bastion host for SSH access to private instances.
6. All network traffic logged for auditing purposes.
7. Least-privilege security groups following the principle of defense in depth.

---

## Architecture Diagram (Text)

```
                                Internet
                                    |
                           +--------+--------+
                           |  Internet GW    |
                           +--------+--------+
                                    |
                    +---------------+---------------+
                    |                               |
           +-------+-------+              +--------+-------+
           | Public Subnet |              | Public Subnet  |
           |  10.0.1.0/24  |              |  10.0.2.0/24   |
           |   (AZ-a)      |              |   (AZ-b)       |
           +-------+-------+              +--------+-------+
           | - Bastion Host|              |                |
           | - NAT Gateway |              |                |
           | - ALB node    |              | - ALB node     |
           +-------+-------+              +--------+-------+
                    |                               |
           +--------+--------+     +--------+--------+
           |  Application    |     |  Application    |
           |  Load Balancer  +-----+  (cross-AZ)     |
           +--------+--------+     +--------+---------+
                    |                        |
           +-------+-------+       +--------+-------+
           | Private Subnet|       | Private Subnet |
           | (App Tier)    |       | (App Tier)     |
           | 10.0.11.0/24  |       | 10.0.12.0/24   |
           |   (AZ-a)      |       |   (AZ-b)       |
           +-------+-------+       +--------+-------+
           | - Web Server A|       | - Web Server B |
           | - Route: NAT  |       | - Route: NAT   |
           +-------+-------+       +--------+-------+
                    |                        |
           +-------+-------+       +--------+-------+
           | Private Subnet|       | Private Subnet |
           | (DB Tier)     |       | (DB Tier)      |
           | 10.0.21.0/24  |       | 10.0.22.0/24   |
           |   (AZ-a)      |       |   (AZ-b)       |
           +-------+-------+       +--------+-------+
           | - (DB placeholder)    | - (DB placeholder)
           | - Route: local only   | - Route: local only
           +-------------------+   +------------------+

    VPC Flow Logs --> CloudWatch Logs / S3
```

---

## Detailed Requirements

### Requirement 1: VPC and Subnets

| Resource | CIDR | AZ | Purpose |
|---|---|---|---|
| VPC | 10.0.0.0/16 | -- | Main VPC |
| public-a | 10.0.1.0/24 | us-east-1a | ALB, bastion, NAT GW |
| public-b | 10.0.2.0/24 | us-east-1b | ALB |
| app-private-a | 10.0.11.0/24 | us-east-1a | Application servers |
| app-private-b | 10.0.12.0/24 | us-east-1b | Application servers |
| db-private-a | 10.0.21.0/24 | us-east-1a | Database tier (future) |
| db-private-b | 10.0.22.0/24 | us-east-1b | Database tier (future) |

- Enable DNS hostnames and DNS support on the VPC.
- Enable auto-assign public IP on public subnets only.

### Requirement 2: Gateways and Routing

| Route Table | Associated Subnets | Routes |
|---|---|---|
| public-rt | public-a, public-b | 10.0.0.0/16 -> local, 0.0.0.0/0 -> IGW |
| app-private-rt | app-private-a, app-private-b | 10.0.0.0/16 -> local, 0.0.0.0/0 -> NAT GW |
| db-private-rt | db-private-a, db-private-b | 10.0.0.0/16 -> local (NO internet route) |

- One Internet Gateway attached to the VPC.
- One NAT Gateway in public-a with an Elastic IP.
- Database subnets are fully isolated -- no route to NAT GW or IGW.

### Requirement 3: Security Groups

| Security Group | Inbound Rules | Outbound Rules |
|---|---|---|
| **bastion-sg** | SSH (22) from your IP only | All traffic |
| **alb-sg** | HTTP (80) from 0.0.0.0/0, HTTPS (443) from 0.0.0.0/0 | All traffic |
| **app-sg** | HTTP (80) from alb-sg, SSH (22) from bastion-sg | All traffic |
| **db-sg** | MySQL (3306) from app-sg, PostgreSQL (5432) from app-sg | All traffic to 10.0.0.0/16 only |

Key design decisions:
- Security groups reference other security groups (not CIDR blocks) wherever possible.
- Database SG restricts outbound to VPC only (no internet access even if a route existed).
- Bastion SSH is restricted to a single IP (your public IP).

### Requirement 4: Network ACLs

| NACL | Associated Subnets | Key Rules |
|---|---|---|
| **public-nacl** | public-a, public-b | Allow HTTP/HTTPS/SSH inbound + ephemeral outbound |
| **app-nacl** | app-private-a, app-private-b | Allow HTTP from VPC, SSH from VPC, ephemeral ports |
| **db-nacl** | db-private-a, db-private-b | Allow MySQL/PostgreSQL from app subnets ONLY, deny all else |

### Requirement 5: Bastion Host

- t2.micro (Free Tier) in public-a.
- Amazon Linux 2023.
- Key pair for SSH access.
- Security group: SSH from your IP only.
- Used to SSH-hop into private instances.

### Requirement 6: Application Instances

- Two t2.micro instances (one in each app private subnet).
- Run a simple HTTP server (Apache/Nginx) returning instance metadata.
- User data script to install and start the web server.

### Requirement 7: Application Load Balancer

- Internet-facing ALB in public subnets (both AZs).
- HTTP listener on port 80.
- Target group with both app instances.
- Health check: HTTP GET /index.html, interval 30s, healthy threshold 3, unhealthy threshold 2.
- Cross-zone load balancing enabled (default for ALB).

### Requirement 8: VPC Flow Logs

- Enable VPC-level flow logs capturing ALL traffic (ACCEPT and REJECT).
- Send logs to a CloudWatch Logs group named `/vpc/saa-project01-flow-logs`.
- Create an IAM role that allows VPC Flow Logs to publish to CloudWatch Logs.
- Retention: 7 days (to minimize cost).

---

## Implementation Guide

### Phase A: Terraform Infrastructure

Create a `project-01-terraform/` directory with the following structure:

```
project-01-terraform/
  main.tf           # Provider, VPC, subnets
  gateways.tf       # IGW, NAT GW, EIP
  routing.tf        # Route tables and associations
  security.tf       # Security groups
  nacls.tf          # Network ACLs
  compute.tf        # Bastion host, app instances
  loadbalancer.tf   # ALB, target group, listener
  flowlogs.tf       # VPC Flow Logs, IAM role, CloudWatch log group
  variables.tf      # Input variables
  outputs.tf        # Output values
  terraform.tfvars  # Variable values
```

#### Starter: `flowlogs.tf`

```hcl
# CloudWatch Log Group for Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/saa-project01-flow-logs"
  retention_in_days = 7
  tags              = { Name = "saa-project01-flow-logs" }
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {
  name = "saa-project01-flow-logs-role"

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

resource "aws_iam_role_policy" "flow_logs" {
  name = "saa-project01-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

# VPC Flow Log
resource "aws_flow_log" "main" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn             = aws_iam_role.flow_logs.arn

  tags = { Name = "saa-project01-vpc-flow-log" }
}
```

#### Starter: `outputs.tf`

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "DNS name of the ALB -- use this to test"
  value       = aws_lb.main.dns_name
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "app_instance_private_ips" {
  description = "Private IPs of the app instances"
  value       = [for i in aws_instance.app : i.private_ip]
}

output "flow_log_group" {
  description = "CloudWatch Log Group for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}
```

### Phase B: Boto3 Validation Script

Write a Python script that validates the deployed infrastructure:

```python
"""
Project 01 - Infrastructure Validation Script
Verifies that all components are deployed correctly.
Run with: python validate_project01.py
"""

import boto3
import sys

session = boto3.Session(profile_name='saa-study', region_name='us-east-1')
ec2 = session.client('ec2')
elbv2 = session.client('elbv2')
logs = session.client('logs')

PROJECT_TAG = 'saa-project01'
CHECKS_PASSED = 0
CHECKS_FAILED = 0


def check(description: str, condition: bool):
    """Run a validation check."""
    global CHECKS_PASSED, CHECKS_FAILED
    status = "PASS" if condition else "FAIL"
    print(f"  [{status}] {description}")
    if condition:
        CHECKS_PASSED += 1
    else:
        CHECKS_FAILED += 1


def validate_vpc():
    """Validate VPC configuration."""
    print("\n--- VPC Validation ---")
    vpcs = ec2.describe_vpcs(
        Filters=[{'Name': 'tag:Name', 'Values': [f'{PROJECT_TAG}-vpc']}]
    )['Vpcs']

    check("VPC exists", len(vpcs) == 1)
    if vpcs:
        vpc = vpcs[0]
        check("VPC CIDR is 10.0.0.0/16", vpc['CidrBlock'] == '10.0.0.0/16')
        # Check DNS attributes
        dns_hostnames = ec2.describe_vpc_attribute(
            VpcId=vpc['VpcId'], Attribute='enableDnsHostnames'
        )
        check("DNS hostnames enabled", dns_hostnames['EnableDnsHostnames']['Value'])
        return vpc['VpcId']
    return None


def validate_subnets(vpc_id: str):
    """Validate subnet configuration."""
    print("\n--- Subnet Validation ---")
    subnets = ec2.describe_subnets(
        Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}]
    )['Subnets']

    # Exclude default subnets
    custom_subnets = [s for s in subnets if not s.get('DefaultForAz', False)]
    check("6 custom subnets exist", len(custom_subnets) >= 6)

    # Check AZ distribution
    azs = set(s['AvailabilityZone'] for s in custom_subnets)
    check("Subnets span at least 2 AZs", len(azs) >= 2)


def validate_gateways(vpc_id: str):
    """Validate IGW and NAT GW."""
    print("\n--- Gateway Validation ---")
    igws = ec2.describe_internet_gateways(
        Filters=[{'Name': 'attachment.vpc-id', 'Values': [vpc_id]}]
    )['InternetGateways']
    check("Internet Gateway attached", len(igws) == 1)

    nat_gws = ec2.describe_nat_gateways(
        Filters=[
            {'Name': 'vpc-id', 'Values': [vpc_id]},
            {'Name': 'state', 'Values': ['available']}
        ]
    )['NatGateways']
    check("NAT Gateway available", len(nat_gws) >= 1)


def validate_security_groups(vpc_id: str):
    """Validate security group configuration."""
    print("\n--- Security Group Validation ---")
    sgs = ec2.describe_security_groups(
        Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}]
    )['SecurityGroups']

    sg_names = [sg['GroupName'] for sg in sgs]
    for expected in ['bastion-sg', 'alb-sg', 'app-sg', 'db-sg']:
        found = any(expected in name for name in sg_names)
        check(f"Security group '{expected}' exists", found)


def validate_alb():
    """Validate ALB configuration."""
    print("\n--- ALB Validation ---")
    albs = elbv2.describe_load_balancers()['LoadBalancers']
    project_albs = [a for a in albs if PROJECT_TAG in a.get('LoadBalancerName', '')]

    check("ALB exists", len(project_albs) >= 1)
    if project_albs:
        alb = project_albs[0]
        check("ALB is internet-facing", alb['Scheme'] == 'internet-facing')
        check("ALB spans at least 2 AZs", len(alb['AvailabilityZones']) >= 2)

        # Check target group
        tgs = elbv2.describe_target_groups(
            LoadBalancerArn=alb['LoadBalancerArn']
        )['TargetGroups']
        check("Target group exists", len(tgs) >= 1)

        if tgs:
            health = elbv2.describe_target_health(
                TargetGroupArn=tgs[0]['TargetGroupArn']
            )['TargetHealthDescriptions']
            healthy = [t for t in health if t['TargetHealth']['State'] == 'healthy']
            check(f"At least 1 healthy target ({len(healthy)}/{len(health)})", len(healthy) >= 1)


def validate_flow_logs(vpc_id: str):
    """Validate VPC Flow Logs."""
    print("\n--- Flow Logs Validation ---")
    flow_logs = ec2.describe_flow_logs(
        Filters=[{'Name': 'resource-id', 'Values': [vpc_id]}]
    )['FlowLogs']
    check("VPC Flow Logs enabled", len(flow_logs) >= 1)
    if flow_logs:
        check("Flow logs capture ALL traffic", flow_logs[0]['TrafficType'] == 'ALL')


def main():
    print("=" * 60)
    print("PROJECT 01 - INFRASTRUCTURE VALIDATION")
    print("=" * 60)

    vpc_id = validate_vpc()
    if vpc_id:
        validate_subnets(vpc_id)
        validate_gateways(vpc_id)
        validate_security_groups(vpc_id)
        validate_flow_logs(vpc_id)
    validate_alb()

    print("\n" + "=" * 60)
    print(f"RESULTS: {CHECKS_PASSED} passed, {CHECKS_FAILED} failed")
    print("=" * 60)

    sys.exit(0 if CHECKS_FAILED == 0 else 1)


if __name__ == '__main__':
    main()
```

---

## Acceptance Criteria

Your project is complete when ALL of the following are true:

### Infrastructure
- [ ] VPC exists with CIDR 10.0.0.0/16 and DNS hostnames enabled.
- [ ] Six subnets exist across 2 AZs (2 public, 2 app-private, 2 db-private).
- [ ] Internet Gateway is attached to the VPC.
- [ ] NAT Gateway exists in a public subnet with an Elastic IP.
- [ ] Public route table routes 0.0.0.0/0 to the IGW.
- [ ] App-private route table routes 0.0.0.0/0 to the NAT GW.
- [ ] DB-private route table has only the local route (no internet access).

### Security
- [ ] Four security groups exist (bastion, ALB, app, db).
- [ ] Bastion SG allows SSH only from your IP.
- [ ] ALB SG allows HTTP/HTTPS from anywhere.
- [ ] App SG allows HTTP from ALB SG and SSH from bastion SG (SG references, not CIDRs).
- [ ] DB SG allows MySQL/PostgreSQL from app SG only, outbound restricted to VPC.

### Compute and Load Balancing
- [ ] Bastion host is running in a public subnet.
- [ ] Two app instances are running in private subnets (one per AZ).
- [ ] ALB is internet-facing in both public subnets.
- [ ] ALB target group has both app instances registered.
- [ ] ALB health checks pass for at least one target.
- [ ] Hitting the ALB DNS name returns the web page from the app instances.

### Monitoring
- [ ] VPC Flow Logs are enabled for ALL traffic.
- [ ] Flow logs are sent to CloudWatch Logs with 7-day retention.

### Connectivity Tests
- [ ] From your machine: `curl http://<ALB-DNS>` returns the web page.
- [ ] From your machine: SSH into bastion host succeeds.
- [ ] From bastion: SSH into app instance succeeds (via private IP).
- [ ] From app instance: `curl http://google.com` succeeds (via NAT GW).
- [ ] Confirm: DB subnet instances would have NO internet access (verify route table has no 0.0.0.0/0 route).

### Code Quality
- [ ] Terraform code is modular (separate files for networking, security, compute, etc.).
- [ ] All resources are tagged with `Project=saa-study` and `Name=saa-project01-*`.
- [ ] Boto3 validation script passes all checks.
- [ ] A `terraform destroy` cleanly removes all resources.

---

## Stretch Goals (Optional)

1. **Add a second NAT Gateway in AZ-b** for high availability. Update the private route tables so each AZ routes through its own NAT GW.
2. **Add a VPC Gateway Endpoint for S3** so app instances can access S3 without going through the NAT Gateway (saves cost).
3. **Create a Route 53 private hosted zone** with an Alias record pointing to the ALB (e.g., `app.project01.internal`).
4. **Enable ALB access logging** to an S3 bucket.
5. **Create a CloudWatch alarm** that triggers when the ALB has 0 healthy targets.

---

## Cost Summary

| Resource | Rate | Duration | Estimated Cost |
|---|---|---|---|
| NAT Gateway | $0.045/hour | 5 hours | $0.23 |
| ALB | $0.0225/hour | 5 hours | $0.11 |
| EC2 t2.micro x3 | Free Tier | 5 hours | $0.00 |
| Elastic IP (associated) | Free | 5 hours | $0.00 |
| CloudWatch Logs | Free Tier (5 GB) | 7 days | $0.00 |
| VPC components | Free | N/A | $0.00 |
| **Total** | | | **~$0.34** |

> **IMPORTANT:** Run `terraform destroy` immediately after completing the acceptance criteria. Leaving NAT GW and ALB running overnight would cost ~$1.50.

---

## Reflection

After completing the project, write brief answers (2-3 sentences each) for these questions:

1. Why is the database tier in isolated subnets (no internet route) rather than using the same private route table as the app tier?
2. What would happen if the NAT Gateway's AZ (us-east-1a) went down? How would you fix this?
3. Why do the security groups reference other security groups instead of CIDR blocks?
4. If traffic is blocked, how would you use VPC Flow Logs to diagnose the issue?
5. What is the cost implication of adding a second NAT Gateway for HA? Is it worth it?
6. How does this architecture align with the Well-Architected Framework pillars?

[TODO: Add model answers for reflection questions]

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Project Overview
- Architecture Diagram (Text)
- Detailed Requirements
- Stretch Goals

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
