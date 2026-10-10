# Lab 5.2: Policy as Code

## Objective

Implement governance with Sentinel and Open Policy Agent (OPA).

## Duration: 90 minutes

---

## Part 1: Sentinel Fundamentals

### Policy Structure

```sentinel
# policy.sentinel

# Import modules
import "tfplan/v2" as tfplan
import "tfrun"
import "strings"

# Define parameters
param allowed_instance_types default ["t2.micro", "t2.small", "t2.medium"]

# Helper function
get_instances = func() {
    return filter tfplan.resource_changes as _, rc {
        rc.type is "aws_instance" and
        rc.mode is "managed" and
        (rc.change.actions contains "create" or rc.change.actions contains "update")
    }
}

# Main rule
main = rule {
    all get_instances() as _, instance {
        instance.change.after.instance_type in allowed_instance_types
    }
}
```

### Common Sentinel Imports

```sentinel
# tfplan/v2 - Access planned changes
import "tfplan/v2" as tfplan

# tfconfig/v2 - Access configuration
import "tfconfig/v2" as tfconfig

# tfstate/v2 - Access current state
import "tfstate/v2" as tfstate

# tfrun - Access run metadata
import "tfrun"
```

---

## Part 2: Sentinel Policy Examples

### Restrict Instance Types

```sentinel
# restrict-instance-types.sentinel
import "tfplan/v2" as tfplan

param allowed_types default [
    "t2.micro",
    "t2.small",
    "t2.medium",
    "t3.micro",
    "t3.small",
    "t3.medium",
]

# Get all EC2 instances being created or updated
instances = filter tfplan.resource_changes as _, rc {
    rc.type is "aws_instance" and
    rc.mode is "managed" and
    (rc.change.actions contains "create" or
     rc.change.actions contains "update")
}

# Validate instance types
instance_type_allowed = rule {
    all instances as _, instance {
        instance.change.after.instance_type in allowed_types
    }
}

# Main rule
main = rule {
    instance_type_allowed
}
```

### Require Tags

```sentinel
# require-tags.sentinel
import "tfplan/v2" as tfplan
import "strings"

# Required tags
param required_tags default ["Environment", "Owner", "Project"]

# Resources that support tags
taggable_resources = [
    "aws_instance",
    "aws_s3_bucket",
    "aws_vpc",
    "aws_subnet",
    "aws_security_group",
    "aws_db_instance",
]

# Get taggable resources
get_taggable = func() {
    return filter tfplan.resource_changes as _, rc {
        rc.type in taggable_resources and
        rc.mode is "managed" and
        (rc.change.actions contains "create" or
         rc.change.actions contains "update")
    }
}

# Check if resource has all required tags
has_required_tags = func(resource) {
    tags = resource.change.after.tags else {}
    return all required_tags as tag {
        tag in keys(tags) and
        length(tags[tag]) > 0
    }
}

# Main rule
main = rule {
    all get_taggable() as _, resource {
        has_required_tags(resource)
    }
}
```

### Restrict Regions

```sentinel
# restrict-regions.sentinel
import "tfconfig/v2" as tfconfig

param allowed_regions default ["us-east-1", "us-west-2", "eu-west-1"]

# Get AWS provider configurations
aws_providers = filter tfconfig.providers as _, p {
    p.provider_config_key contains "aws"
}

# Check regions
region_allowed = rule {
    all aws_providers as _, provider {
        provider.config.region.constant_value in allowed_regions
    }
}

main = rule {
    region_allowed
}
```

### Cost Controls

```sentinel
# cost-controls.sentinel
import "tfrun"
import "decimal"

# Maximum allowed cost increase
param max_monthly_increase default 100.0

# Get cost estimate
cost_estimate = tfrun.cost_estimate

# Check if cost increase is within limits
cost_within_limits = rule when cost_estimate.delta_monthly_cost is defined {
    decimal.new(cost_estimate.delta_monthly_cost).less_than(
        decimal.new(max_monthly_increase)
    )
}

main = rule {
    cost_within_limits
}
```

### Prevent Destruction

```sentinel
# prevent-destroy.sentinel
import "tfplan/v2" as tfplan

# Protected resource types
param protected_resources default [
    "aws_db_instance",
    "aws_s3_bucket",
    "aws_dynamodb_table",
]

# Find resources being destroyed
destroying = filter tfplan.resource_changes as _, rc {
    rc.type in protected_resources and
    rc.change.actions contains "delete"
}

# Prevent destruction of protected resources
main = rule {
    length(destroying) is 0
}
```

---

## Part 3: Sentinel Policy Sets

### Directory Structure

**`policies/`**

- `sentinel.hcl`
- `common/`
  - `require-tags.sentinel`
  - `restrict-regions.sentinel`
- `security/`
  - `no-public-s3.sentinel`
  - `encryption-required.sentinel`
- `cost/`
  - `cost-controls.sentinel`


### sentinel.hcl

```hcl
# sentinel.hcl
policy "require-tags" {
    source = "./common/require-tags.sentinel"
    enforcement_level = "hard-mandatory"

    params = {
        required_tags = ["Environment", "Owner", "Project", "CostCenter"]
    }
}

policy "restrict-regions" {
    source = "./common/restrict-regions.sentinel"
    enforcement_level = "soft-mandatory"

    params = {
        allowed_regions = ["us-east-1", "us-west-2"]
    }
}

policy "no-public-s3" {
    source = "./security/no-public-s3.sentinel"
    enforcement_level = "hard-mandatory"
}

policy "encryption-required" {
    source = "./security/encryption-required.sentinel"
    enforcement_level = "hard-mandatory"
}

policy "cost-controls" {
    source = "./cost/cost-controls.sentinel"
    enforcement_level = "advisory"

    params = {
        max_monthly_increase = 500.0
    }
}
```

---

## Part 4: HCP Terraform Policy Configuration

```hcl
# Policy set configuration
resource "tfe_policy_set" "security" {
  name         = "security-policies"
  description  = "Security-related policies"
  organization = "my-organization"
  kind         = "sentinel"

  vcs_repo {
    identifier         = "org/sentinel-policies"
    branch             = "main"
    oauth_token_id     = tfe_oauth_client.github.oauth_token_id
    ingress_submodules = false
  }

  policies_path = "security"
}

# Attach to workspaces
resource "tfe_policy_set" "global" {
  name         = "global-policies"
  organization = "my-organization"
  global       = true  # Apply to all workspaces

  policy_ids = [
    tfe_sentinel_policy.require_tags.id,
    tfe_sentinel_policy.restrict_regions.id,
  ]
}

# Workspace-specific policies
resource "tfe_policy_set" "production" {
  name         = "production-policies"
  organization = "my-organization"

  workspace_ids = [
    tfe_workspace.production.id,
  ]

  policy_ids = [
    tfe_sentinel_policy.prevent_destroy.id,
    tfe_sentinel_policy.cost_controls.id,
  ]
}
```

---

## Part 5: Open Policy Agent (OPA)

### Rego Policy Example

```rego
# policy.rego
package terraform.security

import input.plan as tfplan

# Deny public S3 buckets
deny[msg] {
    resource := tfplan.resource_changes[_]
    resource.type == "aws_s3_bucket"
    resource.change.after.acl == "public-read"
    msg := sprintf("S3 bucket '%s' cannot be public", [resource.address])
}

# Require encryption
deny[msg] {
    resource := tfplan.resource_changes[_]
    resource.type == "aws_ebs_volume"
    not resource.change.after.encrypted
    msg := sprintf("EBS volume '%s' must be encrypted", [resource.address])
}

# Restrict instance types
allowed_instance_types := {"t2.micro", "t2.small", "t3.micro", "t3.small"}

deny[msg] {
    resource := tfplan.resource_changes[_]
    resource.type == "aws_instance"
    instance_type := resource.change.after.instance_type
    not allowed_instance_types[instance_type]
    msg := sprintf("Instance type '%s' not allowed for '%s'", [instance_type, resource.address])
}
```

### Using OPA with Terraform

```bash
# Generate plan JSON
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json

# Evaluate with OPA
opa eval -i tfplan.json -d policy.rego "data.terraform.security.deny"

# In CI/CD
opa eval -i tfplan.json -d policy.rego --fail-defined "data.terraform.security.deny[x]"
```

### OPA in GitHub Actions

```yaml
- name: OPA Policy Check
  run: |
    # Generate plan
    terraform plan -out=tfplan
    terraform show -json tfplan > tfplan.json

    # Run OPA
    opa eval \
      --input tfplan.json \
      --data policies/ \
      --format pretty \
      "data.terraform.security.deny" > opa-results.txt

    # Check for violations
    if [ -s opa-results.txt ]; then
      echo "Policy violations found:"
      cat opa-results.txt
      exit 1
    fi
```

---

## Part 6: Conftest

```bash
# Install conftest
brew install conftest

# Run policies
conftest test tfplan.json -p policies/

# With custom namespace
conftest test tfplan.json -p policies/ --namespace terraform.security
```

### conftest Policy

```rego
# policies/main.rego
package main

import data.terraform.security

deny = security.deny
warn = security.warn
```

---

## Exercise: Comprehensive Policy Suite

Create policies for:

1. Required tags on all resources
2. Instance type restrictions by environment
3. Encryption enforcement
4. Region restrictions
5. Cost thresholds
6. No public access to databases
7. VPC requirements

---

## Checkpoint

Before moving to Lab 5.3, verify you can:

- [ ] Write Sentinel policies
- [ ] Configure policy sets
- [ ] Use different enforcement levels
- [ ] Write OPA/Rego policies
- [ ] Integrate policies in CI/CD

---

## Next: Lab 5.3 - Security & Compliance

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Sentinel Fundamentals
- Sentinel Policy Examples
- Sentinel Policy Sets
- HCP Terraform Policy Configuration

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
