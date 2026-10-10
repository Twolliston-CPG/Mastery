# Multi-Cloud Service Equivalence Mapping

This document provides a comprehensive mapping of cloud services across GCP, AWS, and Azure for the DevSecOps AI platform. Each service mapping includes the corresponding Terraform module path and interface compatibility notes.

## Service Equivalence Table

| GCP Service | AWS Equivalent | Azure Equivalent | Terraform Module Path |
|---|---|---|---|
| Google Kubernetes Engine (GKE) | Elastic Kubernetes Service (EKS) | Azure Kubernetes Service (AKS) | `modules/k8s-cluster/{aws,azure}` |
| Cloud SQL for PostgreSQL | Amazon RDS for PostgreSQL | Azure Database for PostgreSQL Flexible Server | `modules/cloud-sql/{aws,azure}` |
| Memorystore for Redis | Amazon ElastiCache for Redis | Azure Cache for Redis | `modules/cache/{aws,azure}` (planned) |
| Artifact Registry | Elastic Container Registry (ECR) | Azure Container Registry (ACR) | `modules/artifact-registry/{aws,azure}` |
| Secret Manager | AWS Secrets Manager | Azure Key Vault | `modules/secret-manager/{aws,azure}` |
| Cloud Storage (GCS) | Amazon S3 | Azure Blob Storage | `modules/object-storage/{aws,azure}` (planned) |
| Workload Identity Federation (WIF) | IAM OIDC Provider (IRSA) | Workload Identity (Federated Credentials) | Integrated into `k8s-cluster` modules |
| Cloud Trace | AWS X-Ray | Azure Application Insights | `modules/tracing/{aws,azure}` (planned) |
| Cloud Data Loss Prevention (DLP) | Amazon Macie | Microsoft Purview | `modules/data-protection/{aws,azure}` (planned) |
| VPC | Amazon VPC | Azure Virtual Network (VNet) | `modules/vpc/{aws,azure}` |

## Per-Module Interface Compatibility Notes

All multi-cloud Terraform modules are designed with a **common interface** pattern: the same variable names produce equivalent infrastructure on different cloud providers. This enables multi-cloud deployments through a single abstraction layer.

### vpc (Network Foundation)

| Variable | AWS Behavior | Azure Behavior |
|---|---|---|
| `project_name` | Prefixed to all resource names | Prefixed to all resource names |
| `environment` | Used for tagging and naming | Used for tagging and naming |
| `vpc_cidr` | VPC CIDR block | VNet address space |
| `availability_zones` | AWS AZ names (e.g., `us-east-1a`) | Azure zone numbers (e.g., `1`, `2`, `3`) |
| `enable_nat_gateway` | Creates NAT Gateway + Elastic IP | Creates Azure NAT Gateway + Public IP |

**Key Differences:**
- AWS uses separate route tables per AZ for private subnets; Azure uses a single route table.
- Azure NSGs are separate resources associated to subnets; AWS uses Security Groups at the instance/ENI level.
- Azure VNets support service endpoints natively; AWS uses VPC endpoints.
- Flow logs: AWS uses CloudWatch; Azure uses NSG Flow Logs with Traffic Analytics.

**Common Outputs:** `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `nat_gateway_ips`

### k8s-cluster (Kubernetes Platform)

| Variable | AWS (EKS) Behavior | Azure (AKS) Behavior |
|---|---|---|
| `cluster_name` | EKS cluster name | AKS cluster name |
| `k8s_version` | EKS Kubernetes version | AKS Kubernetes version |
| `node_instance_types` | EC2 instance types for managed node group | VM sizes for node pools (first=system, second=workload) |
| `min_nodes` / `max_nodes` | Node group scaling config | Node pool autoscaler config |

**Key Differences:**
- EKS requires explicit OIDC provider setup for IRSA; AKS has built-in workload identity with `workload_identity_enabled`.
- EKS uses separate addons (vpc-cni, coredns, kube-proxy); AKS bundles these.
- AKS creates a separate node resource group automatically; EKS does not.
- EKS cluster security group and node security group are managed separately; AKS uses network profiles.
- AKS supports Azure AD RBAC natively; EKS uses aws-auth ConfigMap or access entries.

**Common Outputs:** `cluster_endpoint`, `cluster_name`, `kubeconfig`

### artifact-registry (Container Images)

| Variable | AWS (ECR) Behavior | Azure (ACR) Behavior |
|---|---|---|
| `repository_name` | ECR repository name | ACR registry name (alphanumeric only) |
| `image_tag_mutability` | MUTABLE or IMMUTABLE | Preserved for compatibility (ACR uses content trust) |
| `scan_on_push` | ECR basic/enhanced scanning | Defender for Containers (separate enablement) |

**Key Differences:**
- ECR creates individual repositories; ACR is a registry containing multiple repositories.
- ECR lifecycle policies are JSON-based; ACR uses retention policies (Premium SKU).
- ACR Premium supports geo-replication; ECR uses replication configuration.
- ECR scanning uses Inspector V2; ACR uses Microsoft Defender for Containers.
- ACR supports scope maps and tokens for granular access; ECR uses IAM policies.

**Common Outputs:** `repository_url`, `repository_arn`

### cloud-sql (Managed Database)

| Variable | AWS (RDS) Behavior | Azure (Flexible Server) Behavior |
|---|---|---|
| `db_name` | RDS instance identifier | Flexible Server name |
| `engine_version` | PostgreSQL version (e.g., `16.1`) | PostgreSQL major version (e.g., `16`) |
| `instance_class` | RDS instance class (e.g., `db.r6g.large`) | SKU name (e.g., `GP_Standard_D4s_v3`) |
| `allocated_storage` | Storage in GB (gp3) | Storage in GB (Premium SSD) |
| `multi_az` | Multi-AZ standby deployment | Zone-redundant high availability |

**Key Differences:**
- RDS uses DB subnet groups; Azure uses delegated subnets with private DNS zones.
- RDS parameter groups are separate resources; Azure uses server configurations.
- RDS stores credentials in Secrets Manager; Azure stores in Key Vault.
- Azure Flexible Server supports AAD authentication natively.
- RDS supports automated storage autoscaling via `max_allocated_storage`.

**Common Outputs:** `endpoint`, `port`, `db_name`

### secret-manager (Secrets and Keys)

| Variable | AWS (Secrets Manager) Behavior | Azure (Key Vault) Behavior |
|---|---|---|
| `secret_name` | Secret name in Secrets Manager | Key Vault name (3-24 chars, unique globally) |
| `rotation_days` | Lambda-based automatic rotation | Key/Secret rotation policy |

**Key Differences:**
- AWS Secrets Manager is purely for secrets; Azure Key Vault handles secrets, keys, and certificates.
- AWS rotation requires a Lambda function; Azure rotation uses built-in rotation policies.
- Key Vault names must be globally unique and 3-24 characters.
- AWS uses resource policies for cross-account access; Azure uses RBAC or access policies.
- Key Vault supports soft delete and purge protection by default in production.

**Common Outputs:** `secret_arn`, `secret_name`

## Cloud-Native Security Integrations

### AWS Security Services

| Service | Purpose | Integration Point |
|---|---|---|
| **Amazon GuardDuty** | Threat detection across AWS accounts | Monitors VPC Flow Logs, DNS logs, CloudTrail, S3, EKS audit logs, and Lambda |
| **AWS Security Hub** | Centralized security findings aggregation | Aggregates findings from GuardDuty, Inspector, Macie, IAM Access Analyzer, and Firewall Manager |
| **Amazon Inspector** | Automated vulnerability assessment | Scans ECR images and EC2/Lambda workloads for software vulnerabilities and network exposure |
| **AWS Config** | Resource compliance monitoring | Evaluates resource configurations against rules (CIS, PCI DSS, NIST) |
| **Amazon Macie** | Sensitive data discovery in S3 | Scans S3 buckets for PII, credentials, and sensitive data patterns |
| **IAM Access Analyzer** | External access analysis | Identifies resources shared with external principals |
| **AWS CloudTrail** | API activity logging | Records all API calls for audit and compliance |

**Terraform Templates:** `05-runtime-security/templates/aws-security/`
- `guardduty.tf` - GuardDuty with S3, EKS, and malware protection
- `security-hub.tf` - Security Hub with CIS and AWS Foundational Security standards

### Azure Security Services

| Service | Purpose | Integration Point |
|---|---|---|
| **Microsoft Defender for Cloud** | Unified security management and threat protection | Covers containers, Key Vault, DNS, Resource Manager, SQL, Storage, and App Service |
| **Azure Sentinel** | Cloud-native SIEM and SOAR | Ingests logs from Azure Activity, Security Center, and custom sources for threat hunting |
| **Azure Policy** | Governance and compliance enforcement | Enforces organizational standards across all Azure resources |
| **Azure AD Conditional Access** | Identity-based access control | Context-aware access policies for Azure and integrated apps |
| **Microsoft Purview** | Data governance and DLP | Scans data stores for sensitive information classification and protection |
| **Azure Network Watcher** | Network monitoring and diagnostics | NSG flow logs, packet capture, connection troubleshooting |

**Terraform Templates:** `05-runtime-security/templates/azure-security/`
- `defender.tf` - Defender for Cloud with container, Key Vault, DNS, and Resource Manager protection
- `sentinel.tf` - Sentinel with data connectors and custom analytics rules

### Cross-Cloud Security Feature Matrix

| Security Capability | AWS | Azure | GCP |
|---|---|---|---|
| **Threat Detection** | GuardDuty | Defender for Cloud | Security Command Center |
| **SIEM/SOAR** | Security Hub + EventBridge | Sentinel | Chronicle |
| **Container Security** | Inspector + GuardDuty EKS | Defender for Containers | GKE Security Posture |
| **Secret Rotation** | Secrets Manager + Lambda | Key Vault Rotation Policy | Secret Manager + Cloud Functions |
| **DLP** | Macie | Purview | Cloud DLP |
| **Compliance** | Config + Security Hub | Policy + Defender | SCC + Organization Policy |
| **Network Monitoring** | VPC Flow Logs + Traffic Mirroring | NSG Flow Logs + Traffic Analytics | VPC Flow Logs + Packet Mirroring |
| **Identity Federation** | IRSA (OIDC) | Workload Identity | Workload Identity Federation |
| **Audit Logging** | CloudTrail | Activity Log + Diagnostic Settings | Cloud Audit Logs |
| **Vulnerability Scanning** | Inspector V2 | Defender Vulnerability Assessment | Artifact Analysis |

## Module Directory Structure

```
03-infrastructure-as-code/templates/modules/
|-- vpc/
|   |-- aws/          # VPC, subnets, NAT, route tables, flow logs
|   |-- azure/        # VNet, subnets, NSG, NAT gateway, route tables
|-- k8s-cluster/
|   |-- aws/          # EKS, node groups, OIDC, security groups
|   |-- azure/        # AKS, node pools, AAD RBAC, monitoring
|-- artifact-registry/
|   |-- aws/          # ECR, lifecycle policies, scanning
|   |-- azure/        # ACR, geo-replication, scope maps
|-- cloud-sql/
|   |-- aws/          # RDS PostgreSQL, multi-AZ, parameter groups
|   |-- azure/        # Flexible Server, HA, private DNS
|-- secret-manager/
|   |-- aws/          # Secrets Manager, KMS, rotation
|   |-- azure/        # Key Vault, access policies, diagnostics

05-runtime-security/templates/
|-- aws-security/
|   |-- guardduty.tf
|   |-- security-hub.tf
|-- azure-security/
|   |-- defender.tf
|   |-- sentinel.tf
```

## Usage Pattern

To deploy infrastructure on a specific cloud provider, reference the cloud-specific module:

```hcl
# AWS deployment
module "network" {
  source             = "../modules/vpc/aws"
  project_name       = "devsecops-ai"
  environment        = "production"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  enable_nat_gateway = true
}

# Azure deployment (same interface)
module "network" {
  source             = "../modules/vpc/azure"
  project_name       = "devsecops-ai"
  environment        = "production"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["1", "2", "3"]
  enable_nat_gateway = true
}
```

The common interface pattern enables cloud-agnostic orchestration while preserving cloud-native best practices within each module implementation.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Service Equivalence Table
- Per-Module Interface Compatibility Notes
- Cloud-Native Security Integrations
- Module Directory Structure

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
