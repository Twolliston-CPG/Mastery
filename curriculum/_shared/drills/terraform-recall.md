# Terraform Recall Drill

> Weeks 10–26. Write each from a blank file. No autocomplete, no copy-paste.

## Tier 1 — Structural recall (write from blank, 5 min)

```hcl
terraform {
  required_version = "~> 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.68" }
  }
  backend "s3" {
    bucket       = "tfstate-<acct>-us-east-1"
    key          = "alpha/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true      # S3 native locking (TF >= 1.10); else dynamodb_table
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = local.common_tags }
}
```

## Tier 2 — Variables, validation, outputs

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "subnets" {
  description = "Map of subnet name => CIDR"
  type        = map(string)
  default     = {}
}

variable "instance" {
  type = object({
    type     = string
    count    = number
    monitor  = optional(bool, true)
  })
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.this.id
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true       # hides from CLI output -- does NOT encrypt state
}
```

## Tier 3 — Meta-arguments (the interview material)

```hcl
# for_each over a map -- STABLE keys, safe to add/remove
resource "aws_subnet" "this" {
  for_each          = var.subnets
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = "${var.region}${each.key}"
  tags              = { Name = "subnet-${each.key}" }
}

# for_each over a set
resource "aws_iam_user" "this" {
  for_each = toset(["alice", "bob"])
  name     = each.key
}

# count -- only for "N identical" or conditional creation
resource "aws_nat_gateway" "this" {
  count = var.enable_nat ? 1 : 0
}

# dynamic block
resource "aws_security_group" "web" {
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidrs
    }
  }
}

# lifecycle
resource "aws_db_instance" "main" {
  lifecycle {
    prevent_destroy       = true
    create_before_destroy = true
    ignore_changes        = [tags["LastModified"], password]
  }
}

# moved -- refactor without destroying
moved {
  from = aws_instance.web
  to   = module.compute.aws_instance.web
}
```

## Tier 4 — Expressions

```hcl
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project
  }

  # map comprehension
  subnet_ids = { for k, s in aws_subnet.this : k => s.id }

  # list comprehension with filter
  public_subnets = [for k, v in var.subnets : v if startswith(k, "public")]

  # flatten nested loops
  rules = flatten([
    for sg, cfg in var.sgs : [
      for port in cfg.ports : { sg = sg, port = port }
    ]
  ])

  # conditional
  instance_type = var.environment == "prod" ? "m5.large" : "t3.micro"

  # generate subnet CIDRs from a VPC CIDR
  azs     = slice(data.aws_availability_zones.available.names, 0, 3)
  subnets = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 4, i) }
}
```

`cidrsubnet("10.0.0.0/16", 4, 2)` → `10.0.32.0/20`. Be able to explain: add 4 bits to the /16 → /20,
take the 2nd (zero-indexed) block. **This appears on the Terraform Associate exam.**

## Tier 5 — CLI recall

| Task | Command |
|---|---|
| Init with a different backend config | `terraform init -backend-config=prod.hcl` |
| Migrate state to a new backend | `terraform init -migrate-state` |
| Re-download providers | `terraform init -upgrade` |
| Plan into a file | `terraform plan -out=tf.plan` |
| Apply a saved plan | `terraform apply tf.plan` |
| Target one resource (escape hatch) | `terraform apply -target=module.net` |
| Show drift only | `terraform plan -refresh-only` |
| Accept drift into state | `terraform apply -refresh-only` |
| Import existing infra | `terraform import aws_vpc.this vpc-0abc123` |
| Import block (TF ≥1.5, plannable) | `import { to = aws_vpc.this \n id = "vpc-0abc" }` |
| Rename in state | `terraform state mv aws_x.a aws_x.b` |
| Stop managing without destroying | `terraform state rm aws_x.a` |
| Force replacement | `terraform apply -replace=aws_instance.web` |
| Unlock a stuck state | `terraform force-unlock <LOCK_ID>` |
| Lock providers for CI platforms | `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64` |
| Read an output for scripting | `terraform output -raw vpc_id` |
| Machine-readable state | `terraform show -json \| jq` |

## Tier 6 — The questions you will be asked

1. **`count` vs `for_each`?** → `for_each` uses stable string keys, so removing a middle element
   destroys only that element. `count` uses positional indexes, so removal shifts everything after
   it. Use `for_each` unless you literally want N identical things or a 0/1 conditional.
2. **What's in state and why does it matter?** → A JSON map of configuration to real resource IDs,
   plus metadata and dependency order. It is **plaintext**, including secrets. It must be remote,
   encrypted, versioned, and locked.
3. **Two engineers apply at once?** → State locking makes one fail rather than corrupt. In CI, use a
   `concurrency` group with `cancel-in-progress: false`.
4. **How do you handle secrets?** → Don't put them in Terraform where avoidable. Reference Secrets
   Manager, or let the provider generate them (`manage_master_user_password`). Encrypt the backend.
   `sensitive = true` is a display flag, not encryption.
5. **Workspaces vs directories?** → Workspaces share one backend and one configuration — good for
   ephemeral/identical copies. Directories give separate state, separate backends, and allow prod to
   genuinely differ from dev. **For real environments, directories.**
6. **How do you bring existing infrastructure under management?** → `import` block (plannable since
   1.5) or `terraform import`, then write config to match, then plan until empty.
7. **Module versioning?** → Pin by git tag or registry version. Never track a branch — your CI will
   change behavior without a commit.
