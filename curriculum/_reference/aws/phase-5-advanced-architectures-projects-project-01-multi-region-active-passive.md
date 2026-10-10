# Project 01: Multi-Region Active-Passive Architecture

## Overview

Design and deploy a production-grade multi-region active-passive architecture. This project ties together VPC design, compute, databases, DNS, CDN, and storage replication into a single cohesive system. It represents the type of architecture you must be able to design on the SAA-C03 exam.

## Estimated Cost

- **$10-20 for a few hours.** Aurora Global Database, NAT Gateways, ALBs, and EC2 instances in two regions are the primary cost drivers. **Set a 3-hour timer and tear down everything when done.**

---

## Architecture Diagram

```
                              Internet Users
                                    |
                                    v
                           +------------------+
                           | Amazon CloudFront|
                           | (CDN - caches    |
                           |  static content) |
                           +--------+---------+
                                    |
                                    v
                           +------------------+
                           | Route 53         |
                           | Failover Routing |
                           | HC: Primary ALB  |
                           +--------+---------+
                                    |
                  +-----------------+-----------------+
                  |                                   |
                  v (PRIMARY - Active)                v (SECONDARY - Passive)
    PRIMARY REGION (us-east-1)          SECONDARY REGION (us-west-2)

+-----------------------------------+  +-----------------------------------+
| VPC: 10.0.0.0/16                  |  | VPC: 10.1.0.0/16                  |
|                                   |  |                                   |
| Public Subnets:                   |  | Public Subnets:                   |
| +--------+ +--------+            |  | +--------+ +--------+            |
| |10.0.1.0| |10.0.2.0| ALB       |  | |10.1.1.0| |10.1.2.0| ALB       |
| |  /24   | |  /24   |           |  | |  /24   | |  /24   |(scaled    |
| +--------+ +--------+            |  | +--------+ +--------+ down)     |
|                                   |  |                                   |
| Private Subnets (App):            |  | Private Subnets (App):            |
| +--------+ +--------+            |  | +--------+ +--------+            |
| |10.0.3.0| |10.0.4.0| ASG       |  | |10.1.3.0| |10.1.4.0| ASG       |
| |  /24   | |  /24   | (2-4 inst)|  | |  /24   | |  /24   | (0-1 inst)|
| +--------+ +--------+            |  | +--------+ +--------+            |
|                                   |  |                                   |
| Private Subnets (DB):             |  | Private Subnets (DB):             |
| +--------+ +--------+            |  | +--------+ +--------+            |
| |10.0.5.0| |10.0.6.0|            |  | |10.1.5.0| |10.1.6.0|            |
| |  /24   | |  /24   |            |  | |  /24   | |  /24   |            |
| +--------+ +--------+            |  | +--------+ +--------+            |
|                                   |  |                                   |
| Aurora Global DB (Writer)         |  | Aurora Global DB (Reader)         |
| +-----------------------------+   |  | +-----------------------------+   |
| | Primary Cluster             |   |  | | Secondary Cluster           |   |
| | (writer instance +          |<---->| | (reader instance,           |   |
| |  reader instance)           |   |  | |  can be promoted)           |   |
| +-----------------------------+   |  | +-----------------------------+   |
|                                   |  |                                   |
| NAT Gateway (for private subs)    |  | NAT Gateway (for private subs)    |
+-----------------------------------+  +-----------------------------------+

S3 Cross-Region Replication:
+-------------------+  Async Repl   +-------------------+
| S3: static assets |  ---------->  | S3: static assets |
| (us-east-1)       |               | (us-west-2)       |
+-------------------+               +-------------------+
```

---

## Requirements

### Functional Requirements
1. Web application accessible via a single domain name.
2. Static content served through CloudFront CDN.
3. Dynamic content served through ALB -> EC2 (ASG) -> Aurora.
4. Automatic DNS failover if the primary region becomes unhealthy.
5. Database replication to secondary region with < 1 second lag.
6. Static assets replicated to secondary region.

### Non-Functional Requirements
1. RPO: < 1 second (Aurora Global DB replication lag).
2. RTO: < 5 minutes (Route 53 failover + ASG scaling).
3. Primary region handles all write traffic.
4. Secondary region is read-only (warm standby).

---

## Acceptance Criteria

- [ ] Primary region VPC with public, private-app, and private-db subnets across 2 AZs.
- [ ] Secondary region VPC with identical subnet layout.
- [ ] Aurora Global Database with writer in primary, reader in secondary.
- [ ] ALB in both regions, but only primary receives traffic via Route 53.
- [ ] ASG in primary region with desired=2, min=2, max=4.
- [ ] ASG in secondary region with desired=0, min=0, max=4 (warm standby: scale up on failover).
- [ ] Route 53 failover routing with health check on primary ALB.
- [ ] S3 cross-region replication for static assets.
- [ ] CloudFront distribution fronting the primary ALB/S3.
- [ ] All resources tagged with `Project=MultiRegionDR`.
- [ ] Complete teardown script that removes all resources.

---

## Terraform Implementation

### Project Structure

```
multi-region-dr/
  modules/
    vpc/
      main.tf
      variables.tf
      outputs.tf
    aurora/
      main.tf
      variables.tf
      outputs.tf
    compute/
      main.tf
      variables.tf
      outputs.tf
  environments/
    primary/
      main.tf
      terraform.tfvars
    secondary/
      main.tf
      terraform.tfvars
  global/
    route53.tf
    cloudfront.tf
    s3-replication.tf
    aurora-global.tf
```

### VPC Module (modules/vpc/main.tf)

```hcl
variable "vpc_cidr" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type    = string
  default = "primary"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "multi-region-dr-${var.environment}-vpc"
    Project = "MultiRegionDR"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "multi-region-dr-${var.environment}-public-${count.index + 1}"
    Project = "MultiRegionDR"
  }
}

# Private App Subnets
resource "aws_subnet" "private_app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name    = "multi-region-dr-${var.environment}-private-app-${count.index + 1}"
    Project = "MultiRegionDR"
  }
}

# Private DB Subnets
resource "aws_subnet" "private_db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 5)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name    = "multi-region-dr-${var.environment}-private-db-${count.index + 1}"
    Project = "MultiRegionDR"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "multi-region-dr-${var.environment}-igw", Project = "MultiRegionDR" }
}

# NAT Gateway (single NAT for cost savings in lab)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "multi-region-dr-${var.environment}-nat-eip", Project = "MultiRegionDR" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "multi-region-dr-${var.environment}-nat", Project = "MultiRegionDR" }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "multi-region-dr-${var.environment}-public-rt", Project = "MultiRegionDR" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "multi-region-dr-${var.environment}-private-rt", Project = "MultiRegionDR" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_app" {
  count          = 2
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_db" {
  count          = 2
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private.id
}

output "vpc_id" { value = aws_vpc.main.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_app_subnet_ids" { value = aws_subnet.private_app[*].id }
output "private_db_subnet_ids" { value = aws_subnet.private_db[*].id }
```

### Compute Module Skeleton (modules/compute/main.tf)

```hcl
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_app_subnet_ids" { type = list(string) }
variable "environment" { type = string }
variable "desired_capacity" { type = number }
variable "min_size" { type = number }
variable "max_size" { type = number }

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "multi-region-dr-alb-"
  vpc_id      = var.vpc_id

  ingress {
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

  tags = { Project = "MultiRegionDR" }
}

# EC2 Security Group
resource "aws_security_group" "ec2" {
  name_prefix = "multi-region-dr-ec2-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = "MultiRegionDR" }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "multi-region-dr-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = { Project = "MultiRegionDR" }
}

resource "aws_lb_target_group" "main" {
  name     = "mr-dr-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = { Project = "MultiRegionDR" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Launch Template
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_launch_template" "main" {
  name_prefix   = "multi-region-dr-${var.environment}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  network_interfaces {
    security_groups             = [aws_security_group.ec2.id]
    associate_public_ip_address = false
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    echo "<h1>Multi-Region DR - ${var.environment}</h1><p>Instance: $INSTANCE_ID</p><p>AZ: $AZ</p>" > /var/www/html/index.html
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "multi-region-dr-${var.environment}-web", Project = "MultiRegionDR" }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  name                = "multi-region-dr-${var.environment}-asg"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.private_app_subnet_ids
  target_group_arns   = [aws_lb_target_group.main.arn]

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Project"
    value               = "MultiRegionDR"
    propagate_at_launch = true
  }
}

output "alb_dns_name" { value = aws_lb.main.dns_name }
output "alb_zone_id" { value = aws_lb.main.zone_id }
output "alb_arn" { value = aws_lb.main.arn }
```

---

## Deployment Steps

```bash
# Step 1: Deploy primary region
cd multi-region-dr/environments/primary
terraform init
terraform apply -auto-approve

# Step 2: Deploy secondary region
cd ../secondary
terraform init
terraform apply -auto-approve

# Step 3: Deploy global resources (Route 53, CloudFront, Aurora Global, S3 CRR)
cd ../../global
terraform init
terraform apply -auto-approve
```

---

## Failover Test Procedure

1. **Verify primary is healthy:**
   ```bash
   curl http://PRIMARY_ALB_DNS_NAME/
   # Should return response from us-east-1
   ```

2. **Simulate failure** (stop instances in primary ASG):
   ```bash
   aws autoscaling update-auto-scaling-group \
       --auto-scaling-group-name multi-region-dr-primary-asg \
       --desired-capacity 0 --min-size 0 \
       --region us-east-1
   ```

3. **Observe Route 53 failover** (health check fails, DNS switches to secondary).

4. **Scale up secondary:**
   ```bash
   aws autoscaling update-auto-scaling-group \
       --auto-scaling-group-name multi-region-dr-secondary-asg \
       --desired-capacity 2 --min-size 2 \
       --region us-west-2
   ```

5. **Promote Aurora secondary** (if needed):
   ```bash
   # In production, promote the secondary Aurora cluster
   # aws rds failover-global-cluster --global-cluster-identifier multi-region-dr-global ...
   ```

---

## Teardown (CRITICAL)

```bash
# Tear down in reverse order: global -> secondary -> primary

cd multi-region-dr/global
terraform destroy -auto-approve

cd ../environments/secondary
terraform destroy -auto-approve

cd ../primary
terraform destroy -auto-approve

# Verify no resources remain
aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=Project,Values=MultiRegionDR \
    --region us-east-1

aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=Project,Values=MultiRegionDR \
    --region us-west-2
```

---

## What You Learned

1. How to design a complete multi-region active-passive architecture.
2. How Aurora Global Database provides < 1 second cross-region replication.
3. How Route 53 failover routing with health checks enables automatic DNS failover.
4. How ASG in the secondary region can be scaled from 0 to production capacity during failover.
5. How S3 cross-region replication keeps static assets synchronized.
6. How CloudFront provides a single entry point with edge caching.
7. The cost implications of running multi-region infrastructure (and why teardown is critical).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Terraform Implementation
- Deployment Steps
- Failover Test Procedure
- Teardown (CRITICAL)

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
