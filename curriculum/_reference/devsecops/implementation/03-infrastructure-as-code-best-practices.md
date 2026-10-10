# Domain 3: Infrastructure as Code -- Best Practices Analysis

## Strengths

### 1. Module Composition Pattern
- Clean separation between reusable modules (`modules/`) and environment bindings (`environments/`)
- Each module has a consistent `main.tf`, `variables.tf`, `outputs.tf` structure
- Modules are composable: the root composition wires outputs from one module into inputs of another (e.g., `vpc.network_id` feeds into `k8s-cluster`, `cloud-sql`, `redis`)

### 2. OPA Policy-as-Code
- Custom Rego policies in `policies/terraform/security.rego` enforce security guardrails at plan time
- Policies cover IAM least-privilege, public access prevention, firewall restrictions, database SSL enforcement, and hardcoded secret detection
- Conftest integrates OPA into the CI pipeline so violations block merges
- Kubernetes admission policies (`policies/kubernetes/`) validate deployments, pods, and network policies

### 3. Exact Provider Pinning
- Providers use exact version constraints (`= 5.10.0` instead of `~> 5.10`), ensuring reproducible builds
- Both `google` and `random` providers are pinned
- Lock files (`.terraform.lock.hcl`) checked in for hash verification

### 4. Security-First Design
- **[GCP-SPECIFIC]** Workload Identity Federation eliminates static service account keys for CI/CD
- **[GCP-SPECIFIC]** Shielded VMs with secure boot, vTPM, and integrity monitoring on all K8s nodes
- **[GCP-SPECIFIC]** Identity-Aware Proxy for zero-trust admin access
- **[GCP-SPECIFIC]** Private IP only for Cloud SQL (no public endpoint)
- **[GCP-SPECIFIC]** Uniform bucket-level access and public access prevention on all GCS buckets
- SLSA Level 4 branch protection enforced via Terraform-managed GitHub settings

### 5. Cost Optimization
- **[KUBEADM-SPECIFIC]** kubeadm on GCE VMs instead of GKE saves the management fee (~$74/month per cluster)
- Spot/preemptible VMs for worker nodes (~70% cost savings)
- Staging cluster stop/start automation via reusable workflow
- Tiered GCS storage lifecycle policies (Standard -> Nearline -> Coldline -> Archive)

### 6. Multi-Layer Security Scanning
- tfsec for Terraform-specific security checks
- Trivy for IaC misconfigurations
- Checkov for GCP security policies
- Gitleaks for secret detection in code
- OPA/Conftest for custom policy enforcement
- All scans produce SARIF output for GitHub Security tab integration

### 7. Drift Detection
- Automated daily drift detection via scheduled workflow
- Uses `terraform plan -detailed-exitcode` to detect changes
- Auto-creates GitHub issues when drift is found
- Supports both staging and production environments

### 8. Automated Secret Rotation
- **[GCP-SPECIFIC]** Cloud Functions handle rotation logic
- **[GCP-SPECIFIC]** Secret Manager rotation policies trigger automatic rotation
- **[GCP-SPECIFIC]** Pub/Sub notifications for rotation events
- **[GCP-SPECIFIC]** Cloud Monitoring alerts on rotation failures
- **[GCP-SPECIFIC]** Cloud Scheduler for periodic health checks

### 9. SBOM Generation
- CycloneDX format SBOM generated from Terraform provider lock files
- SBOM artifact retained for 90 days
- Tracks all Terraform provider dependencies with versions

---

## Limitations

### 1. Single-Region Design
- All resources deployed to a single GCP region (`us-east1`)
- No multi-region failover or disaster recovery configuration
- GCS `training_content` bucket uses multi-region, but other buckets are regional

### 2. kubeadm Operational Overhead
- **[KUBEADM-SPECIFIC]** Manual cluster upgrades (no managed control plane)
- **[KUBEADM-SPECIFIC]** Manual certificate rotation and etcd management
- **[KUBEADM-SPECIFIC]** No built-in node auto-repair or auto-scaling
- **[KUBEADM-SPECIFIC]** Startup scripts handle cluster initialization -- errors can leave clusters in inconsistent state

### 3. Limited Module Versioning
- Modules referenced via relative paths (`../../modules/vpc`) rather than versioned registry sources
- No semantic versioning for individual modules
- Changes to modules affect all environments simultaneously

### 4. Missing Remote State Data Sources
- No use of `terraform_remote_state` data sources for cross-stack references
- Outputs are wired within a single root composition, limiting decomposition options

### 5. No CMEK Encryption
- GCS buckets use Google-managed encryption keys, not customer-managed (CMEK)
- Secret Manager secrets use automatic replication without explicit KMS configuration

### 6. Firewall Rules Allow Broad Access
- Some firewall rules allow `0.0.0.0/0` for ingress (HTTP/HTTPS) and K8s API
- NodePort range open to internal networks (`10.0.0.0/8`)

---

## Recommendations

### Short-Term (Quick Wins)

1. **Add module versioning:** Publish modules to a private Terraform registry or use Git tags with `source = "git::https://...?ref=v1.0.0"`
2. **Restrict K8s API firewall:** Replace `0.0.0.0/0` with specific IP ranges for API access (port 6443)
3. **Enable VPC flow logs in production:** Currently disabled for cost savings but essential for security monitoring
4. **Add CMEK for sensitive buckets:** Apply customer-managed encryption keys to tax_documents, financial_documents, and evidence buckets

### Medium-Term (Architecture Improvements)

5. **Implement remote state data sources:** Split the monolithic root composition into smaller stacks (network, compute, data) with remote state references
6. **Add Terraform workspaces or Terragrunt:** Reduce duplication between staging and production environment files
7. **Implement node auto-recovery:** Add health check scripts that auto-restart failed kubeadm nodes
8. **Add Cloud NAT for production:** Currently disabled -- needed for secure outbound traffic without public IPs

### Long-Term (Strategic)

9. **Evaluate GKE Autopilot:** For production workloads where operational overhead of kubeadm outweighs cost savings
10. **Multi-region architecture:** Add a secondary region with GCS replication and compute failover
11. **Implement Terraform Cloud or Spacelift:** For better state management, policy enforcement, and team collaboration
12. **Add cost alerting:** Integrate Infracost thresholds with automated PR blocking

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Module Composition Pattern
- OPA Policy-as-Code
- Exact Provider Pinning
- Security-First Design

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
