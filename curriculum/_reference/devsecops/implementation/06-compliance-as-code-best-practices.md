# Compliance as Code -- Best Practices

## Strengths

### 1. Full OSCAL Adoption with Trestle Tooling

The implementation uses the NIST OSCAL standard end-to-end rather than ad-hoc spreadsheets or proprietary formats. Every compliance artifact -- catalogs, profiles, component definitions, system security plans, assessment results, and assessment plans -- is machine-readable JSON validated by IBM Trestle. This enables automated validation on every pull request, preventing compliance drift before it reaches the main branch.

### 2. 100% Control Coverage Across Three Frameworks

All selected controls are fully mapped: 28/28 NIST 800-53, 5/5 SOC2 TSC, and 4/4 ISO 27001. Each control has a concrete technical implementation referenced in component definitions, with source file paths linking to the actual Rego policies, CI/CD workflows, or Terraform modules that implement the control. There are no "planned" or "partially implemented" controls.

### 3. Automated Compliance Pipeline

The four-workflow system creates a continuous compliance loop:
- **PR validation** catches OSCAL schema errors before merge
- **Weekly SSP assembly** keeps documentation current
- **Daily assessment** collects evidence from GitHub, DefectDojo, and OPA policies
- **Daily tool sync** propagates findings to CISO Assistant for stakeholder visibility

This eliminates the manual "evidence collection sprint" before audits.

### 4. Bidirectional Tool Integration

The sync architecture flows data in both directions:
- **DefectDojo to OSCAL**: Vulnerability findings are mapped to control assessments (RA-5, SA-11)
- **OSCAL to CISO Assistant**: Component definitions and assessment evidence are exported for compliance officer review

This keeps the OSCAL source of truth synchronized with the operational tools that security teams actually use daily.

### 5. Component-Based Architecture

Controls are organized by technical domain (Kubernetes policies, CI/CD security, infrastructure security) rather than by framework. A single OPA policy can satisfy controls across NIST 800-53 and SOC2 simultaneously. This component-based approach eliminates duplicate documentation and makes it clear which technical artifact satisfies which compliance requirement.

### 6. Defense-in-Depth Vulnerability Management

The three compliance tools serve complementary purposes:
- **DefectDojo** aggregates and deduplicates findings from all scan types with MTTR tracking
- **Dependency-Track** provides continuous SBOM-based vulnerability monitoring
- **CISO Assistant** provides the compliance management layer for non-technical stakeholders

### 7. GDPR Data Lifecycle Automation

The location archival cron job automates GDPR-compliant data retention with configurable retention periods, dry-run capability, environment separation, and Slack failure notifications. This turns a potentially error-prone manual process into a verified automated workflow.

### 8. Non-Root Security Contexts

All compliance tool deployments (DefectDojo, CISO Assistant) run with non-root security contexts, privilege escalation disabled, and network policies restricting both ingress and egress traffic. The compliance tools themselves follow the same security standards they are measuring.

---

## Limitations

### 1. Catalog Stubs Not Populated

The `catalogs/` and `assessment-plans/` directories exist in the repository structure but are empty. The profiles reference the upstream NIST catalog via URL, which works for Trestle but means there is no local copy of the catalog for offline validation or auditor review without network access.

**Impact**: Offline validation is not possible; auditors cannot review the full catalog locally.

### 2. Assessment Results Are Not Historical

The daily assessment overwrites `assessment-results/latest/`, meaning there is no built-in historical trend analysis. While GitHub artifact retention (365 days) provides backups, there is no time-series view of compliance posture over time.

**Impact**: Difficult to demonstrate compliance improvement trends to auditors.

### 3. DefectDojo Secrets in Plain YAML

The DefectDojo and CISO Assistant Secret manifests contain hardcoded credentials in `stringData`. While this is a common pattern for initial deployment, it means secrets are stored in version control.

**Impact**: Secret exposure risk if the infrastructure repository is compromised.

### 4. Single-Replica Compliance Tools

DefectDojo, CISO Assistant, and their databases all run with `replicas: 1`. There are no horizontal pod autoscalers or pod disruption budgets for the compliance tools themselves.

**Impact**: Compliance tool downtime during node maintenance or pod eviction.

### 5. No Automated Remediation

When assessments find "not-satisfied" controls, the system generates findings but does not trigger automated remediation workflows. There is no integration with issue trackers to create tickets for failing controls.

**Impact**: Manual intervention required to act on assessment findings.

### 6. GCP-Specific Dependency-Track Secrets

Dependency-Track uses External Secrets with a GCP Secret Manager ClusterSecretStore. This creates a hard dependency on GCP infrastructure for secret management.

**Impact**: Additional work required to deploy on non-GCP platforms.

### 7. No Multi-Cluster Support

The compliance tools are deployed to a single cluster. There is no federated compliance view across multiple clusters or environments.

**Impact**: Organizations with multiple clusters need to deploy and sync compliance tools independently.

---

## Recommendations

### Short-Term (1-2 Sprints)

1. **Populate catalog stubs**: Download and commit the NIST 800-53 Rev 5 catalog JSON locally so that validation works offline and auditors have a self-contained repository.

2. **Move secrets to External Secrets**: Replace the hardcoded Secret manifests for DefectDojo and CISO Assistant with ExternalSecret resources (like Dependency-Track already uses), pulling credentials from a secret manager.

3. **Add assessment history**: Instead of overwriting `latest/`, write assessment results to timestamped directories (`assessment-results/YYYY-MM-DD/`) and maintain a `latest` symlink. This provides built-in historical tracking.

4. **Create issue integration**: Add a workflow step after assessment that opens GitHub Issues for any "not-satisfied" findings, with labels for severity and control ID. Close issues automatically when subsequent assessments show "satisfied."

### Medium-Term (1-3 Months)

5. **Add HPA and PDB for compliance tools**: Configure horizontal pod autoscalers for DefectDojo Django and Celery workers, and pod disruption budgets for all compliance tool components to ensure availability during cluster maintenance.

6. **Implement compliance dashboard**: Create a Grafana dashboard that visualizes compliance posture over time by parsing assessment results. Track metrics like: controls satisfied over time, MTTR by severity, vulnerability trend lines.

7. **Add OSCAL assessment plans**: Populate the empty `assessment-plans/` directory with formal assessment plan documents that describe the methodology, scope, and frequency of automated assessments. This is required for formal ATO (Authority to Operate) processes.

8. **Integrate Dependency-Track findings into OSCAL**: Add a script similar to `sync-defectdojo-to-assessment.py` that pulls SBOM vulnerability data from Dependency-Track and maps it to CM-8 (System Component Inventory) and RA-5 (Vulnerability Scanning) controls.

### Long-Term (3-6 Months)

9. **Multi-cluster compliance federation**: Implement a central compliance aggregator that collects assessment results from multiple clusters and provides a unified compliance view.

10. **Continuous ATO (cATO)**: Integrate the compliance pipeline with a formal ATO process where continuous assessment results automatically maintain or revoke authorization based on real-time compliance posture.

11. **Add ISO 27001 coverage depth**: Expand ISO 27001 coverage beyond the current 4 controls to include additional Annex A controls relevant to cloud-native deployments (A.12 Operations Security, A.14 System Development, A.18 Compliance).

12. **OSCAL-native DefectDojo integration**: Contribute or develop a DefectDojo plugin that natively exports findings in OSCAL Assessment Results format, eliminating the need for the custom sync script.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Full OSCAL Adoption with Trestle Tooling
- 100% Control Coverage Across Three Frameworks
- Automated Compliance Pipeline
- Bidirectional Tool Integration

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
