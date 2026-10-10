# Domain 3: Infrastructure as Code -- Configuration Reference

## Terraform Backend Configuration

### GCS Backend **[GCP-SPECIFIC]**

```hcl
terraform {
  required_version = ">= 1.5"

  backend "gcs" {
    bucket = "{{TERRAFORM_STATE_BUCKET}}"     # GCS bucket for state storage
    prefix = "infrastructure/{{ENVIRONMENT}}"  # State path prefix per environment
  }
}
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| `bucket` | `{{TERRAFORM_STATE_BUCKET}}` | GCS bucket name for Terraform state |
| `prefix` | `infrastructure/staging` or `infrastructure/production` | Environment-specific state path |

**State Bucket Requirements:**
- Versioning enabled (for state recovery)
- Uniform bucket-level access
- Public access prevention enforced
- Lifecycle rule: delete non-current versions after 90 days

---

## Provider Configuration

### Google Provider **[GCP-SPECIFIC]**

```hcl
required_providers {
  google = {
    source  = "hashicorp/google"
    version = "= 5.10.0"    # Exact version pin for reproducibility
  }
  random = {
    source  = "hashicorp/random"
    version = "= 3.6.0"     # Used for join tokens, passwords
  }
}

provider "google" {
  project = var.project_id   # {{GCP_PROJECT_ID}}
  region  = var.region        # {{GCP_REGION}}
}
```

| Provider | Version | Purpose |
|----------|---------|---------|
| `hashicorp/google` | `= 5.10.0` | All GCP resources |
| `hashicorp/random` | `= 3.6.0` | Random passwords, tokens |
| `integrations/github` | `~> 6.0` | Branch protection (github-repository module) |
| `github.com/hashicorp/googlecompute` | `>= 1.1.0` | Packer image builds |

---

## .tflint.hcl Configuration

```hcl
# tflint configuration for Terraform linting
# Place in repository root

config {
  # Enable all rules by default
  module = true
}

plugin "google" {
  enabled = true
  version = "0.27.1"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

# Enforce naming conventions
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Require description for all variables
rule "terraform_documented_variables" {
  enabled = true
}

# Require description for all outputs
rule "terraform_documented_outputs" {
  enabled = true
}

# Require type for all variables
rule "terraform_typed_variables" {
  enabled = true
}
```

---

## Packer Variables

### kubeadm-node.pkr.hcl Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_id` | string | (required) | **[GCP-SPECIFIC]** GCP project ID |
| `zone` | string | `us-east1-b` | **[GCP-SPECIFIC]** Build zone |
| `kubernetes_version` | string | `1.34.3` | **[KUBEADM-SPECIFIC]** K8s version to install |
| `image_family` | string | `kubeadm-ubuntu-2404` | Image family name for auto-resolution |
| `machine_type` | string | `e2-standard-2` | **[GCP-SPECIFIC]** Machine type for build VM |
| `disk_size` | number | `20` | Boot disk size in GB |

### Build Environment Variables

| Variable | Provisioner | Description |
|----------|-------------|-------------|
| `DEBIAN_FRONTEND` | All scripts | Set to `noninteractive` for unattended installs |
| `KUBERNETES_VERSION` | 02, 04 | **[KUBEADM-SPECIFIC]** K8s version for kubeadm/kubelet |

---

## OPA Policy Reference

### Terraform Security Policies

**Source:** `policies/terraform/security.rego`
**Package:** `terraform.security`

| Rule Type | Rule | Trigger Condition |
|-----------|------|-------------------|
| `deny` | Overly permissive IAM | `roles/owner` or `roles/editor` used |
| `deny` | Public IAM members | `allUsers` or `allAuthenticatedUsers` in IAM binding |
| `deny` | Public GCS buckets | `public_access_prevention` not set to `enforced` |
| `deny` | Permissive firewall | `0.0.0.0/0` access to sensitive ports (22, 3389, 5432, 3306, 6379, 27017) |
| `deny` | Cloud SQL without SSL | `require_ssl` not set to true |
| `deny` | Cloud SQL public IP | `ipv4_enabled` true without `private_network` |
| `deny` | Production DB no backup | Production Cloud SQL without `backup_configuration.enabled` |
| `deny` | Hardcoded secrets | Fields named `password`, `secret`, `api_key`, `private_key` with literal values |
| `warn` | Unencrypted buckets | Buckets with `sensitive` in name but no CMEK |
| `warn` | No bucket versioning | GCS buckets without versioning enabled |
| `warn` | Open firewall | Any `0.0.0.0/0` source range (informational) |
| `warn` | No production logging | Production GCS buckets without access logging |

### Kubernetes Admission Policies

**Source:** `policies/kubernetes/`

| Package | File | Rules |
|---------|------|-------|
| `kubernetes.deployment` | `deployment.rego` | Resource limits, no `:latest` tag, no privileged, no root, probes, labels |
| `kubernetes.pod` | `pod.rego` | No hostPath, no Docker/containerd socket mounts, service account required |
| `kubernetes.network` | `network.rego` | NetworkPolicy required for app namespaces, no allow-all ingress |
| `kubernetes.supply-chain` | `supply-chain.rego` | SLSA supply chain verification |

---

## Environment Variables (terraform.tfvars)

### Staging Defaults

| Variable | Value | Description |
|----------|-------|-------------|
| `project_id` | `{{GCP_PROJECT_ID}}-staging` | **[GCP-SPECIFIC]** Staging project |
| `region` | `{{GCP_REGION}}` | **[GCP-SPECIFIC]** Primary region |
| `github_org` | `{{ORG_NAME}}` | GitHub organization |
| `github_repo` | `{{APP_NAME}}-infrastructure` | Infrastructure repository |

### Production Defaults

| Variable | Value | Description |
|----------|-------|-------------|
| `project_id` | `{{GCP_PROJECT_ID}}` | **[GCP-SPECIFIC]** Production project |
| `region` | `{{GCP_REGION}}` | **[GCP-SPECIFIC]** Primary region |

---

## GitHub Secrets Required

| Secret | Description | Used By |
|--------|-------------|---------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | **[GCP-SPECIFIC]** WIF provider full resource name | terraform-plan, terraform-apply |
| `GCP_SERVICE_ACCOUNT` | **[GCP-SPECIFIC]** Service account email | terraform-plan, packer-build |
| `GCP_STAGING_SERVICE_ACCOUNT` | **[GCP-SPECIFIC]** Staging-specific SA email | terraform-apply (staging) |
| `GCP_PRODUCTION_SERVICE_ACCOUNT` | **[GCP-SPECIFIC]** Production-specific SA email | terraform-apply (production) |
| `GCP_PROJECT_ID` | **[GCP-SPECIFIC]** GCP project ID | packer-build |
| `INFRACOST_API_KEY` | Infracost API key for cost estimation | terraform-plan |
| `GITHUB_TOKEN` | GitHub token (auto-provided) | gitleaks, PR comments |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Terraform Backend Configuration
- Provider Configuration
- .tflint.hcl Configuration
- Packer Variables

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
