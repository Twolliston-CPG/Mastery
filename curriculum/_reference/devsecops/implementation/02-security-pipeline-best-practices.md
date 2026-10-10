# Security Pipeline — Best Practices & Gaps

## Strengths

### 1. Comprehensive Five-Layer Scanning
Every PR passes through SAST, SCA, secret detection, container scanning, and license compliance — covering the full attack surface from code to container.

### 2. Language-Specific Toolchain Selection
Go and Node.js each use the optimal scanning tools for their ecosystem. Go uses govulncheck (call-graph analysis, zero false positives on reachability) while Node.js uses Snyk (deep npm ecosystem knowledge). This avoids the "one tool for everything" anti-pattern.

### 3. $0 Security Tooling Cost for Go
The Go security pipeline (CodeQL + Gosec + govulncheck + Nancy + Trivy) provides commercial-grade coverage at zero cost. Snyk is only used where it provides unique value (Node.js ecosystem).

### 4. SARIF as Universal Output Format
All scanners emit SARIF, enabling a unified data flow: GitHub Security tab (developer visibility) → DefectDojo (security team aggregation) → CISO Assistant (compliance evidence). This prevents scanner-specific data silos.

### 5. Verified-Only Secret Detection
TruffleHog's `--only-verified` flag dramatically reduces false positives by confirming secrets are actually active against provider APIs. This makes secret detection results actionable rather than noise.

### 6. Automated Threat Modeling
Threagile integration provides automated threat modeling that runs on model changes, catching architectural risks before they become code.

### 7. Continuous SBOM Monitoring
Dependency-Track continuously re-evaluates SBOMs as new CVEs are published, catching vulnerabilities that appear after a build was already deployed.

## Known Limitations

### 1. SonarQube Only for Node.js
SonarQube code quality gates are only configured for Node.js services. Go services rely on golangci-lint (in CI) and Gosec (in security pipeline) but lack equivalent quality metrics like complexity analysis and duplication tracking.

**Impact**: Medium — Go code quality depends on lint rules rather than holistic quality gates.

### 2. No SAST for Infrastructure as Code
While `reusable-terraform-security.yml` covers Terraform with Checkov and tflint, there's no equivalent SAST analysis for Kubernetes manifests beyond schema validation. Kyverno policies fill part of this gap at admission time but not at PR time.

**Impact**: Low — admission controllers catch issues before deployment, but feedback comes later in the pipeline.

### 3. DAST Limited to Staging
DAST scans (OWASP ZAP) only run against staging. There is no production DAST scanning, which means production-only configurations or behaviors are not tested.

**Impact**: Low — staging closely mirrors production, but environment-specific issues could be missed.

### 4. No Mobile/Frontend DAST
DAST scanning is designed for REST API services. Mobile apps and SPAs require browser-based DAST tools not currently in the pipeline.

**Impact**: Low for the current architecture (backend-focused), but would need addressing for frontend-heavy services.

### 5. DefectDojo as Single Point of Failure
All vulnerability aggregation flows through DefectDojo. If DefectDojo is down, vulnerability tracking and SLA enforcement are disrupted. There is no fallback — GitHub Security tab provides visibility but not aggregation or SLA management.

**Impact**: Medium — mitigated by DefectDojo's persistence (PostgreSQL-backed) and the fact that scan results are still stored as SARIF in GitHub.

### 6. Snyk Dependency on Commercial Service
While Go scanning is fully open-source, Node.js scanning depends on Snyk for SAST and SCA. If the Snyk free tier limits are hit or the service is unavailable, Node.js scanning degrades.

**Impact**: Medium — Trivy provides backup SCA coverage, but Snyk Code SAST has no open-source equivalent with comparable accuracy.

## Recommendations for Improvement

### 1. Add SonarQube for Go Services
Configure SonarQube with Go analysis to provide quality gates (complexity, duplication, maintainability) equivalent to Node.js. This would create a unified quality reporting experience across languages.

### 2. Add Pre-Deployment K8s Manifest Scanning
Add Kubescape or Checkov K8s scanning to PR-time workflows, catching misconfigurations before they reach admission controllers. This provides faster feedback than waiting for Gatekeeper/Kyverno rejection.

### 3. Consider Semgrep as Snyk Code Alternative
Semgrep provides open-source SAST rules for Node.js that could replace or supplement Snyk Code, reducing commercial dependency while maintaining coverage.

### 4. Add Vulnerability SLA Dashboard
The `reusable-vulnerability-sla.yml` workflow tracks SLAs, but there's no centralized dashboard showing SLA compliance across all services. A Grafana dashboard pulling from DefectDojo APIs would provide visibility.

### 5. Add SBOM Attestation Verification
While SBOMs are generated and signed, there's no automated verification that deployed images have valid SBOM attestations. The runtime-verifier component partially addresses this, but a dedicated CI check would add defense in depth.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Known Limitations
- Recommendations for Improvement
- Comprehensive Five-Layer Scanning
- Language-Specific Toolchain Selection

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
