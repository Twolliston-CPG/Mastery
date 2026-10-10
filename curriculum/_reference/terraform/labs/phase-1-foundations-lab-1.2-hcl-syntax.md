# Lab 1.2: HCL Syntax Deep Dive

## Objective

Master HashiCorp Configuration Language (HCL) syntax, including blocks, arguments, expressions, and formatting conventions.

## Duration: 45 minutes

---

## Part 1: Understanding HCL Structure

### Block Types

HCL uses blocks as the fundamental building unit. Each block has a type and may have labels.

```hcl
# Block structure:
# block_type "label1" "label2" {
#   argument = value
# }

# Terraform settings block (no labels)
terraform {
  required_version = ">= 1.0"
}

# Provider block (one label: provider name)
provider "aws" {
  region = "us-east-1"
}

# Resource block (two labels: type and name)
resource "aws_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}

# Variable block (one label: variable name)
variable "environment" {
  type    = string
  default = "development"
}

# Output block (one label: output name)
output "instance_ip" {
  value = aws_instance.web_server.public_ip
}

# Data block (two labels: type and name)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
}

# Locals block (no labels)
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Module block (one label: module name)
module "vpc" {
  source = "./modules/vpc"
}
```

---

## Part 2: Data Types

Create a file `types-practice.tf`:

```hcl
# STRING - Text values
variable "instance_name" {
  type        = string
  default     = "my-instance"
  description = "Name tag for the EC2 instance"
}

# NUMBER - Numeric values (integers and floats)
variable "instance_count" {
  type    = number
  default = 3
}

variable "cpu_threshold" {
  type    = number
  default = 75.5
}

# BOOL - Boolean values
variable "enable_monitoring" {
  type    = bool
  default = true
}

# LIST - Ordered collection of values
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "ports" {
  type    = list(number)
  default = [80, 443, 8080]
}

# SET - Unordered collection of unique values
variable "allowed_ips" {
  type    = set(string)
  default = ["10.0.0.1", "10.0.0.2", "10.0.0.3"]
}

# MAP - Key-value pairs
variable "instance_types" {
  type = map(string)
  default = {
    development = "t2.micro"
    staging     = "t2.small"
    production  = "t2.medium"
  }
}

# OBJECT - Structured type with named attributes
variable "server_config" {
  type = object({
    instance_type = string
    volume_size   = number
    encrypted     = bool
    tags          = map(string)
  })
  default = {
    instance_type = "t2.micro"
    volume_size   = 20
    encrypted     = true
    tags = {
      Name = "web-server"
    }
  }
}

# TUPLE - Fixed-length sequence with specific types
variable "server_tuple" {
  type    = tuple([string, number, bool])
  default = ["web-server", 8080, true]
}

# ANY - Accept any type
variable "flexible_input" {
  type    = any
  default = "can be anything"
}
```

---

## Part 3: Expressions and Operators

Create a file `expressions-practice.tf`:

```hcl
locals {
  # ARITHMETIC OPERATORS
  sum        = 5 + 3      # 8
  difference = 10 - 4     # 6
  product    = 3 * 4      # 12
  quotient   = 20 / 4     # 5
  remainder  = 17 % 5     # 2
  negative   = -5         # -5

  # COMPARISON OPERATORS
  equal         = 5 == 5   # true
  not_equal     = 5 != 3   # true
  less_than     = 3 < 5    # true
  greater_than  = 5 > 3    # true
  less_equal    = 3 <= 3   # true
  greater_equal = 5 >= 5   # true

  # LOGICAL OPERATORS
  and_result = true && false  # false
  or_result  = true || false  # true
  not_result = !true          # false

  # CONDITIONAL (TERNARY) EXPRESSION
  environment     = "production"
  instance_type   = local.environment == "production" ? "t2.large" : "t2.micro"
  enable_backups  = local.environment == "production" ? true : false

  # STRING INTERPOLATION
  region       = "us-east-1"
  account_id   = "123456789012"
  resource_arn = "arn:aws:ec2:${local.region}:${local.account_id}:instance/*"

  # HEREDOC - Multi-line strings
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "Hello from Terraform" > /var/www/html/index.html
  EOF

  # HEREDOC with interpolation disabled
  literal_script = <<-'EOF'
    #!/bin/bash
    echo "The variable is $HOME"
    echo "This ${is} literal"
  EOF
}

# Output examples
output "conditional_example" {
  value = local.instance_type
}

output "interpolation_example" {
  value = local.resource_arn
}
```

---

## Part 4: Collection Operations

Create a file `collections-practice.tf`:

```hcl
variable "servers" {
  type = list(string)
  default = ["web-1", "web-2", "web-3", "api-1", "api-2"]
}

variable "environments" {
  type = map(object({
    instance_type = string
    min_size      = number
    max_size      = number
  }))
  default = {
    dev = {
      instance_type = "t2.micro"
      min_size      = 1
      max_size      = 2
    }
    staging = {
      instance_type = "t2.small"
      min_size      = 2
      max_size      = 4
    }
    prod = {
      instance_type = "t2.medium"
      min_size      = 3
      max_size      = 10
    }
  }
}

locals {
  # FOR EXPRESSIONS

  # Transform list
  uppercase_servers = [for s in var.servers : upper(s)]
  # Result: ["WEB-1", "WEB-2", "WEB-3", "API-1", "API-2"]

  # Filter list
  web_servers = [for s in var.servers : s if startswith(s, "web")]
  # Result: ["web-1", "web-2", "web-3"]

  # Transform to map
  server_map = { for s in var.servers : s => upper(s) }
  # Result: {"web-1" = "WEB-1", "web-2" = "WEB-2", ...}

  # Map with index
  server_index = { for i, s in var.servers : s => i }
  # Result: {"web-1" = 0, "web-2" = 1, ...}

  # Iterate over map
  instance_types = [for env, config in var.environments : config.instance_type]
  # Result: ["t2.micro", "t2.small", "t2.medium"]

  # Filter map
  large_envs = { for env, config in var.environments : env => config if config.max_size > 5 }
  # Result: {"prod" = {...}}

  # SPLAT EXPRESSIONS
  # Equivalent to [for o in var.list : o.attribute]
  # server_names = aws_instance.servers[*].tags.Name

  # COLLECTION FUNCTIONS
  list1  = ["a", "b"]
  list2  = ["c", "d"]
  merged = concat(local.list1, local.list2)  # ["a", "b", "c", "d"]

  flat_list = flatten([["a", "b"], ["c", "d"]])  # ["a", "b", "c", "d"]

  first_server = element(var.servers, 0)  # "web-1"

  server_count = length(var.servers)  # 5

  has_web = contains(var.servers, "web-1")  # true

  sorted = sort(var.servers)  # Alphabetically sorted

  unique_list = distinct(["a", "b", "a", "c"])  # ["a", "b", "c"]

  chunked = chunklist(var.servers, 2)  # [["web-1", "web-2"], ["web-3", "api-1"], ["api-2"]]

  map1 = { a = 1, b = 2 }
  map2 = { c = 3, d = 4 }
  merged_map = merge(local.map1, local.map2)  # { a = 1, b = 2, c = 3, d = 4 }

  keys_only   = keys(local.map1)    # ["a", "b"]
  values_only = values(local.map1)  # [1, 2]

  lookup_result = lookup(local.map1, "a", "default")  # 1
  lookup_missing = lookup(local.map1, "z", "default")  # "default"
}

output "for_expression_results" {
  value = {
    uppercase     = local.uppercase_servers
    filtered      = local.web_servers
    as_map        = local.server_map
    instance_types = local.instance_types
  }
}
```

---

## Part 5: String Functions

Create a file `strings-practice.tf`:

```hcl
locals {
  # STRING MANIPULATION

  original = "  Hello, Terraform World!  "

  # Trimming
  trimmed       = trim(local.original, " ")        # "Hello, Terraform World!"
  trimmed_space = trimspace(local.original)        # "Hello, Terraform World!"
  trim_prefix   = trimprefix("HelloWorld", "Hello") # "World"
  trim_suffix   = trimsuffix("HelloWorld", "World") # "Hello"

  # Case transformation
  upper_case = upper("hello")  # "HELLO"
  lower_case = lower("HELLO")  # "hello"
  title_case = title("hello world")  # "Hello World"

  # Splitting and joining
  parts      = split(",", "a,b,c,d")        # ["a", "b", "c", "d"]
  joined     = join("-", ["a", "b", "c"])   # "a-b-c"

  # Replacement
  replaced = replace("hello world", "world", "terraform")  # "hello terraform"
  regex_replaced = replace("hello-123-world", "/[0-9]+/", "XXX")  # "hello-XXX-world"

  # Substring
  sub = substr("Hello World", 0, 5)  # "Hello"

  # Formatting
  formatted = format("Hello, %s! You have %d messages.", "User", 5)
  # "Hello, User! You have 5 messages."

  formatted_list = formatlist("server-%s", ["web", "api", "db"])
  # ["server-web", "server-api", "server-db"]

  # Regex
  matched = regex("^[a-z]+", "hello123")  # "hello"
  all_matches = regexall("[a-z]+", "hello123world")  # ["hello", "world"]
  can_match = can(regex("^[0-9]+$", "hello"))  # false

  # Encoding
  base64_encoded = base64encode("Hello World")  # "SGVsbG8gV29ybGQ="
  base64_decoded = base64decode("SGVsbG8gV29ybGQ=")  # "Hello World"

  json_encoded = jsonencode({
    name = "test"
    value = 123
  })  # '{"name":"test","value":123}'

  url_encoded = urlencode("hello world")  # "hello%20world"

  # Indentation (useful for YAML/JSON embedding)
  yaml_content = <<-EOF
    apiVersion: v1
    kind: ConfigMap
  EOF

  indented = indent(4, local.yaml_content)
}

output "string_examples" {
  value = {
    trimmed    = local.trimmed
    formatted  = local.formatted
    split      = local.parts
    replaced   = local.replaced
  }
}
```

---

## Part 6: Formatting Standards

### terraform fmt

Always format your code:

```bash
# Format current directory
terraform fmt

# Format recursively
terraform fmt -recursive

# Check if files are formatted (useful for CI)
terraform fmt -check

# Show diff of formatting changes
terraform fmt -diff
```

### Style Guidelines

```hcl
# GOOD: Consistent alignment
resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name        = "example"
    Environment = "development"
  }
}

# GOOD: One blank line between blocks
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}

resource "aws_instance" "api" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.small"
}

# GOOD: Group related arguments
resource "aws_instance" "complete" {
  # Required arguments first
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  # Optional arguments grouped logically
  key_name               = "my-key"
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = aws_subnet.public.id

  # Nested blocks last
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "example"
  }
}
```

---

## Exercise: HCL Practice

Create a complete configuration that demonstrates your understanding:

### Requirements

1. Create `main.tf` with:
   - Terraform settings block with AWS provider version constraint
   - AWS provider configuration

2. Create `variables.tf` with:
   - A string variable for environment
   - A number variable for instance count
   - A bool variable for enable_monitoring
   - A list variable for availability zones
   - A map variable for instance types per environment
   - An object variable for server configuration

3. Create `locals.tf` with:
   - Conditional expression for instance type based on environment
   - For expression to generate server names
   - String interpolation for resource naming
   - Merged tags combining common and environment-specific

4. Create `outputs.tf` with:
   - Outputs demonstrating different value types

### Validation

```bash
terraform init
terraform validate
terraform fmt -check
```

---

## Solution

<details>
<summary>Click to reveal solution</summary>

```hcl
# main.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

```hcl
# variables.tf
variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "instance_count" {
  type        = number
  description = "Number of instances to create"
  default     = 2

  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "enable_monitoring" {
  type        = bool
  description = "Enable detailed monitoring"
  default     = false
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "instance_types" {
  type        = map(string)
  description = "Instance type per environment"
  default = {
    development = "t2.micro"
    staging     = "t2.small"
    production  = "t2.medium"
  }
}

variable "server_config" {
  type = object({
    root_volume_size = number
    encrypted        = bool
    backup_retention = number
  })
  default = {
    root_volume_size = 20
    encrypted        = true
    backup_retention = 7
  }
}
```

```hcl
# locals.tf
locals {
  # Conditional instance type
  instance_type = var.instance_types[var.environment]

  # Generate server names
  server_names = [for i in range(var.instance_count) : format("%s-server-%02d", var.environment, i + 1)]

  # Resource naming
  name_prefix = "${var.environment}-app"

  # Common tags
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "terraform-learning"
  }

  # Environment-specific tags
  env_tags = var.environment == "production" ? {
    Critical = "true"
    Backup   = "enabled"
  } : {}

  # Merged tags
  all_tags = merge(local.common_tags, local.env_tags)

  # AZ distribution
  az_distribution = { for i, name in local.server_names : name => var.availability_zones[i % length(var.availability_zones)] }
}
```

```hcl
# outputs.tf
output "instance_type_selected" {
  description = "The instance type for this environment"
  value       = local.instance_type
}

output "server_names" {
  description = "Generated server names"
  value       = local.server_names
}

output "az_distribution" {
  description = "Server to AZ mapping"
  value       = local.az_distribution
}

output "all_tags" {
  description = "Complete tag set"
  value       = local.all_tags
}

output "server_config" {
  description = "Server configuration object"
  value       = var.server_config
}
```

</details>

---

## Next: Lab 1.3 - Core Workflow Mastery

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Understanding HCL Structure
- Data Types
- Expressions and Operators
- Collection Operations

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
