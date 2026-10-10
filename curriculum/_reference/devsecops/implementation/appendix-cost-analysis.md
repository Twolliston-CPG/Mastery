# Cost Analysis

Infrastructure and tooling cost breakdown for the reference implementation. All costs are approximate and based on the source implementation's GCP **[GCP-SPECIFIC]** deployment.

> **Source files**: `northwind-infrastructure/docs/INFRASTRUCTURE.md`, `northwind-infrastructure/docs/STACK-DECISIONS.md`

---

## Summary

| Category | Monthly Cost | Notes |
|----------|-------------|-------|
| **Production Infrastructure** | ~$183 | GCP compute + networking |
| **Staging Infrastructure** | ~$110 | Cost-optimized (stop when not in use) |
| **Security Tooling** | $0 | 100% open-source |
| **Compliance Tooling** | $0 | 100% open-source |
| **Observability Tooling** | $0 | 100% open-source |
| **CI/CD** | $0 | GitHub Actions free tier (public repos) |
| **Total** | **~$110–$183/mo** | |

---

## Production Infrastructure Costs (~$183/month) **[GCP-SPECIFIC]**

| Resource | Spec | Monthly Cost |
|----------|------|-------------|
| Control Plane VM | e2-custom-4-16384 (4 vCPU, 16 GB RAM) | ~$60 |
| Worker VM (Spot) | e2-custom-4-20480 (4 vCPU, 20 GB RAM) | ~$33 |
| Network Load Balancer | Regional | ~$18 |
| Persistent Disks | 100 GB SSD (OS) + 50 GB (data) | ~$20 |
| Artifact Registry | Container image storage | ~$5 |
| Secret Manager | ~50 secrets, ~1000 access operations/month | ~$1 |
| GCS Storage | Terraform state, backups, SBOM archive | ~$5 |
| Pub/Sub | Event messaging | ~$1 |
| Network Egress | ~10 GB/month | ~$1 |
| Static IP | 1 regional IP | ~$7 |
| DNS | Cloud DNS zone | ~$0.50 |
| **Subtotal** | | **~$152** |
| Spot discount | Worker VM (60-70% savings) | -$47 |
| **Total Production** | | **~$183** |

### Cost Optimization Techniques

1. **Spot instances for worker nodes**: 60-70% savings on compute. Acceptable with PodDisruptionBudgets ensuring graceful eviction.

2. **Staging scheduler**: `staging-scheduler.yml` automatically stops staging VMs during off-hours (nights/weekends), reducing staging costs by ~60%.

3. **Co-located data layer**: PostgreSQL and Redis run on the control plane node, eliminating separate database VM costs.

4. **No VPC Flow Logs**: Disabled for MVP. Can enable selectively for debugging (~$5-10/month).

5. **Single-region deployment**: No cross-region replication costs for MVP.

## Staging Infrastructure Costs (~$110/month) **[GCP-SPECIFIC]**

| Resource | Spec | Monthly Cost |
|----------|------|-------------|
| Control Plane VM | e2-custom-4-16384 (with scheduling) | ~$40 |
| Worker VM (Spot) | e2-custom-4-20480 (with scheduling) | ~$22 |
| Persistent Disks | 80 GB SSD | ~$12 |
| Other (LB, IP, DNS) | Same services, lower usage | ~$20 |
| **Subtotal** | | **~$94** |
| Off-hours costs | VMs stopped ~60% of time | Included |
| **Total Staging** | | **~$110** |

## Security Tooling Costs ($0/month)

All security scanning uses open-source tools at zero licensing cost:

| Tool | Purpose | Cost | Alternative Avoided |
|------|---------|------|---------------------|
| CodeQL | Go SAST | $0 (GitHub-provided) | Checkmarx (~$15K/yr) |
| Gosec v2.18.2 | Go security analysis | $0 | Snyk Code (~$5K/yr) |
| govulncheck | Go vulnerability detection | $0 | Snyk SCA (~$5K/yr) |
| Nancy | Go dependency scanning | $0 | - |
| Trivy | Multi-purpose scanner | $0 | Prisma Cloud (~$10K/yr) |
| Snyk (free tier) | Node.js SAST + SCA | $0 | Snyk Team ($98/dev/mo) |
| TruffleHog | Verified secret scanning | $0 | GitGuardian (~$3K/yr) |
| Gitleaks v8.18.1 | Pattern-based secret scanning | $0 | - |
| OWASP ZAP | DAST scanning | $0 | Burp Suite Pro (~$450/yr) |
| SonarQube (CE) | Code quality | $0 | SonarQube EE (~$20K/yr) |
| DefectDojo | Vulnerability aggregation | $0 | - |
| Dependency-Track | SBOM analysis | $0 | Snyk ($5K/yr) |
| CISO Assistant | Compliance management | $0 | Drata (~$15K/yr) |
| **Total** | | **$0** | **~$78K+/yr avoided** |

### Go vs Node.js Security Cost Comparison

| Layer | Go Tools (Cost) | Node.js Tools (Cost) |
|-------|-----------------|---------------------|
| SAST | CodeQL + Gosec ($0) | Snyk Code ($0 free tier) |
| SCA | govulncheck + Nancy + Trivy ($0) | Snyk + npm audit + Trivy ($0 free tier) |
| Secrets | TruffleHog + Gitleaks ($0) | TruffleHog + Gitleaks ($0) |
| Container | Trivy ($0) | Snyk Container + Trivy ($0 free tier) |
| License | go-licenses ($0) | license-checker ($0) |
| **Total** | **$0** | **$0** |

## Compliance Automation Costs ($0/month)

| Tool | Purpose | Cost |
|------|---------|------|
| OSCAL/Trestle | Compliance documents | $0 |
| DefectDojo | Vulnerability management | $0 |
| CISO Assistant | Compliance UI | $0 |
| Dependency-Track | SBOM analysis | $0 |
| Python sync scripts | Automation glue | $0 |

**Resource overhead**: DefectDojo + Dependency-Track + CISO Assistant consume ~3.75 CPU / 6.2 GB memory on the K8s cluster. This fits within the existing 2-node cluster without additional VMs.

## CI/CD Costs

| Service | Cost | Notes |
|---------|------|-------|
| GitHub Actions | $0 | Free for public repos; 2,000 min/mo for private |
| Container Registry | ~$5/mo | Included in GCP costs above |
| Cosign signing | $0 | Keyless via GitHub OIDC |
| Rekor transparency log | $0 | Public service by Sigstore |

## Scaling Path

As the platform grows, costs will increase in these areas:

| Growth Trigger | Impact | Estimated Cost |
|----------------|--------|---------------|
| >10 services | Additional worker nodes | +$33/node (spot) |
| Multi-region | Cross-region replication | +$100-200/region |
| Managed K8s (GKE) | Control plane fee | +$74/month |
| Cloud SQL (managed DB) | Managed PostgreSQL | +$50-100/month |
| Snyk Team plan | Per-developer licensing | +$98/dev/month |
| GitHub Advanced Security | Private repo scanning | +$49/committer/month |

## Cloud Provider Alternatives

| Component | GCP Cost | AWS Equivalent | Azure Equivalent |
|-----------|----------|----------------|------------------|
| e2-custom-4-16384 | ~$60/mo | t3.xlarge (~$75/mo) | B4ms (~$70/mo) |
| Spot worker | ~$33/mo | Spot (~$25/mo) | Spot (~$28/mo) |
| Load Balancer | ~$18/mo | ALB (~$22/mo) | LB (~$20/mo) |
| Secret Manager | ~$1/mo | Secrets Manager (~$5/mo) | Key Vault (~$3/mo) |
| Container Registry | ~$5/mo | ECR (~$5/mo) | ACR (~$5/mo) |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Production Infrastructure Costs (~$183/month) [GCP-SPECIFIC]
- Staging Infrastructure Costs (~$110/month) [GCP-SPECIFIC]
- Security Tooling Costs ($0/month)
- Compliance Automation Costs ($0/month)

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
