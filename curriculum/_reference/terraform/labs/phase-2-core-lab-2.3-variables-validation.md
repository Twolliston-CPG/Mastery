# Lab 2.3: Variables & Validation

## Objective

Master input variables, outputs, local values, and validation rules for robust configurations.

## Duration: 60 minutes

---

## Part 1: Variable Types & Constraints

### Primitive Types

```hcl
# variables.tf

# String
variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "dev"
}

# Number
variable "instance_count" {
  type        = number
  description = "Number of instances to create"
  default     = 1
}

# Boolean
variable "enable_monitoring" {
  type        = bool
  description = "Enable detailed CloudWatch monitoring"
  default     = false
}
```

### Collection Types

```hcl
# List - Ordered, can have duplicates
variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Set - Unordered, unique values only
variable "allowed_ips" {
  type        = set(string)
  description = "Set of allowed IP addresses"
  default     = ["10.0.0.1", "10.0.0.2"]
}

# Map - Key-value pairs
variable "instance_types" {
  type        = map(string)
  description = "Instance types per environment"
  default = {
    dev     = "t2.micro"
    staging = "t2.small"
    prod    = "t2.medium"
  }
}
```

### Structural Types

```hcl
# Object - Named attributes with specific types
variable "database_config" {
  type = object({
    engine         = string
    engine_version = string
    instance_class = string
    storage_size   = number
    multi_az       = bool
    backup_retention_days = optional(number, 7)  # Optional with default
  })

  description = "Database configuration"

  default = {
    engine         = "postgres"
    engine_version = "15"
    instance_class = "db.t3.micro"
    storage_size   = 20
    multi_az       = false
  }
}

# Tuple - Fixed-length with specific types per position
variable "server_config" {
  type        = tuple([string, number, bool])
  description = "Server config: [name, port, ssl_enabled]"
  default     = ["web-server", 443, true]
}
```

### Nested Complex Types

```hcl
variable "applications" {
  type = map(object({
    port           = number
    protocol       = string
    health_check   = object({
      path     = string
      interval = number
      timeout  = number
    })
    instances = list(object({
      name          = string
      instance_type = string
    }))
  }))

  default = {
    frontend = {
      port     = 80
      protocol = "HTTP"
      health_check = {
        path     = "/"
        interval = 30
        timeout  = 5
      }
      instances = [
        { name = "web-1", instance_type = "t2.micro" },
        { name = "web-2", instance_type = "t2.micro" }
      ]
    }
    backend = {
      port     = 8080
      protocol = "HTTP"
      health_check = {
        path     = "/health"
        interval = 10
        timeout  = 3
      }
      instances = [
        { name = "api-1", instance_type = "t2.small" }
      ]
    }
  }
}
```

---

## Part 2: Variable Validation

### Basic Validation

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "instance_count" {
  type        = number
  description = "Number of instances"

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}
```

### String Pattern Validation

```hcl
variable "project_name" {
  type        = string
  description = "Project name for resource naming"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,28}[a-z0-9]$", var.project_name))
    error_message = "Project name must be 4-30 characters, start with letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "email" {
  type        = string
  description = "Contact email"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.email))
    error_message = "Must be a valid email address."
  }
}

variable "cidr_block" {
  type        = string
  description = "VPC CIDR block"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid CIDR notation (e.g., 10.0.0.0/16)."
  }

  validation {
    condition     = tonumber(split("/", var.cidr_block)[1]) >= 16 && tonumber(split("/", var.cidr_block)[1]) <= 28
    error_message = "CIDR prefix must be between /16 and /28."
  }
}
```

### Multiple Validation Rules

```hcl
variable "bucket_name" {
  type        = string
  description = "S3 bucket name"

  # Length validation
  validation {
    condition     = length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63
    error_message = "Bucket name must be between 3 and 63 characters."
  }

  # Character validation
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must start and end with letter/number, contain only lowercase, numbers, dots, hyphens."
  }

  # No consecutive dots
  validation {
    condition     = !can(regex("\\.\\.", var.bucket_name))
    error_message = "Bucket name cannot contain consecutive dots."
  }

  # Not IP-like
  validation {
    condition     = !can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", var.bucket_name))
    error_message = "Bucket name cannot be formatted as an IP address."
  }
}
```

### Object Validation

```hcl
variable "server_config" {
  type = object({
    name          = string
    instance_type = string
    volume_size   = number
    environment   = string
  })

  validation {
    condition     = contains(["t2.micro", "t2.small", "t2.medium", "t3.micro", "t3.small", "t3.medium"], var.server_config.instance_type)
    error_message = "Instance type must be a valid t2 or t3 instance type."
  }

  validation {
    condition     = var.server_config.volume_size >= 8 && var.server_config.volume_size <= 16384
    error_message = "Volume size must be between 8 and 16384 GB."
  }

  validation {
    condition = (
      var.server_config.environment == "prod" ?
      var.server_config.volume_size >= 100 :
      true
    )
    error_message = "Production servers must have at least 100 GB volume."
  }
}
```

### List/Map Validation

```hcl
variable "ports" {
  type        = list(number)
  description = "List of ports to open"

  validation {
    condition     = length(var.ports) > 0
    error_message = "At least one port must be specified."
  }

  validation {
    condition     = alltrue([for p in var.ports : p >= 1 && p <= 65535])
    error_message = "All ports must be valid (1-65535)."
  }

  validation {
    condition     = length(var.ports) == length(distinct(var.ports))
    error_message = "Ports cannot contain duplicates."
  }
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"

  validation {
    condition     = lookup(var.tags, "Environment", null) != null
    error_message = "Tags must include 'Environment' key."
  }

  validation {
    condition     = alltrue([for k, v in var.tags : length(k) <= 128 && length(v) <= 256])
    error_message = "Tag keys max 128 chars, values max 256 chars."
  }
}
```

---

## Part 3: Variable Sources & Precedence

### Precedence Order (Highest to Lowest)

1. `-var` and `-var-file` command line
2. `*.auto.tfvars` / `*.auto.tfvars.json` (alphabetical)
3. `terraform.tfvars.json`
4. `terraform.tfvars`
5. Environment variables (`TF_VAR_name`)
6. Default values

### terraform.tfvars

```hcl
# terraform.tfvars
environment    = "dev"
instance_count = 2
project_name   = "myproject"

database_config = {
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"
  storage_size   = 20
  multi_az       = false
}
```

### Environment-Specific Files

```hcl
# dev.tfvars
environment    = "dev"
instance_count = 1
instance_types = {
  web = "t2.micro"
  api = "t2.micro"
}

# prod.tfvars
environment    = "prod"
instance_count = 3
instance_types = {
  web = "t2.medium"
  api = "t2.medium"
}
```

```bash
# Apply with specific environment
terraform apply -var-file="prod.tfvars"
```

### Environment Variables

```bash
# Set variable via environment
export TF_VAR_environment="staging"
export TF_VAR_instance_count=3
export TF_VAR_database_password="supersecret"

terraform apply
```

### Command Line Override

```bash
# Override specific variables
terraform apply \
  -var="environment=prod" \
  -var="instance_count=5" \
  -var-file="common.tfvars"
```

---

## Part 4: Sensitive Variables

```hcl
variable "database_password" {
  type        = string
  description = "Database master password"
  sensitive   = true

  validation {
    condition     = length(var.database_password) >= 16
    error_message = "Password must be at least 16 characters."
  }

  validation {
    condition     = can(regex("[A-Z]", var.database_password)) && can(regex("[a-z]", var.database_password)) && can(regex("[0-9]", var.database_password))
    error_message = "Password must contain uppercase, lowercase, and numbers."
  }
}

variable "api_keys" {
  type        = map(string)
  description = "API keys for various services"
  sensitive   = true
}

# Usage
resource "aws_db_instance" "main" {
  identifier     = "production"
  engine         = "postgres"
  instance_class = "db.t3.micro"
  username       = "admin"
  password       = var.database_password  # Value hidden in output

  # ...
}
```

### Output with Sensitive Values

```hcl
output "database_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "database_password" {
  value     = var.database_password
  sensitive = true  # Required when outputting sensitive values
}
```

---

## Part 5: Local Values

### Basic Locals

```hcl
locals {
  # Simple values
  environment = var.environment
  region      = "us-east-1"

  # Computed values
  name_prefix = "${var.project_name}-${local.environment}"

  # Common tags
  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web"
    Role = "web"
  })
}
```

### Complex Locals

```hcl
locals {
  # Conditional logic
  is_production = var.environment == "prod"

  # Instance sizing based on environment
  instance_config = {
    dev = {
      instance_type  = "t2.micro"
      volume_size    = 20
      instance_count = 1
    }
    staging = {
      instance_type  = "t2.small"
      volume_size    = 50
      instance_count = 2
    }
    prod = {
      instance_type  = "t2.medium"
      volume_size    = 100
      instance_count = 3
    }
  }

  # Current environment config
  current_config = local.instance_config[var.environment]

  # Flatten complex structures
  subnet_config = flatten([
    for az_index, az in var.availability_zones : [
      {
        az         = az
        public_cidr  = cidrsubnet(var.vpc_cidr, 8, az_index)
        private_cidr = cidrsubnet(var.vpc_cidr, 8, az_index + 100)
      }
    ]
  ])

  # Map transformation
  instance_map = {
    for i in range(local.current_config.instance_count) :
    "${local.name_prefix}-${i + 1}" => {
      index         = i
      instance_type = local.current_config.instance_type
      az            = var.availability_zones[i % length(var.availability_zones)]
    }
  }
}
```

---

## Part 6: Output Values

### Basic Outputs

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "instance_public_ips" {
  description = "Public IPs of all instances"
  value       = aws_instance.web[*].public_ip
}
```

### Conditional Outputs

```hcl
output "load_balancer_dns" {
  description = "DNS name of the load balancer (if created)"
  value       = var.create_lb ? aws_lb.main[0].dns_name : null
}
```

### Complex Output Structures

```hcl
output "instance_details" {
  description = "Details of all created instances"
  value = {
    for name, instance in aws_instance.servers : name => {
      id         = instance.id
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
      az         = instance.availability_zone
      tags       = instance.tags
    }
  }
}

output "infrastructure_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    vpc = {
      id   = aws_vpc.main.id
      cidr = aws_vpc.main.cidr_block
    }
    subnets = {
      public  = [for s in aws_subnet.public : s.id]
      private = [for s in aws_subnet.private : s.id]
    }
    instances = {
      count = length(aws_instance.web)
      ids   = aws_instance.web[*].id
    }
  }
}
```

### Output Dependencies

```hcl
output "database_connection_string" {
  description = "Database connection string"
  value       = "postgresql://${aws_db_instance.main.username}:PASSWORD@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = true

  # Ensure database is ready before outputting
  depends_on = [aws_db_instance.main]
}
```

---

## Exercise: Variable-Driven Multi-Environment Setup

Create a configuration that uses variables to deploy different infrastructure per environment:

### Requirements

1. Variables for:
   - Environment (dev/staging/prod) with validation
   - Instance configuration per environment
   - Enable/disable features (monitoring, backups)
   - Tags

2. Locals for:
   - Computed names
   - Environment-specific settings
   - Common tags

3. Outputs for:
   - All resource IDs
   - Connection strings
   - Summary

### Starter Template

```hcl
# variables.tf
variable "environment" {
  type = string
  # Add validation
}

variable "config" {
  type = object({
    instance_type  = string
    instance_count = number
    enable_backups = bool
  })
  # Add validation
}

# locals.tf
locals {
  # Compute name prefix
  # Determine environment settings
  # Build common tags
}

# outputs.tf
output "summary" {
  # Output comprehensive summary
}
```

---

## Checkpoint

Before moving to Lab 2.4, verify you can:

- [ ] Define all variable types correctly
- [ ] Write validation rules for complex requirements
- [ ] Use variable precedence effectively
- [ ] Handle sensitive variables properly
- [ ] Create computed local values
- [ ] Design informative outputs

---

## Next: Lab 2.4 - State Management Mastery

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Variable Types & Constraints
- Variable Validation
- Variable Sources & Precedence
- Sensitive Variables

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
