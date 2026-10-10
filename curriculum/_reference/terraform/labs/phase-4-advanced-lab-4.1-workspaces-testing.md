# Lab 4.1: Workspaces & Testing

## Objective

Master workspace management and comprehensive infrastructure testing.

## Duration: 90 minutes

---

## Part 1: Workspace Fundamentals

### Create Workspaces

```bash
# List workspaces
terraform workspace list

# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch workspace
terraform workspace select dev

# Show current
terraform workspace show
```

### Workspace-Aware Configuration

```hcl
# variables.tf
variable "environment_configs" {
  type = map(object({
    instance_type  = string
    instance_count = number
    enable_ha      = bool
  }))
  default = {
    dev = {
      instance_type  = "t2.micro"
      instance_count = 1
      enable_ha      = false
    }
    staging = {
      instance_type  = "t2.small"
      instance_count = 2
      enable_ha      = false
    }
    prod = {
      instance_type  = "t2.medium"
      instance_count = 3
      enable_ha      = true
    }
  }
}

# locals.tf
locals {
  environment = terraform.workspace
  config      = var.environment_configs[local.environment]

  common_tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Workspace   = terraform.workspace
  }
}

# main.tf
resource "aws_instance" "app" {
  count         = local.config.instance_count
  ami           = data.aws_ami.amazon_linux.id
  instance_type = local.config.instance_type

  tags = merge(local.common_tags, {
    Name = "${local.environment}-app-${count.index + 1}"
  })
}
```

### Backend with Workspaces

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
    # State files: env:/dev/app/terraform.tfstate
    #              env:/staging/app/terraform.tfstate
    #              env:/prod/app/terraform.tfstate
  }
}
```

---

## Part 2: Terraform Testing

### Test File Structure

**`project/`**

- `main.tf`
- `variables.tf`
- `outputs.tf`
- `tests/`
  - `basic.tftest.hcl`
  - `validation.tftest.hcl`
  - `integration.tftest.hcl`


### Basic Test

```hcl
# tests/basic.tftest.hcl

# Variables for test
variables {
  environment    = "test"
  instance_count = 2
  instance_type  = "t2.micro"
}

# Test run with plan only
run "plan_infrastructure" {
  command = plan

  assert {
    condition     = length(aws_instance.app) == 2
    error_message = "Expected 2 instances"
  }

  assert {
    condition     = aws_instance.app[0].instance_type == "t2.micro"
    error_message = "Instance type should be t2.micro"
  }
}

# Test run with apply
run "apply_infrastructure" {
  command = apply

  assert {
    condition     = output.instance_ids != null
    error_message = "Instance IDs output should not be null"
  }

  assert {
    condition     = length(output.instance_ids) == 2
    error_message = "Should output 2 instance IDs"
  }
}
```

### Variable Validation Tests

```hcl
# tests/validation.tftest.hcl

# Test valid input
run "valid_environment" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = var.environment == "prod"
    error_message = "Environment should be prod"
  }
}

# Test invalid input (expect failure)
run "invalid_environment" {
  command = plan

  variables {
    environment = "invalid"
  }

  expect_failures = [
    var.environment
  ]
}

# Test CIDR validation
run "valid_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/16"
  }

  assert {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Should be valid CIDR"
  }
}
```

### Module Tests

```hcl
# tests/module.tftest.hcl

run "test_vpc_module" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    name               = "test"
    cidr_block         = "10.0.0.0/16"
    availability_zones = ["us-east-1a", "us-east-1b"]
  }

  assert {
    condition     = output.vpc_id != null
    error_message = "VPC ID should be created"
  }

  assert {
    condition     = length(output.public_subnet_ids) == 2
    error_message = "Should create 2 public subnets"
  }
}
```

### Mock Providers

```hcl
# tests/with_mocks.tftest.hcl

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-12345678"
    }
  }
}

run "test_with_mocks" {
  command = plan

  assert {
    condition     = aws_instance.app[0].ami == "ami-12345678"
    error_message = "Should use mocked AMI"
  }
}
```

### Run Tests

```bash
# Run all tests
terraform test

# Run specific test file
terraform test -filter=tests/basic.tftest.hcl

# Verbose output
terraform test -verbose
```

---

## Part 3: Check Blocks (Runtime Validation)

```hcl
# checks.tf

# Verify external dependency
check "database_health" {
  data "http" "db_health" {
    url = "https://${aws_db_instance.main.endpoint}/health"
  }

  assert {
    condition     = data.http.db_health.status_code == 200
    error_message = "Database health check failed"
  }
}

# Verify certificate expiry
check "certificate_expiry" {
  data "aws_acm_certificate" "main" {
    domain = "example.com"
  }

  assert {
    condition = timecmp(
      data.aws_acm_certificate.main.not_after,
      timeadd(timestamp(), "720h")  # 30 days
    ) > 0
    error_message = "Certificate expires within 30 days"
  }
}

# Verify resource configuration
check "instance_sizing" {
  assert {
    condition = alltrue([
      for inst in aws_instance.app :
      contains(["t2.micro", "t2.small", "t2.medium"], inst.instance_type)
    ])
    error_message = "All instances must use approved instance types"
  }
}
```

---

## Part 4: Preconditions & Postconditions

```hcl
# Precondition: Validate before creation
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  lifecycle {
    precondition {
      condition     = data.aws_subnet.selected.available_ip_address_count > 10
      error_message = "Subnet must have at least 10 available IPs"
    }

    precondition {
      condition     = var.instance_type != "t2.micro" || var.environment != "prod"
      error_message = "t2.micro not allowed in production"
    }

    postcondition {
      condition     = self.private_ip != null
      error_message = "Instance must have private IP"
    }
  }
}

# Data source with postcondition
data "aws_ami" "app" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["app-*"]
  }

  lifecycle {
    postcondition {
      condition     = self.architecture == "x86_64"
      error_message = "AMI must be x86_64 architecture"
    }

    postcondition {
      condition     = timecmp(self.creation_date, timeadd(timestamp(), "-720h")) > 0
      error_message = "AMI must be created within last 30 days"
    }
  }
}

# Output with precondition
output "load_balancer_dns" {
  value = aws_lb.main.dns_name

  precondition {
    condition     = aws_lb.main.dns_name != ""
    error_message = "Load balancer DNS name is empty"
  }
}
```

---

## Part 5: Drift Detection

### Manual Drift Check

```bash
# Detect drift
terraform plan -refresh-only

# Apply state update (sync with reality)
terraform apply -refresh-only -auto-approve
```

### Automated Drift Detection Script

```bash
#!/bin/bash
# detect-drift.sh

set -e

# Run refresh-only plan
terraform plan -refresh-only -detailed-exitcode -out=drift.plan 2>&1 | tee drift.log

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "No drift detected"
elif [ $EXIT_CODE -eq 2 ]; then
    echo "DRIFT DETECTED!"
    terraform show drift.plan
    # Send notification
    # curl -X POST $SLACK_WEBHOOK -d '{"text":"Terraform drift detected!"}'
    exit 1
else
    echo "Error running terraform plan"
    exit 1
fi
```

---

## Exercise: Complete Testing Suite

Create a comprehensive testing suite for a web application infrastructure:

1. Unit tests for individual resources
2. Integration tests for resource relationships
3. Validation tests for input variables
4. Check blocks for runtime validation
5. Drift detection automation

---

## Checkpoint

Before moving to Lab 4.2, verify you can:

- [ ] Create and manage workspaces
- [ ] Write comprehensive Terraform tests
- [ ] Implement check blocks
- [ ] Use preconditions and postconditions
- [ ] Detect and handle drift

---

## Next: Lab 4.2 - CI/CD Integration

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Workspace Fundamentals
- Terraform Testing
- Check Blocks (Runtime Validation)
- Preconditions & Postconditions

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
