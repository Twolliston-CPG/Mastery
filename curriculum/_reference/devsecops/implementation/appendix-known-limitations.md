# Known Limitations & Workarounds

Current gaps in the reference implementation and their workarounds or mitigation strategies.

> **Source files**: Various domain architecture and best-practices docs

---

## Runtime Security

### 1. Falco BTF/eBPF Incompatibility on GCP Kernel 6.14.0

**Status**: Active limitation

**Description**: Falco's eBPF driver requires BTF (BPF Type Format) support, which is not available on GCP's kernel 6.14.0 images. The Falco DaemonSet deploys but cannot load eBPF programs.

**Workaround**: Compensated by three alternative layers:
- **Trivy Operator**: Continuous container image scanning in-cluster
- **Kyverno**: Policy enforcement at admission and runtime
- **Cilium NetworkPolicies**: L7 network visibility and enforcement

**Resolution path**: Update to a kernel version with BTF support (kernel >= 5.8 with BTF, or custom-compiled kernel). GCP's Container-Optimized OS (COS) or Ubuntu 22.04+ images typically include BTF.

**Impact**: Reduced syscall-level visibility. Network and admission controls still provide strong runtime protection.

---

## Security Scanning

### 2. SonarQube Limited to Node.js Services

**Status**: By design

**Description**: SonarQube code quality analysis is only configured for Node.js services. Go services use CodeQL + Gosec instead.

**Rationale**: CodeQL's `security-extended,security-and-quality` query suite provides equivalent or better Go coverage at $0 cost. SonarQube's Go support is less mature than its JavaScript/TypeScript support.

**Impact**: None — Go services have comprehensive coverage via CodeQL + Gosec + govulncheck.

### 3. No IaC-Specific SAST

**Status**: Gap

**Description**: While Terraform files are scanned by Trivy, Checkov, and tflint, there is no dedicated SAST (static application security testing) for HCL code patterns. Conftest/OPA policies handle custom rules but don't cover all SAST patterns.

**Recommendation**: Consider [tfsec](https://github.com/aquasecurity/tfsec) (now merged into Trivy) or [Semgrep](https://semgrep.dev/) for HCL-specific SAST rules.

### 4. DAST Limited to Staging Environment

**Status**: By design

**Description**: OWASP ZAP DAST scanning only runs against the staging environment. Production is not scanned.

**Rationale**: DAST scanning generates real traffic and can cause side effects. Staging provides a safe target that mirrors production configuration.

**Impact**: Production-only configurations or behaviors are not tested. Mitigated by ensuring staging/production parity.

### 5. Snyk Free Tier Limitations

**Status**: Active limitation

**Description**: The Snyk free tier limits the number of tests per month and may not include all vulnerability data. Some advanced features (priority scoring, fix PRs) require paid tiers.

**Workaround**: Trivy runs in parallel with Snyk as a backup scanner. Critical findings are caught by both tools.

**Resolution path**: Upgrade to Snyk Team ($98/dev/month) when budget allows, or migrate fully to Trivy + CodeQL for Node.js.

---

## Infrastructure

### 6. Single-Region Deployment

**Status**: By design (MVP)

**Description**: The platform runs in a single GCP region (us-east1) **[GCP-SPECIFIC]** with no cross-region replication.

**Impact**: Regional outages cause full platform downtime. RPO depends on backup frequency to GCS (which is multi-regional).

**Resolution path**: Add a second region with:
- Cross-region PostgreSQL replication
- Multi-region GCS buckets
- Global load balancer
- Estimated additional cost: $100-200/month

### 7. Two-Node Cluster Constraints **[KUBEADM-SPECIFIC]**

**Status**: Active limitation

**Description**: The 2-node kubeadm cluster (control plane + worker) has limited capacity:
- Control plane: K8s system components + PostgreSQL + Redis + monitoring
- Worker: All application workloads
- No spare nodes for rolling upgrades or node failures

**Workaround**:
- PodDisruptionBudgets prevent all pods from being evicted simultaneously
- Spot instance preemption is handled gracefully
- Velero backups enable cluster rebuild

**Resolution path**: Add additional worker nodes ($33/node/month with spot pricing).

### 8. Terraform State in Single Bucket

**Status**: Active limitation

**Description**: Terraform state is stored in a single GCS bucket per environment **[GCP-SPECIFIC]**. No state locking mechanism beyond GCS object versioning.

**Workaround**: GCS provides object-level locking via Terraform's GCS backend. However, concurrent `terraform apply` runs could conflict.

**Resolution path**: Use Terraform Cloud or implement a CI/CD-based state locking mechanism (e.g., only allow `terraform apply` via CI/CD, never locally).

---

## Compliance

### 9. OSCAL Tooling Maturity

**Status**: Active limitation

**Description**: The OSCAL ecosystem (Trestle, compliance-as-code tools) is relatively new. Tooling for validation, rendering, and import/export is still maturing.

**Impact**: Some manual effort required for compliance document formatting and auditor presentation. The `generate-ssp-markdown.py` script bridges the gap by rendering OSCAL as human-readable markdown.

### 10. DefectDojo Scan Deduplication Accuracy

**Status**: Active limitation

**Description**: DefectDojo's automatic deduplication may occasionally create duplicate findings when the same vulnerability is reported by multiple scanners with slightly different fingerprints.

**Workaround**: Configure product-level deduplication settings. Periodically review and merge duplicate findings via the DefectDojo UI.

---

## Developer Experience

### 11. Pre-commit Hook Performance

**Status**: Active limitation

**Description**: Running all 20 pre-commit hooks locally can take 30-60 seconds on first run (especially Checkov, Gosec, and golangci-lint). Subsequent runs are faster due to caching.

**Workaround**:
- Use `pre-commit run --files <changed-files>` instead of running all hooks on all files
- pre-commit.ci handles the full hook suite in CI, so local failures are caught remotely
- Consider `.pre-commit-config.yaml` stages to only run fast hooks on commit, slow hooks on push

### 12. Backstage Plugin Maintenance

**Status**: Ongoing

**Description**: Backstage plugins require periodic updates and may break between major Backstage versions. The Node.js ecosystem moves fast.

**Workaround**: Pin Backstage version and update quarterly. Use only stable, well-maintained plugins.

---

## Observability

### 13. No Distributed Tracing (Self-Hosted)

**Status**: Gap

**Description**: The source implementation uses Cloud Trace **[GCP-SPECIFIC]** for distributed tracing. There is no self-hosted tracing solution deployed.

**Recommendation**: Deploy Jaeger or Grafana Tempo for cloud-agnostic distributed tracing. Both integrate with the existing Prometheus + Grafana stack.

### 14. Alertmanager Configuration Complexity

**Status**: Active limitation

**Description**: Alertmanager routing rules can become complex with multiple notification channels (Slack, PagerDuty, email). Misconfigurations may cause alert fatigue or missed alerts.

**Workaround**: Use the Grafana Alerting UI as a more user-friendly alternative for alert rule management. Keep Alertmanager for critical infrastructure alerts only.

---

## Resilience

### 15. DR Test Automation Coverage

**Status**: Partial

**Description**: The `reusable-dr-test.yml` workflow automates basic DR testing (cluster rebuild, restore from backup) but does not cover all failure scenarios.

**Missing scenarios**:
- Partial data corruption recovery
- Cross-region failover
- Cascading service failure recovery
- DNS failover validation

**Resolution path**: Expand Litmus Chaos experiments to cover these scenarios. Add periodic DR drills with runbook validation.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Runtime Security
- Security Scanning
- Infrastructure
- Compliance

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
