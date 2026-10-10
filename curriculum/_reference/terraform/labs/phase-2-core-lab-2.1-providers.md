# Lab 2.1: Providers Deep Dive

## Objective

Master Terraform provider configuration including versioning, aliases, authentication, and multi-provider setups.

## Duration: 60 minutes

---

## Part 1: Provider Architecture

Terraform uses a plugin-based architecture where providers are separate binaries.

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Part 1: Provider Architecture — diagram](../../../../_figures/curriculum-_reference-terraform-labs-phase-2-core-lab-2.1-providers-0-a5237e9b.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  subgraph CORE["Terraform core"]
    direction TB
    P["Configuration parser<br/><small>HCL → a graph</small>"]:::n
    G["Dependency graph<br/><small>built from references, not declaration order</small>"]:::crit
    PI["Provider plugin interface<br/><small>gRPC, over a local socket</small>"]:::n
    P --> G --> PI
  end
  subgraph PROV["Providers · separate binaries"]
    direction LR
    A["aws"]:::n
    K["kubernetes"]:::n
    H["helm"]:::n
  end
  API["Target APIs"]:::data
  ST[("State<br/><small>config address → real resource ID</small>")]:::data

  PI --> PROV --> API
  CORE -.-> ST

  linkStyle 1,3,4 stroke:#2f6fb8,stroke-width:2px
```

</details>

---

## Part 2: Provider Version Constraints

```bash
mkdir -p ~/terraform-learning/labs/providers-lab
cd ~/terraform-learning/labs/providers-lab
```

### Version Constraint Syntax

```hcl
# versions.tf
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    # Exact version
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }

    # Minimum version
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }

    # Pessimistic constraint (allows 5.31.x)
    # Also called "tilde constraint"
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }

    # Range constraint
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0, < 5.0.0"
    }

    # Multiple constraints
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0, != 2.5.0, < 3.0.0"
    }
  }
}
```

### Understanding Version Constraints

| Operator | Meaning | Example |
|----------|---------|---------|
| `=` or none | Exact version | `5.31.0` |
| `!=` | Exclude version | `!= 2.5.0` |
| `>`, `>=`, `<`, `<=` | Comparison | `>= 3.0.0` |
| `~>` | Pessimistic (minor) | `~> 5.0` allows 5.x.x |
| `~>` | Pessimistic (patch) | `~> 5.0.0` allows 5.0.x |

### Lock File

```bash
# Initialize to create lock file
terraform init

# View lock file
cat .terraform.lock.hcl
```

The lock file records:
- Exact provider versions installed
- Platform-specific hashes
- Integrity checksums

```hcl
# .terraform.lock.hcl (example)
provider "registry.terraform.io/hashicorp/aws" {
  version     = "5.31.0"
  constraints = "5.31.0"
  hashes = [
    "h1:xxxxxxx...",
    "zh:xxxxxxx...",
  ]
}
```

### Upgrade Providers

```bash
# Upgrade to latest compatible version
terraform init -upgrade

# View available versions
terraform providers
```

---

## Part 3: Provider Configuration

### Basic Configuration

```hcl
# providers.tf
provider "aws" {
  region = "us-east-1"

  # Default tags for all resources
  default_tags {
    tags = {
      Environment = "learning"
      ManagedBy   = "Terraform"
      Project     = "providers-lab"
    }
  }
}
```

### Authentication Methods

```hcl
# Method 1: Static credentials (NOT RECOMMENDED for production)
provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# Method 2: Environment variables (RECOMMENDED)
# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
provider "aws" {
  region = "us-east-1"
}

# Method 3: Shared credentials file
provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "terraform"
}

# Method 4: IAM Role (for EC2/ECS)
provider "aws" {
  region = "us-east-1"
  # Automatically uses instance profile
}

# Method 5: Assume Role
provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::ACCOUNT_ID:role/TerraformRole"
    session_name = "TerraformSession"
    external_id  = "EXTERNAL_ID"
  }
}
```

---

## Part 4: Provider Aliases (Multi-Region)

### Create Multi-Region Configuration

```hcl
# providers.tf

# Default provider (us-east-1)
provider "aws" {
  region = "us-east-1"
  alias  = "east"

  default_tags {
    tags = {
      Region = "us-east-1"
    }
  }
}

# Secondary provider (us-west-2)
provider "aws" {
  region = "us-west-2"
  alias  = "west"

  default_tags {
    tags = {
      Region = "us-west-2"
    }
  }
}

# EU provider
provider "aws" {
  region = "eu-west-1"
  alias  = "europe"

  default_tags {
    tags = {
      Region = "eu-west-1"
    }
  }
}
```

### Using Provider Aliases

```hcl
# main.tf

# Create S3 buckets in multiple regions
resource "aws_s3_bucket" "east_bucket" {
  provider = aws.east
  bucket   = "my-app-data-us-east-1-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "west_bucket" {
  provider = aws.west
  bucket   = "my-app-data-us-west-2-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "eu_bucket" {
  provider = aws.europe
  bucket   = "my-app-data-eu-west-1-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}
```

### Multi-Region VPC Example

```hcl
# multi-region-vpc.tf

# VPC in US East
resource "aws_vpc" "east" {
  provider   = aws.east
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "vpc-us-east-1"
  }
}

# VPC in US West
resource "aws_vpc" "west" {
  provider   = aws.west
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "vpc-us-west-2"
  }
}

# VPC in EU
resource "aws_vpc" "europe" {
  provider   = aws.europe
  cidr_block = "10.2.0.0/16"

  tags = {
    Name = "vpc-eu-west-1"
  }
}

# Cross-region outputs
output "vpc_ids" {
  value = {
    east   = aws_vpc.east.id
    west   = aws_vpc.west.id
    europe = aws_vpc.europe.id
  }
}
```

---

## Part 5: Multi-Cloud Configuration

```hcl
# versions.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Azure Provider
provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
}

# Google Cloud Provider
provider "google" {
  project = var.gcp_project_id
  region  = "us-central1"
}
```

### Multi-Cloud Resources

```hcl
# multi-cloud.tf

# AWS S3 Bucket
resource "aws_s3_bucket" "data" {
  bucket = "multi-cloud-demo-aws-${random_id.suffix.hex}"

  tags = {
    Cloud = "AWS"
  }
}

# Azure Storage Account
resource "azurerm_resource_group" "main" {
  name     = "multi-cloud-demo-rg"
  location = "East US"
}

resource "azurerm_storage_account" "data" {
  name                     = "multiclouddemosa${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Cloud = "Azure"
  }
}

# Google Cloud Storage Bucket
resource "google_storage_bucket" "data" {
  name          = "multi-cloud-demo-gcs-${random_id.suffix.hex}"
  location      = "US"
  force_destroy = true

  labels = {
    cloud = "gcp"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

output "storage_endpoints" {
  value = {
    aws   = aws_s3_bucket.data.bucket_regional_domain_name
    azure = azurerm_storage_account.data.primary_blob_endpoint
    gcp   = google_storage_bucket.data.url
  }
}
```

---

## Part 6: Provider Configuration in Modules

### Passing Providers to Modules

```hcl
# Root module - main.tf
provider "aws" {
  region = "us-east-1"
  alias  = "primary"
}

provider "aws" {
  region = "us-west-2"
  alias  = "secondary"
}

module "primary_vpc" {
  source = "./modules/vpc"

  providers = {
    aws = aws.primary
  }

  vpc_cidr = "10.0.0.0/16"
  name     = "primary-vpc"
}

module "secondary_vpc" {
  source = "./modules/vpc"

  providers = {
    aws = aws.secondary
  }

  vpc_cidr = "10.1.0.0/16"
  name     = "secondary-vpc"
}
```

```hcl
# modules/vpc/main.tf

# Module declares required provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "vpc_cidr" {
  type = string
}

variable "name" {
  type = string
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.name
  }
}

output "vpc_id" {
  value = aws_vpc.main.id
}
```

---

## Part 7: Troubleshooting Providers

### Common Issues

#### Issue 1: Provider Not Found

```bash
Error: Failed to query available provider packages

Could not retrieve the list of available versions for provider
hashicorp/aws: no available releases match the given constraints
```

**Solution:**

```bash
# Check provider source
terraform providers

# Clear cache and reinitialize
rm -rf .terraform
terraform init
```

#### Issue 2: Authentication Failure

```bash
Error: error configuring Terraform AWS Provider: no valid credential sources found
```

**Solution:**

```bash
# Check credentials
aws sts get-caller-identity

# Set environment variables
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="us-east-1"
```

#### Issue 3: Version Conflict

```bash
Error: Failed to query available provider packages

Could not retrieve the list of available versions for provider
hashicorp/aws: no available releases match the given constraints ~> 4.0, 5.31.0
```

**Solution:**

```bash
# Check for conflicting constraints in modules
terraform providers

# Update constraints to be compatible
# Or upgrade providers
terraform init -upgrade
```

### Debug Logging

```bash
# Enable provider logging
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log

terraform init
terraform plan

# View logs
cat terraform.log | grep "provider"
```

---

## Exercise: Multi-Region Disaster Recovery

### Requirements

Create a multi-region setup with:

1. Primary region: us-east-1
   - VPC with public subnet
   - S3 bucket for data

2. DR region: us-west-2
   - VPC with public subnet
   - S3 bucket with replication from primary

3. Global resources:
   - Route 53 hosted zone
   - CloudFront distribution

### Starter Code

```hcl
# versions.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# providers.tf
provider "aws" {
  region = "us-east-1"
  alias  = "primary"
}

provider "aws" {
  region = "us-west-2"
  alias  = "dr"
}

# TODO: Create VPCs in both regions
# TODO: Create S3 buckets with cross-region replication
# TODO: Configure proper IAM roles for replication
```

---

## Checkpoint

Before moving to Lab 2.2, verify you can:

- [ ] Configure provider version constraints
- [ ] Use provider aliases for multi-region
- [ ] Configure authentication securely
- [ ] Pass providers to modules
- [ ] Troubleshoot common provider issues

---

## Next: Lab 2.2 - Resources & Meta-Arguments

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Provider Architecture
- Provider Version Constraints
- Provider Configuration
- Provider Aliases (Multi-Region)

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
