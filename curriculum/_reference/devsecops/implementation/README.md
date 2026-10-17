# DevOps & DevSecOps Reference Implementation

A reusable, cloud-agnostic reference system for building enterprise-grade DevOps and DevSecOps platforms. Extracted from a production polyrepo running ~27 microservices (Go + Node.js) on self-managed Kubernetes, achieving 100% SEC540 compliance and SLSA Level 3 supply chain security using entirely open-source tooling at ~$110-183/month.

## Quickstart

1. **Pick a domain** from the table below based on what you need
2. **Read the architecture doc** to understand the pattern
3. **Copy the consumer templates** into your service repo
4. **Replace placeholders** — all templates use `{{VARIABLE_NAME}}` syntax (see Placeholder Reference)
5. **Follow the implementation checklist** step by step

## Domains

| # | Domain | What You Get |
|---|--------|-------------|
| 01 | **CI/CD Pipelines** | GitHub Actions reusable workflows (26 standalone + composite), SLSA L3 hermetic builds, Cosign signing, SBOM generation, canary deployments |
| 02 | **Security Pipeline** | 5-layer shift-left scanning (SAST, SCA, secrets, containers, licenses), DAST, DefectDojo/Dependency-Track integration, threat modeling |
| 03 | **Infrastructure as Code** | Terraform modules (13), Packer hardened images, OPA Rego policies, IaC security scanning |
| 04 | **Kubernetes Platform** | Kustomize manifests, ArgoCD GitOps with sync-waves, External Secrets, Istio service mesh, in-cluster PostgreSQL/Redis |
| 05 | **Runtime Security** | Falco, KubeArmor, OPA Gatekeeper (workload + supply chain), Kyverno, ModSecurity WAF, DLP, incident response automation |
| 06 | **Compliance as Code** | OSCAL/Trestle (NIST 800-53, SOC2, ISO 27001), DefectDojo, Dependency-Track, CISO Assistant, GDPR data lifecycle |
| 07 | **Observability** | Prometheus, Grafana dashboards, Fluent Bit, Alertmanager, SIEM rules |
| 08 | **Developer Experience** | 20 pre-commit hooks, Backstage portal, Renovate/Dependabot, PR preview environments |
| 09 | **Resilience & DR** | Velero backups, Litestream WAL streaming, Litmus chaos experiments, etcd snapshots, DR test workflows |

## Cross-Cutting Docs

These patterns span multiple domains — read them for architectural context:

- [Secret Management](cross-cutting-secret-management.md) — End-to-end secret lifecycle from cloud provider to pod
- [OIDC / Workload Identity](cross-cutting-oidc-workload-identity.md) — Keyless authentication from CI/CD to cloud
- [SARIF Integration](cross-cutting-sarif-integration.md) — Universal scanner output format and data flow
- [Vulnerability Sinks](cross-cutting-vulnerability-sinks.md) — DefectDojo + Dependency-Track architecture

## Appendix

- [New Service Checklist](appendix-new-service-checklist.md) — End-to-end checklist for onboarding a new microservice across all domains
- [Architecture Decision Records](appendix-architecture-decision-records.md) — Consolidated ADRs (~15 decisions)
- [Cost Analysis](appendix-cost-analysis.md) — Infrastructure and tooling cost breakdown
- [Known Limitations](appendix-known-limitations.md) — Current gaps and workarounds

## Adding a New Service

The fastest path to onboarding a new microservice:

```bash
# 1. Copy consumer templates for your language
cp -r 01-cicd-pipelines/consumer-templates/go-service/.github/ my-service/.github/
cp -r 04-kubernetes-platform/consumer-templates/ my-service/k8s/
cp -r 08-developer-experience/consumer-templates/go-service/* my-service/

# 2. Replace all placeholders
find my-service/ -type f -exec sed -i '' \
  -e 's/{{ORG_NAME}}/my-org/g' \
  -e 's/{{SERVICE_NAME}}/my-service/g' \
  -e 's/{{SERVICE_PORT}}/3001/g' \
  -e 's/{{REPO_NAME}}/my-org-my-service/g' \
  {} +

# 3. Follow the full checklist
# See appendix/new-service-checklist.md
```

## Cloud Provider Support

Templates are designed for GCP but annotated for portability:

- **[GCP-SPECIFIC]** — Items that need adaptation for other clouds
- **[KUBEADM-SPECIFIC]** — Items specific to self-managed Kubernetes
- **[AWS-SPECIFIC]** / **[AZURE-SPECIFIC]** — Cloud-specific alternatives noted in architecture docs

## Key Metrics from Source Implementation

| Metric | Value |
|--------|-------|
| SEC540 Compliance | 15/15 controls (100%) |
| SLSA Level | 3 (targeting 4) |
| Security scanning tools | 13+ integrated |
| Monthly tooling cost | $0 (fully open-source) |
| Monthly infrastructure | ~$110-183 |
| Compliance frameworks | NIST 800-53, SOC2, ISO 27001 |
| Build time (with caching) | 3-5 min (~60% reduction) |

## Reference Versions

| Component | Version |
|-----------|---------|
| Go | 1.22 |
| Node.js | 18 LTS |
| Kubernetes | v1.34.3 |
| Terraform | >= 1.5 |

See INSTRUCTIONS.md for the complete version table.

## License

This reference implementation is provided as-is for educational and adoption purposes.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Quickstart
- Domains
- Cross-Cutting Docs
- Adding a New Service

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
