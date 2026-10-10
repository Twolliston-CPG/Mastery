# Architecture Decision Records

Consolidated from the source implementation's technology stack decisions (~15 decision areas). Each ADR follows a lightweight format: context, decision, rationale, and consequences.

> **Source files**: `northwind-infrastructure/docs/STACK-DECISIONS.md`, `northwind-infrastructure/docs/K8S-RATIONALE.md`

---

## ADR-001: Container Orchestration — kubeadm Kubernetes

**Context**: Need a container orchestration platform. Options: managed K8s (GKE/EKS/AKS), kubeadm, k3s, OpenShift, Docker Swarm.

**Decision**: kubeadm v1.34 on self-managed VMs.

**Rationale**:
- $0 licensing vs $74+/month for managed K8s control plane fees
- Full feature set (all admission controllers, API features)
- Industry-standard skills (directly transferable)
- Complete customization of control plane components

**Consequences**:
- (+) ~60% cost reduction vs managed K8s
- (+) Full control over cluster configuration
- (-) Self-managed upgrades and patching
- (-) No built-in SLA from cloud provider
- **[KUBEADM-SPECIFIC]** — for managed K8s, skip cluster bootstrap and node management sections

---

## ADR-002: Container Networking — Cilium v1.15

**Context**: Need a CNI plugin. Options: Calico, Flannel, Weave, Cilium.

**Decision**: Cilium v1.15 with eBPF.

**Rationale**:
- eBPF-based networking is faster than iptables
- Built-in Hubble for network flow observability
- L7 network policies (HTTP/gRPC-aware)
- CNCF graduated project with strong community
- Seamless Istio ambient mode integration

**Consequences**:
- (+) Kernel-level performance
- (+) DNS-aware policies, FQDN filtering
- (+) Built-in observability without additional tools
- (-) Requires Linux kernel >= 4.19 with BTF support
- (-) Higher learning curve than Flannel

---

## ADR-003: Container Base Images — Distroless (Go) + Alpine (Node.js)

**Context**: Need secure, minimal container images for production services.

**Decision**: `gcr.io/distroless/static-debian12:nonroot` for Go, `node:18-alpine` for Node.js.

**Rationale**:
- **Go (Distroless)**: ~2MB image, no shell/package manager, near-zero CVEs. Go produces static binaries (`CGO_ENABLED=0`) that need only CA certs and timezone data.
- **Node.js (Alpine)**: ~40MB (vs ~350MB for full Node.js image). Node.js requires a runtime so `scratch`/distroless isn't viable.

**Consequences**:
- (+) Minimal attack surface (no shell for post-exploitation)
- (+) Faster pulls, lower storage costs
- (+) Non-root by default (UID 65532 for distroless, custom for alpine)
- (-) No shell for debugging — use `kubectl debug` with ephemeral containers
- (-) Alpine uses musl libc — rare Node.js native module compatibility issues

---

## ADR-004: Service Mesh — Istio Ambient Mode

**Context**: Need mutual TLS between services and traffic management. Options: Istio sidecar, Istio ambient, Linkerd, no mesh.

**Decision**: Istio ambient mode (sidecar-less).

**Rationale**:
- Automatic mTLS without per-pod sidecar overhead
- Reduced memory (~128MB per sidecar savings × N pods)
- Simpler deployment model (ztunnel DaemonSet vs per-pod sidecars)
- L4 auth by default, optional L7 waypoint proxies

**Consequences**:
- (+) Zero resource overhead per pod
- (+) Transparent mTLS enrollment
- (-) Ambient mode is newer, smaller community knowledge base
- (-) L7 features require explicit waypoint proxy deployment

---

## ADR-005: GitOps — ArgoCD with Image Updater

**Context**: Need automated deployment from Git. Options: ArgoCD, Flux, Jenkins X.

**Decision**: ArgoCD with ArgoCD Image Updater for automatic image promotion.

**Rationale**:
- Strong UI for deployment visibility
- Sync-wave ordering for dependency management
- Image Updater polls registry every 2 minutes for semver-tagged images
- Git write-back to kustomization.yaml for full auditability

**Consequences**:
- (+) Fully declarative deployments from Git
- (+) Automatic staging deploys on merge to main
- (+) Visual deployment dashboard
- (-) ArgoCD resource overhead (~300MB memory)
- (-) Image Updater adds polling load to container registry

---

## ADR-006: Secrets Management — External Secrets Operator + Secret Manager

**Context**: Need secure secret injection into K8s pods. Options: K8s native secrets, Vault, External Secrets Operator.

**Decision**: External Secrets Operator syncing from GCP Secret Manager **[GCP-SPECIFIC]**, with Stakater Reloader for automatic pod restarts.

**Rationale**:
- No Vault infrastructure to manage ($0 additional cost)
- Cloud-native secret rotation
- Kubernetes-native integration (creates standard K8s Secrets)
- Reloader handles automatic pod restarts on secret rotation

**Consequences**:
- (+) Automated rotation (5m–1h intervals)
- (+) Cloud-provider audit logging
- (+) No additional infrastructure to manage
- (-) Cloud-provider dependency for secret storage
- (-) Requires WIF/OIDC for secure access from K8s

---

## ADR-007: Security Scanning — $0 Go Stack vs Snyk for Node.js

**Context**: Need comprehensive security scanning. Go and Node.js have different tool ecosystems.

**Decision**: Go uses entirely open-source tools (CodeQL + Gosec + govulncheck + Nancy + Trivy). Node.js uses Snyk (SAST + SCA + Container) + Trivy.

**Rationale**:
- **Go**: CodeQL (`security-extended`) + Gosec v2.18.2 + govulncheck provide equal or better coverage than Snyk at $0. govulncheck uses the official Go vulnerability database and performs reachability analysis.
- **Node.js**: Snyk's JavaScript/TypeScript analysis is significantly better than open-source alternatives. Snyk Code (SAST) has broader rule coverage for Node.js patterns.

**Consequences**:
- (+) $0/month security tooling for Go services
- (+) Best-in-class scanning for both languages
- (+) All scanners emit SARIF for unified tracking
- (-) Different tool configurations per language
- (-) Snyk requires paid tier for some features

---

## ADR-008: Supply Chain Security — SLSA Level 3

**Context**: Need to verify the integrity of build artifacts. Options: no verification, SLSA Level 1-3.

**Decision**: SLSA Level 3 with hermetic builds, Cosign signing, and Rekor transparency log.

**Rationale**:
- Hermetic builds (`--network none`, `GOPROXY=off`) prevent dependency confusion attacks
- Cosign keyless signing uses GitHub OIDC — no key management
- Rekor provides immutable, public transparency log of all signatures
- OPA Gatekeeper enforces signed images at admission

**Consequences**:
- (+) Verifiable provenance for every container image
- (+) Prevents supply chain attacks (no runtime dependency fetching)
- (+) Admission control blocks unsigned images
- (-) Two-phase build is slower (fetch deps → hermetic build)
- (-) Requires OIDC setup for keyless signing

---

## ADR-009: Compliance Automation — OSCAL/Trestle + DefectDojo + CISO Assistant

**Context**: Need automated compliance evidence and tracking for NIST 800-53, SOC2, ISO 27001.

**Decision**: OSCAL via Trestle for machine-readable compliance, DefectDojo for vulnerability aggregation, CISO Assistant for compliance management.

**Rationale**:
- OSCAL is the NIST standard for machine-readable compliance documents
- DefectDojo aggregates and deduplicates vulnerability findings from all scanners
- CISO Assistant provides the compliance management UI for auditors
- All three are open-source ($0 licensing)

**Consequences**:
- (+) Automated compliance assessment (daily)
- (+) Machine-readable evidence for auditors
- (+) $0 tooling cost
- (-) In-cluster deployment uses ~3.75 CPU / 6.2 GB memory
- (-) OSCAL has a steep learning curve

---

## ADR-010: Observability — Prometheus + Grafana + Fluent Bit

**Context**: Need metrics, logging, and alerting. Options: cloud-native (Cloud Monitoring), Datadog, self-hosted.

**Decision**: Self-hosted Prometheus + Grafana + Fluent Bit + OpenSearch.

**Rationale**:
- $0/month vs $23+/month for cloud monitoring
- Full control over retention and alerting rules
- Industry-standard tools with large ecosystem
- No data egress concerns

**Consequences**:
- (+) Complete customization of dashboards and alerts
- (+) No per-metric or per-log-line costs
- (-) Self-managed storage and retention
- (-) No built-in anomaly detection (requires manual rule writing)

---

## ADR-011: Runtime Security — Defense-in-Depth (Falco + KubeArmor + Gatekeeper + Kyverno)

**Context**: Need runtime protection beyond CI/CD scanning. Options: single tool, layered approach.

**Decision**: Four complementary layers: Falco (syscall monitoring), KubeArmor (runtime enforcement), OPA Gatekeeper (admission control), Kyverno (policy enforcement).

**Rationale**:
- Each tool covers a different protection layer
- Gatekeeper handles admission-time policies (block before deployment)
- Kyverno handles resource mutation/validation
- Falco detects runtime threats (syscall anomalies)
- KubeArmor enforces fine-grained process/file/network restrictions

**Consequences**:
- (+) Defense-in-depth: no single point of failure
- (+) Catches threats that CI/CD scanning misses
- (-) Falco currently disabled on GCP kernel 6.14.0 (BTF/eBPF incompatibility)
- (-) Multiple policy engines increase management complexity

---

## ADR-012: Backup Strategy — Velero + Litestream + etcd Snapshots

**Context**: Need backup and disaster recovery for the platform. Options: cloud snapshots only, Velero, custom scripts.

**Decision**: Three-layer backup: Velero (K8s resources + PV snapshots), Litestream (PostgreSQL WAL streaming), etcd snapshots.

**Rationale**:
- Velero handles K8s native resources and persistent volumes
- Litestream provides continuous PostgreSQL replication (RPO near-zero)
- etcd snapshots protect cluster state independently

**Consequences**:
- (+) Multiple recovery options depending on failure type
- (+) Continuous PostgreSQL backup (not just periodic)
- (+) Can restore individual namespaces or full cluster
- (-) GCS storage costs for backup buckets **[GCP-SPECIFIC]**
- (-) Restore procedures require periodic testing

---

## ADR-013: Developer Portal — Backstage

**Context**: Need a central developer portal for service catalog, docs, and operational visibility.

**Decision**: Backstage with PostgreSQL backend.

**Rationale**:
- CNCF project with strong community
- Unified view: service catalog + K8s pods + ArgoCD + Prometheus + GitHub Actions
- TechDocs for documentation-as-code
- catalog-info.yaml follows domain → system → component hierarchy

**Consequences**:
- (+) Single pane of glass for developers
- (+) Service ownership and dependency tracking
- (+) Automated documentation rendering
- (-) Additional PostgreSQL database required
- (-) Plugin ecosystem requires maintenance

---

## ADR-014: Pre-commit Hooks — 20 Hooks with pre-commit.ci

**Context**: Need to catch issues before code reaches CI/CD.

**Decision**: 20 pre-commit hooks with pre-commit.ci for weekly auto-updates and autofix PRs.

**Rationale**:
- Catches formatting, security, and style issues locally
- pre-commit.ci automates hook version updates
- Conventional Commits via commitizen ensure consistent commit messages

**Consequences**:
- (+) Faster feedback than CI/CD
- (+) Consistent code formatting across all contributors
- (+) Secret detection before push
- (-) Initial setup overhead for developers
- (-) Some hooks (checkov, gosec) can be slow locally

---

## ADR-015: Chaos Engineering — Litmus Chaos

**Context**: Need to validate resilience through failure injection.

**Decision**: Litmus Chaos for Kubernetes-native chaos experiments.

**Rationale**:
- CNCF project with strong K8s integration
- Declarative chaos experiments via CRDs
- Supports: pod kill, network partition, node drain, CPU/memory stress
- ChaosResult provides structured experiment outcomes

**Consequences**:
- (+) Validates PDB, HPA, and self-healing in production-like conditions
- (+) Scheduled experiments for continuous resilience validation
- (-) Requires careful runbook for production environments
- (-) Not a substitute for proper capacity planning

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- ADR-001: Container Orchestration — kubeadm Kubernetes
- ADR-002: Container Networking — Cilium v1.15
- ADR-003: Container Base Images — Distroless (Go) + Alpine (Node.js)
- ADR-004: Service Mesh — Istio Ambient Mode

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
