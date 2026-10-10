# Lab 3.3: Module Development

## Objective

Create production-ready, reusable Terraform modules with best practices.

## Duration: 120 minutes

---

## Part 1: Module Fundamentals

### Module Structure

**`modules/`**

- `vpc/`
  - `main.tf` — Primary resources
  - `variables.tf` — Input variables
  - `outputs.tf` — Output values
  - `versions.tf` — Provider requirements
  - `locals.tf` — Local values
  - `data.tf` — Data sources
  - `README.md` — Documentation
  - `examples/`
    - `basic/`
      - `main.tf`
      - `outputs.tf`


### Setup

```bash
mkdir -p ~/terraform-learning/modules/{vpc,ec2-instance,security-group}
mkdir -p ~/terraform-learning/modules/vpc/examples/basic
cd ~/terraform-learning/modules
```

---

## Part 2: Create VPC Module

### versions.tf

```hcl
# modules/vpc/versions.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
```

### variables.tf

```hcl
# modules/vpc/variables.tf
variable "name" {
  description = "Name prefix for all resources"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,28}[a-z0-9]$", var.name))
    error_message = "Name must be 4-30 lowercase alphanumeric characters."
  }
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 1 && length(var.availability_zones) <= 6
    error_message = "Must specify 1-6 availability zones."
  }
}

variable "public_subnet_count" {
  description = "Number of public subnets"
  type        = number
  default     = 2

  validation {
    condition     = var.public_subnet_count >= 0 && var.public_subnet_count <= 6
    error_message = "Public subnet count must be 0-6."
  }
}

variable "private_subnet_count" {
  description = "Number of private subnets"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for all AZs (cost saving)"
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
```

### locals.tf

```hcl
# modules/vpc/locals.tf
locals {
  # Calculate subnet CIDRs
  public_subnet_cidrs = [
    for i in range(var.public_subnet_count) :
    cidrsubnet(var.cidr_block, 8, i)
  ]

  private_subnet_cidrs = [
    for i in range(var.private_subnet_count) :
    cidrsubnet(var.cidr_block, 8, i + 100)
  ]

  # NAT Gateway count
  nat_gateway_count = var.enable_nat_gateway ? (
    var.single_nat_gateway ? 1 : var.public_subnet_count
  ) : 0

  # Common tags
  common_tags = merge(var.tags, {
    Module    = "vpc"
    ManagedBy = "Terraform"
  })
}
```

### main.tf

```hcl
# modules/vpc/main.tf

# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(local.common_tags, {
    Name = "${var.name}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  count  = var.public_subnet_count > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-igw"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = var.public_subnet_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.name}-public-${count.index + 1}"
    Type = "public"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count = var.private_subnet_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]

  tags = merge(local.common_tags, {
    Name = "${var.name}-private-${count.index + 1}"
    Type = "private"
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.name}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

# NAT Gateways
resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

# Public Route Table
resource "aws_route_table" "public" {
  count  = var.public_subnet_count > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-public-rt"
  })
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count = var.public_subnet_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Private Route Tables
resource "aws_route_table" "private" {
  count  = var.private_subnet_count > 0 ? (var.single_nat_gateway ? 1 : var.private_subnet_count) : 0
  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-private-rt-${count.index + 1}"
  })
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count = var.private_subnet_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}
```

### outputs.tf

```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.this.arn
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  description = "ID of Internet Gateway"
  value       = try(aws_internet_gateway.this[0].id, null)
}

output "availability_zones" {
  description = "Availability zones used"
  value       = distinct(aws_subnet.public[*].availability_zone)
}
```

---

## Part 3: Create EC2 Instance Module

```hcl
# modules/ec2-instance/variables.tf
variable "name" {
  description = "Name of the instance"
  type        = string
}

variable "ami_id" {
  description = "AMI ID (if not specified, uses latest Amazon Linux 2)"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "Subnet ID to launch instance in"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script"
  type        = string
  default     = null
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Type of root volume"
  type        = string
  default     = "gp3"
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}

variable "associate_public_ip" {
  description = "Associate public IP address"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
```

```hcl
# modules/ec2-instance/main.tf
data "aws_ami" "amazon_linux" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux[0].id
}

resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  user_data                   = var.user_data
  user_data_replace_on_change = true
  iam_instance_profile        = var.iam_instance_profile
  monitoring                  = var.enable_monitoring
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = var.name
  })

  lifecycle {
    ignore_changes = [ami]
  }
}
```

```hcl
# modules/ec2-instance/outputs.tf
output "instance_id" {
  description = "ID of the instance"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.this.public_ip
}

output "private_dns" {
  description = "Private DNS name"
  value       = aws_instance.this.private_dns
}

output "arn" {
  description = "ARN of the instance"
  value       = aws_instance.this.arn
}
```

---

## Part 4: Using Modules

### Basic Usage

```hcl
# main.tf
provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "./modules/vpc"

  name               = "myapp"
  cidr_block         = "10.0.0.0/16"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnet_count  = 2
  private_subnet_count = 2
  enable_nat_gateway   = true
  single_nat_gateway   = true

  tags = {
    Environment = "development"
    Project     = "myapp"
  }
}

module "web_server" {
  source = "./modules/ec2-instance"

  name               = "web-server"
  subnet_id          = module.vpc.public_subnet_ids[0]
  security_group_ids = [aws_security_group.web.id]
  associate_public_ip = true

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx
    systemctl start nginx
  EOF

  tags = {
    Environment = "development"
    Role        = "web"
  }
}

resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = module.vpc.vpc_id

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
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "web_server_ip" {
  value = module.web_server.public_ip
}
```

### Module with for_each

```hcl
variable "environments" {
  default = ["dev", "staging", "prod"]
}

module "vpc" {
  source   = "./modules/vpc"
  for_each = toset(var.environments)

  name               = each.value
  cidr_block         = cidrsubnet("10.0.0.0/8", 8, index(var.environments, each.value))
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  enable_nat_gateway = each.value == "prod"
  single_nat_gateway = true

  tags = {
    Environment = each.value
  }
}

output "vpc_ids" {
  value = { for env, vpc in module.vpc : env => vpc.vpc_id }
}
```

---

## Part 5: Module Versioning

### Using Registry Modules

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}
```

### Using Git Modules

```hcl
# Specific tag
module "vpc" {
  source = "git::https://github.com/org/terraform-modules.git//vpc?ref=v1.2.0"
}

# Specific branch
module "vpc" {
  source = "git::https://github.com/org/terraform-modules.git//vpc?ref=main"
}

# Specific commit
module "vpc" {
  source = "git::https://github.com/org/terraform-modules.git//vpc?ref=abc123"
}

# SSH
module "vpc" {
  source = "git@github.com:org/terraform-modules.git//vpc?ref=v1.0.0"
}
```

---

## Part 6: Module Testing

### Test Configuration

```hcl
# modules/vpc/tests/basic.tftest.hcl
provider "aws" {
  region = "us-east-1"
}

variables {
  name               = "test-vpc"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  public_subnet_count  = 2
  private_subnet_count = 2
  enable_nat_gateway   = false
}

run "create_vpc" {
  command = plan

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block is incorrect"
  }

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Should create 2 public subnets"
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Should create 2 private subnets"
  }
}

run "verify_subnet_cidrs" {
  command = plan

  assert {
    condition     = aws_subnet.public[0].cidr_block == "10.0.0.0/24"
    error_message = "First public subnet CIDR is incorrect"
  }

  assert {
    condition     = aws_subnet.private[0].cidr_block == "10.0.100.0/24"
    error_message = "First private subnet CIDR is incorrect"
  }
}
```

### Run Tests

```bash
cd modules/vpc
terraform test
```

---

## Part 7: Module Best Practices

### Documentation (README.md)

````markdown
# VPC Module

Creates a VPC with public and private subnets, NAT Gateways, and route tables.

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  name               = "myapp"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]

  public_subnet_count  = 2
  private_subnet_count = 2
  enable_nat_gateway   = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Name prefix for resources | string | n/a | yes |
| cidr_block | VPC CIDR block | string | "10.0.0.0/16" | no |
...

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC |
| public_subnet_ids | IDs of public subnets |
...
````

### Generate Documentation

```bash
# Install terraform-docs
brew install terraform-docs

# Generate README
terraform-docs markdown table . > README.md

# Or with template
terraform-docs markdown table --output-file README.md --output-mode inject .
```

---

## Exercise: Create a Complete Module

Create an "application" module that combines:

1. EC2 instances (configurable count)
2. Application Load Balancer
3. Auto Scaling Group
4. Security Groups
5. IAM roles

### Requirements

- Accept VPC and subnet IDs as inputs
- Configurable instance type and count
- Health check configuration
- Complete outputs for all resource IDs

---

## Checkpoint

Before moving to Lab 3.4, verify you can:

- [ ] Structure modules correctly
- [ ] Define comprehensive variables with validation
- [ ] Create meaningful outputs
- [ ] Use modules from registry and Git
- [ ] Write module tests
- [ ] Document modules properly

---

## Next: Lab 3.4 - Dynamic Blocks & Advanced Patterns

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Module Fundamentals
- Create VPC Module
- Create EC2 Instance Module
- Using Modules

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Terraform manages your infrastructure."* |
| ✓ | *"`plan` is a three-way comparison: the configuration (desired), the state file (what Terraform believes it created), and a refresh against the real API (what exists). Almost every confusing result is one of those three drifting from the other two."* |

**Trace it:** `terraform apply` on one resource: config → plan → API call → state write. Then say what happens if the process dies between the API call and the state write.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [the purpose of Terraform state](https://developer.hashicorp.com/terraform/language/state/purpose) — almost every confusing result is a three-way disagreement, spelled out there.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#terraform)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
