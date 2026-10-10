# Security Pipeline — Configuration Reference

## Reusable Workflow Inputs

### reusable-go-security.yml

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier
    type: string
  go-version:            # Go compiler version
    type: string
    default: '1.22'
  working-directory:     # Service source root
    type: string
    default: '.'
  enable-codeql:         # Run CodeQL analysis
    type: boolean
    default: true
  enable-gosec:          # Run Gosec scanner
    type: boolean
    default: true
  enable-govulncheck:    # Run govulncheck
    type: boolean
    default: true
  enable-nancy:          # Run Nancy (Sonatype OSS Index)
    type: boolean
    default: true
  enable-secret-scanning: # Run TruffleHog + Gitleaks
    type: boolean
    default: true
  fail-on-severity:      # Minimum severity to fail the build
    type: string
    default: 'high'      # Options: low, medium, high, critical
```

### reusable-node-security.yml (reusable-security.yml in source)

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier
    type: string
  node-version:          # Node.js version
    type: string
    default: '18'
  working-directory:     # Service source root
    type: string
    default: '.'
  severity-threshold:    # Snyk severity threshold
    type: string
    default: 'high'

secrets:
  NPM_TOKEN:             # GitHub Packages token for private packages
    required: true
  SNYK_TOKEN:            # Snyk API token
    required: true
```

### reusable-terraform-security.yml

```yaml
inputs:
  working-directory:     # Terraform root directory
    type: string
    default: '.'
  checkov-skip-checks:   # Comma-separated CKV IDs to skip
    type: string
    default: 'CKV_GCP_32'  # [GCP-SPECIFIC] Skipped in pre-commit
  tflint-config:         # Path to .tflint.hcl
    type: string
    default: '.tflint.hcl'
  conftest-policy-dir:   # OPA Rego policy directory
    type: string
    default: 'policies/terraform'
```

### reusable-dast-scan.yml

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier
    type: string
  scan-type:             # ZAP scan type
    type: string
    default: 'baseline'  # Options: baseline (~5min), api (~10min), full (~30min)
  target-url:            # Target URL to scan
    type: string
    default: 'http://localhost:8080'
  k8s-namespace:         # Namespace for port-forward
    type: string
    default: '{{APP_NAMESPACE}}'
  openapi-spec:          # OpenAPI spec URL (for api scan type)
    type: string
    default: ''

secrets:
  K8S_KUBECONFIG:        # Base64-encoded kubeconfig
    required: true
```

**ZAP baseline rules** (commonly suppressed in staging):

| Rule ID | Name | Reason for Suppression |
|---------|------|----------------------|
| 10010 | Cookie No HttpOnly Flag | Staging uses different cookie settings |
| 10011 | Cookie Without Secure Flag | Staging may not use HTTPS internally |
| 10015 | Re-examine Cache-control Directives | Not security-critical in staging |
| 10021 | X-Content-Type-Options Missing | Header may be set at ingress level |
| 10038 | CSP Header Not Set | CSP configured at WAF/ingress level |
| 90033 | Loosely Scoped Cookie | Expected in staging multi-service setup |

### reusable-sonarqube.yml

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier
    type: string
  working-directory:     # Service source root
    type: string
    default: '.'

secrets:
  SONAR_TOKEN:           # SonarQube authentication token
    required: true
  SONAR_HOST_URL:        # SonarQube server URL
    required: true
```

**sonar-project.properties** (per-service configuration):
```properties
sonar.projectKey={{ORG_NAME}}_{{SERVICE_NAME}}
sonar.organization={{ORG_NAME}}
sonar.sources=src
sonar.tests=src
sonar.test.inclusions=**/*.test.ts,**/*.spec.ts
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.qualitygate.wait=true
```

### reusable-defectdojo-import.yml

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier
    type: string
  scan-type:             # DefectDojo scan type name
    type: string         # e.g., 'Trivy Scan', 'Snyk Scan', 'ZAP Scan'
  scan-file:             # Path to scan result file
    type: string
  engagement-name:       # DefectDojo engagement name
    type: string
    default: 'CI/CD'

secrets:
  DEFECTDOJO_URL:        # DefectDojo instance URL
    required: true
  DEFECTDOJO_TOKEN:      # DefectDojo API token
    required: true
```

### reusable-dependency-track.yml

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier
    type: string
  sbom-file:             # Path to CycloneDX SBOM file
    type: string
    default: 'sbom.cyclonedx.json'
  project-version:       # Version string for Dependency-Track project
    type: string
    default: ''          # Uses git SHA when empty

secrets:
  DEPENDENCY_TRACK_URL:  # Dependency-Track instance URL
    required: true
  DEPENDENCY_TRACK_API_KEY: # Dependency-Track API key
    required: true
```

### reusable-vulnerability-sla.yml

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier
    type: string
  critical-sla-days:     # Max days for critical vulnerabilities
    type: number
    default: 7
  high-sla-days:         # Max days for high vulnerabilities
    type: number
    default: 30
  medium-sla-days:       # Max days for medium vulnerabilities
    type: number
    default: 90
  fail-on-sla-breach:    # Fail workflow if SLA is breached
    type: boolean
    default: true

secrets:
  DEFECTDOJO_URL:
    required: true
  DEFECTDOJO_TOKEN:
    required: true
```

## Composite Workflow Inputs

### reusable-security-with-defectdojo.yml

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier
    type: string
  service-type:          # nodejs or go
    type: string
    default: 'nodejs'
  auto-import:           # Automatically import results to DefectDojo
    type: boolean
    default: true

secrets:
  # Inherits all security workflow secrets plus DefectDojo secrets
```

This composite workflow:
1. Runs the appropriate security workflow (`reusable-go-security.yml` or `reusable-security.yml`)
2. Automatically imports all SARIF results into DefectDojo
3. Checks vulnerability SLA compliance

## Gosec Configuration

Gosec runs with all rules enabled by default. To suppress specific rules per-service:

```yaml
# In the service repository, create .gosec.conf or use build tags
# Common suppressions:
# G104 - Errors unhandled (for deferred close operations)
# G304 - File path provided as taint input (for config file loading)
```

## CodeQL Configuration

```yaml
# CodeQL uses security-extended and security-and-quality query suites
# This provides broader coverage than the default security suite
- uses: github/codeql-action/init@v3
  with:
    languages: go
    queries: security-extended,security-and-quality
```

## Trivy Configuration

```yaml
# Filesystem scan (SCA)
- uses: aquasecurity/trivy-action@0.28.0
  with:
    scan-type: 'fs'
    format: 'sarif'
    severity: 'CRITICAL,HIGH'
    vuln-type: 'library'
    scanners: 'vuln,secret,misconfig'  # Multi-scanner mode

# Container image scan
- uses: aquasecurity/trivy-action@0.28.0
  with:
    scan-type: 'image'
    format: 'sarif'
    severity: 'CRITICAL,HIGH'
    vuln-type: 'os,library'            # Both OS and library vulnerabilities
```

## Threagile Configuration

```yaml
# Threagile model structure (threagile-model.yaml)
threagile_version: 1.0.0

title: "{{APP_NAME}} Platform Threat Model"
author:
  name: "{{TEAM_NAME}}"

# Define trust boundaries, data assets, technical assets,
# communication links, and shared runtimes
# See templates/threat-modeling/threagile-model.yaml for full template
```

## Required Secrets Summary

| Secret | Used By | Purpose |
|--------|---------|---------|
| `SNYK_TOKEN` | Node.js security workflows | Snyk SAST + SCA |
| `SONAR_TOKEN` | SonarQube workflow | Code quality analysis |
| `SONAR_HOST_URL` | SonarQube workflow | SonarQube server URL |
| `DEFECTDOJO_URL` | DefectDojo import, SLA check | Vulnerability aggregation |
| `DEFECTDOJO_TOKEN` | DefectDojo import, SLA check | API authentication |
| `DEPENDENCY_TRACK_URL` | Dependency-Track workflow | SBOM analysis |
| `DEPENDENCY_TRACK_API_KEY` | Dependency-Track workflow | API authentication |
| `K8S_KUBECONFIG` | DAST scan (port-forward) | Cluster access |
| `NPM_TOKEN` | Node.js security workflows | Private package access |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Reusable Workflow Inputs
- Composite Workflow Inputs
- Gosec Configuration
- CodeQL Configuration

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
