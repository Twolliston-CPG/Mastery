# Lab 5.1: HCP Terraform (Terraform Cloud)

## Objective

Master HCP Terraform for enterprise collaboration and governance.

## Duration: 90 minutes

---

## Part 1: HCP Terraform Overview

**What HCP Terraform adds over local state**

| | What it gives you | What you would otherwise build |
|---|---|---|
| **Workspaces** | One state, one variable set, one run history per environment | S3 key conventions plus discipline |
| **VCS integration** | A plan on every pull request, automatically | A GitHub Actions workflow per repo |
| **Remote runs** | Applies execute on HashiCorp's workers, not a laptop | A CI runner with cloud credentials |
| **State management** | Versioned, locked, encrypted, with a diff viewer | S3 + DynamoDB + `state pull` and squinting |
| **Policy and governance** | Sentinel or OPA evaluated between plan and apply | Conftest in CI, and a way to stop a local apply |
| **Private registry** | Versioned internal modules with documentation | A Git tag convention and a wiki page |
| **Teams and RBAC** | Who may plan, who may apply, per workspace | IAM plus a review culture |
| **Run tasks** | Third-party checks (cost, security) as a gate on the run | More CI steps |
| **Cost estimation** | The dollar delta shown next to the resource delta | Infracost wired in by hand |

Every row is buildable yourself — that is the real decision. You are paying to not own nine small
pieces of infrastructure whose failure mode is *"nobody can deploy today."*

---

## Part 2: Backend Configuration

### HCP Terraform Backend

```hcl
# versions.tf
terraform {
  cloud {
    organization = "my-organization"

    workspaces {
      name = "my-workspace"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### Dynamic Workspace Selection

```hcl
terraform {
  cloud {
    organization = "my-organization"

    workspaces {
      tags = ["app:web", "env:production"]
    }
  }
}
```

### Login and Initialize

```bash
# Login to HCP Terraform
terraform login

# Initialize with cloud backend
terraform init

# Select workspace (if multiple match)
terraform workspace select production
```

---

## Part 3: Workspace Configuration

### Workspace Variables

```hcl
# Using tfe provider to manage workspaces
provider "tfe" {
  hostname = "app.terraform.io"
  token    = var.tfe_token
}

resource "tfe_workspace" "app" {
  name         = "app-production"
  organization = "my-organization"

  # Execution mode
  execution_mode = "remote"

  # Auto-apply settings
  auto_apply = false
  queue_all_runs = true

  # VCS settings
  vcs_repo {
    identifier     = "org/terraform-app"
    branch         = "main"
    oauth_token_id = tfe_oauth_client.github.oauth_token_id
  }

  # Working directory
  working_directory = "environments/production"

  # Terraform version
  terraform_version = "1.6.0"

  # Tags
  tag_names = ["app", "production", "aws"]
}

resource "tfe_variable" "aws_region" {
  key          = "AWS_REGION"
  value        = "us-east-1"
  category     = "env"
  workspace_id = tfe_workspace.app.id
}

resource "tfe_variable" "environment" {
  key          = "environment"
  value        = "production"
  category     = "terraform"
  workspace_id = tfe_workspace.app.id
}

resource "tfe_variable" "aws_credentials" {
  key          = "AWS_ACCESS_KEY_ID"
  value        = var.aws_access_key
  category     = "env"
  sensitive    = true
  workspace_id = tfe_workspace.app.id
}
```

---

## Part 4: Run Tasks

### Configure Run Tasks

```hcl
resource "tfe_organization_run_task" "security_scan" {
  organization = "my-organization"
  name         = "security-scan"
  url          = "https://security-scanner.example.com/terraform"
  hmac_key     = var.run_task_hmac_key
  enabled      = true
}

resource "tfe_workspace_run_task" "security" {
  workspace_id      = tfe_workspace.app.id
  task_id           = tfe_organization_run_task.security_scan.id
  enforcement_level = "mandatory"
  stage             = "post_plan"
}

resource "tfe_organization_run_task" "cost_estimation" {
  organization = "my-organization"
  name         = "cost-check"
  url          = "https://infracost.example.com/webhook"
  hmac_key     = var.infracost_hmac_key
  enabled      = true
}

resource "tfe_workspace_run_task" "cost" {
  workspace_id      = tfe_workspace.app.id
  task_id           = tfe_organization_run_task.cost_estimation.id
  enforcement_level = "advisory"
  stage             = "post_plan"
}
```

---

## Part 5: Teams and RBAC

```hcl
# Create team
resource "tfe_team" "developers" {
  name         = "developers"
  organization = "my-organization"

  organization_access {
    manage_workspaces = false
    manage_policies   = false
    manage_vcs_settings = false
  }
}

resource "tfe_team" "platform" {
  name         = "platform-team"
  organization = "my-organization"

  organization_access {
    manage_workspaces = true
    manage_policies   = true
  }
}

# Workspace access
resource "tfe_team_access" "dev_read" {
  team_id      = tfe_team.developers.id
  workspace_id = tfe_workspace.app.id
  access       = "read"
}

resource "tfe_team_access" "platform_admin" {
  team_id      = tfe_team.platform.id
  workspace_id = tfe_workspace.app.id
  access       = "admin"
}

# Custom permissions
resource "tfe_team_access" "dev_custom" {
  team_id      = tfe_team.developers.id
  workspace_id = tfe_workspace.app.id

  permissions {
    runs              = "apply"
    variables         = "read"
    state_versions    = "read"
    sentinel_mocks    = "read"
    workspace_locking = false
    run_tasks         = false
  }
}
```

---

## Part 6: Private Registry

### Publish Module

```hcl
resource "tfe_registry_module" "vpc" {
  organization = "my-organization"

  vcs_repo {
    display_identifier = "org/terraform-aws-vpc"
    identifier         = "org/terraform-aws-vpc"
    oauth_token_id     = tfe_oauth_client.github.oauth_token_id
  }
}
```

### Use Private Module

```hcl
module "vpc" {
  source  = "app.terraform.io/my-organization/vpc/aws"
  version = "2.0.0"

  name       = "production"
  cidr_block = "10.0.0.0/16"
}
```

---

## Part 7: Remote State Sharing

```hcl
# In workspace A - outputs
output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_ids" {
  value = aws_subnet.private[*].id
}
```

```hcl
# In workspace B - consume outputs
data "tfe_outputs" "vpc" {
  organization = "my-organization"
  workspace    = "network-production"
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = data.tfe_outputs.vpc.values.subnet_ids[0]
}
```

---

## Part 8: API-Driven Runs

```bash
# Trigger run via API
curl \
  --header "Authorization: Bearer $TFE_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data '{
    "data": {
      "type": "runs",
      "attributes": {
        "message": "Triggered via API",
        "auto-apply": false
      },
      "relationships": {
        "workspace": {
          "data": {
            "type": "workspaces",
            "id": "ws-abc123"
          }
        }
      }
    }
  }' \
  https://app.terraform.io/api/v2/runs
```

### Python SDK

```python
from terrasnek.api import TFC

api = TFC(TFC_TOKEN)
api.set_org("my-organization")

# List workspaces
workspaces = api.workspaces.list()

# Trigger run
run = api.runs.create({
    "data": {
        "type": "runs",
        "attributes": {
            "message": "Triggered via Python"
        },
        "relationships": {
            "workspace": {
                "data": {
                    "type": "workspaces",
                    "id": "ws-abc123"
                }
            }
        }
    }
})

# Wait for completion
api.runs.wait_for_run(run["data"]["id"])
```

---

## Exercise: Enterprise Workspace Setup

Create a complete HCP Terraform setup:

1. Organization with multiple teams
2. Workspaces for dev/staging/prod
3. VCS integration with GitHub
4. Run tasks for security scanning
5. Private module registry
6. Cross-workspace state sharing

---

## Checkpoint

Before moving to Lab 5.2, verify you can:

- [ ] Configure cloud backend
- [ ] Create and manage workspaces
- [ ] Set up teams and permissions
- [ ] Configure run tasks
- [ ] Use private registry
- [ ] Share state between workspaces

---

## Next: Lab 5.2 - Policy as Code

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- HCP Terraform Overview
- Backend Configuration
- Workspace Configuration
- Run Tasks

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
