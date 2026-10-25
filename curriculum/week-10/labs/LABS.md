# Week 10 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (10.2 to 10.5). Read a lab's figure
> before you start it; redraw it after.

---

# Lab 1 — HCL Fundamentals (3h)

## Part 1 — Your first configuration

```bash
mkdir -p ~/tf-lab/01-basics && cd ~/tf-lab/01-basics
```

```hcl
# versions.tf
terraform {
  required_version = "~> 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "tf-lab"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
```

```hcl
# variables.tf
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
```

```hcl
# main.tf
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "web" {
  name_prefix = "tf-lab-web-"
  description = "Lab web SG"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from anywhere"
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

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]

  metadata_options {
    http_tokens                 = "required"   # IMDSv2
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOT
    #!/bin/bash
    dnf install -y nginx
    systemctl enable --now nginx
    echo "<h1>$(hostname -f)</h1>" > /usr/share/nginx/html/index.html
  EOT

  tags = { Name = "tf-lab-web" }
}
```

```hcl
# outputs.tf
output "public_ip" {
  description = "Public IP of the web instance"
  value       = aws_instance.web.public_ip
}

output "instance_id" {
  value = aws_instance.web.id
}
```

## Tasks
```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
curl "http://$(terraform output -raw public_ip)"
terraform destroy
```

1. Run the full cycle **three times** until `init/plan/apply/destroy` is muscle memory
2. Try `terraform apply` with `environment = "production"` — the validation rejects it. Read the error.
3. Change `instance_type` and read the plan. Does it say `~` (update) or `-/+` (replace)? Why?
4. Remove the `data.aws_ami` block and hardcode an AMI ID. Then try it in another region and watch it
   fail — this is why you use a data source.
5. Add `depends_on` somewhere it isn't needed and explain why the **implicit** dependency
   (`aws_security_group.web.id` referenced inside `aws_instance.web`) was already sufficient.

## Part 2 — Read the graph
```bash
terraform graph | dot -Tpng -o graph.png   # needs graphviz
terraform show -json | jq '.values.root_module.resources[].address'
terraform state list
terraform state show aws_instance.web
```

**Terraform builds a DAG from references.** `aws_security_group.web.id` inside the instance creates
the edge. `depends_on` is the escape hatch for dependencies Terraform can't see — usually IAM policy
propagation or something outside Terraform entirely.

---

# Lab 2 — State (3h)

## Part 1 — Look at it

```bash
cd ~/tf-lab/01-basics
terraform apply -auto-approve
cat terraform.tfstate | jq '.resources[] | {type, name, instances: [.instances[].attributes.id]}'
cat terraform.tfstate | jq '.serial, .lineage, .terraform_version'
```

**What's in state:** every resource's full attribute set, the mapping from config address to real
resource ID, the dependency graph, a serial number (incremented on every write), and a lineage UUID.

**Everything is plaintext.** Create an RDS instance with a `random_password` and grep the state for
it — you will find it. (BF-36)

## Part 2 — Remote backend with locking

```bash
# Bootstrap the backend (this part is chicken-and-egg -- do it with the CLI)
ACCT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="tfstate-${ACCT}-us-east-1"

aws s3api create-bucket --bucket "$BUCKET" --region us-east-1
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket       = "tfstate-REPLACE-us-east-1"
    key          = "tf-lab/basics/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true    # S3 native locking (TF >= 1.10). Older: dynamodb_table = "..."
  }
}
```

```bash
terraform init -migrate-state
aws s3 ls "s3://$BUCKET/tf-lab/basics/"
rm terraform.tfstate*      # local copy no longer authoritative
terraform plan             # still works -- reads from S3
```

**Versioning on the state bucket is the single most important setting.** It is your recovery path
when state is corrupted or deleted.

## Part 3 — Break it and recover

```bash
# 1. Corrupt the local cache
echo "garbage" > .terraform/terraform.tfstate
terraform plan              # observe the error
terraform init -reconfigure # recovers from remote

# 2. Simulate a stuck lock (BF-33)
terraform apply &
sleep 2 && kill -9 %1
terraform plan              # "Error acquiring the state lock"
terraform force-unlock <LOCK_ID>

# 3. Restore a previous state version
aws s3api list-object-versions --bucket "$BUCKET" \
  --prefix "tf-lab/basics/terraform.tfstate" \
  --query 'Versions[].{Id:VersionId,Modified:LastModified}' --output table
aws s3api get-object --bucket "$BUCKET" --key "tf-lab/basics/terraform.tfstate" \
  --version-id <OLD_VERSION> restored.tfstate
```

## Tasks
1. Migrate to the remote backend
2. Reproduce and resolve the stuck lock (BF-33)
3. **Prove the lock works:** run `terraform plan` in two terminals simultaneously and watch one wait
4. Delete the state object entirely, then restore it from a version
5. Grep state for a secret and write down the remediation order (BF-36)

---

# Lab 3 — Import, State Manipulation, Drift (3h)

## Part 1 — Import

Create something in the console by hand — a VPC, a security group — then bring it under management.

```hcl
# import.tf  (Terraform >= 1.5: plannable import blocks)
import {
  to = aws_vpc.imported
  id = "vpc-0abc123def456"
}

resource "aws_vpc" "imported" {
  # write this to match reality
  cidr_block = "10.99.0.0/16"
}
```
```bash
terraform plan -generate-config-out=generated.tf   # Terraform writes the config for you
terraform plan     # iterate until the plan is EMPTY
terraform apply
```

**"Plan to empty" is the acceptance criterion.** Any remaining diff means your config doesn't match
reality, and applying it would change the real resource.

The older imperative form still works and is what you'll meet in most existing codebases:
```bash
terraform import aws_vpc.imported vpc-0abc123def456
```

**This is a real job skill.** Most companies have infrastructure that predates their IaC, and
"how would you bring existing infrastructure under Terraform?" is a common interview question.

## Part 2 — State manipulation

```bash
terraform state list
terraform state show aws_instance.web
terraform state mv aws_instance.web aws_instance.frontend    # rename
terraform state rm aws_instance.web                          # stop managing (does NOT destroy)
terraform state pull > backup.tfstate
terraform state push backup.tfstate                          # dangerous; know it exists
```

**The modern, reviewable alternative to `state mv`:**
```hcl
moved {
  from = aws_instance.web
  to   = module.compute.aws_instance.web
}
```
A `moved` block is **in your code**, shows up in the plan, and is reviewable in a PR. `state mv` is
an untracked local action. Prefer `moved` — and saying so in an interview is a good signal.

## Part 3 — Drift

```bash
# Change something in the console
aws ec2 create-tags --resources $(terraform output -raw instance_id) \
  --tags Key=ChangedBy,Value=console

terraform plan                  # shows the drift as a proposed change
terraform plan -refresh-only    # shows ONLY the drift, no config changes
terraform apply -refresh-only   # accept reality into state without changing infrastructure
```

**The decision — this is the interesting part:**
| Situation | Action |
|---|---|
| Emergency fix someone made under pressure | **Codify it.** Update Terraform to match. |
| Unauthorized or accidental | **Revert it.** `terraform apply` restores desired state. |
| Legitimately managed elsewhere | `lifecycle { ignore_changes = [...] }` |

Then find *who*:
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=$(terraform output -raw instance_id) \
  --max-results 5
```

## Part 4 — Break/Fix
**BF-33** (stuck state lock) · **BF-35** (unexpected destroy-and-recreate).

For BF-35, force it: change `availability_zone` on an instance, or `identifier` on an RDS instance,
and read which attribute Terraform marks `# forces replacement`.

---

# Lab 4 — ⚑ Project Alpha Kickoff (4h)

Full spec: [`../../../PROJECTS.md`](../../../PROJECTS.md) §2.
Reference implementation: [`../../projects/alpha-cloud-foundation/`](../../projects/alpha-cloud-foundation/)

## Today's scope

```bash
gh repo create alpha-cloud-foundation --public --clone
cd alpha-cloud-foundation
```

**`.`**

- `.github/workflows/` — (week 12)
- `docs/`
  - `architecture.md`
  - `adr/`
    - `0001-record-architecture-decisions.md`
- `modules/`
  - `network/` — ← TODAY
  - `compute/` — (week 11)
  - `database/` — (week 11)
  - `observability/` — (week 13)
- `environments/`
  - `dev/`
  - `prod/`
- `.gitignore`
- `.pre-commit-config.yaml`
- Makefile
- `README.md`


### Tasks for today
1. Repo created, structure scaffolded
2. `.gitignore` covering `*.tfstate*`, `.terraform/`, `*.tfvars` (but **commit**
   `terraform.tfvars.example`)
3. `.pre-commit-config.yaml` with `terraform_fmt`, `terraform_validate`, `tflint`, `gitleaks`,
   `detect-private-key`
4. Bootstrap the state backend (a separate `bootstrap/` directory, applied once, with its own local
   state — this is the standard solution to the chicken-and-egg problem)
5. Write the **`network` module**: VPC, public/private/data subnets across 2 AZs, IGW, NAT, route
   tables — using the CIDR plan from week 6's diagram
6. `environments/dev/` consuming it
7. `terraform apply` in dev; `curl` nothing yet, but the VPC exists
8. **`terraform destroy`** before you stop

### The .gitignore that matters
```gitignore
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfvars
!*.tfvars.example
crash.log
override.tf
.terraformrc
```
`*.tfstate` in `.gitignore` from commit one. A state file in git history is a credential leak that
follows the repo forever.
