# Exercise 3: Security Scanning

## Objective

Learn to scan container images for vulnerabilities, understand severity levels, fix critical issues, and integrate scanning into your development workflow.

## Prerequisites

- Completed Exercises 1 and 2
- Trivy installed (`brew install trivy` or see installation below)
- Basic understanding of CVEs and vulnerability scoring

## Installing Trivy

```bash
# macOS
brew install trivy

# Linux
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Docker (no installation required)
docker run aquasec/trivy image nginx:latest
```

## Scenario

You've inherited a container image that needs to be deployed to production. Before deployment, you must:
1. Scan for vulnerabilities
2. Understand and prioritize findings
3. Fix critical and high severity issues
4. Establish a baseline for ongoing monitoring

## Tasks

### Task 1: Scan a Vulnerable Image

Start by scanning an intentionally vulnerable image:

```bash
# Scan nginx:1.21 (older version with known vulnerabilities)
trivy image nginx:1.21

# Scan with severity filter
trivy image --severity HIGH,CRITICAL nginx:1.21

# Generate JSON report
trivy image --format json --output nginx-scan.json nginx:1.21

# Generate SARIF for GitHub integration
trivy image --format sarif --output nginx-scan.sarif nginx:1.21
```

**Questions to answer:**
- How many total vulnerabilities were found?
- How many are CRITICAL? HIGH? MEDIUM?
- What package has the most vulnerabilities?

### Task 2: Understand the Report

Analyze a vulnerability from the scan:

**Library      │ Vulnerability  │ Severity │       Fixed Version**

libssl3          │ CVE-2024-0727  │ CRITICAL │ 3.0.13-1~deb12u1


For each vulnerability:
1. Look up the CVE at https://nvd.nist.gov/vuln/detail/CVE-XXXX-XXXX
2. Understand the attack vector
3. Determine if your application is affected
4. Check if a fix is available

### Task 3: Fix Vulnerabilities by Updating Base Image

Create a Dockerfile that uses the latest patched base:

```dockerfile
# Before: vulnerable
FROM nginx:1.21

# After: patched
FROM nginx:1.25-alpine
```

Scan both and compare:

```bash
docker build -f Dockerfile.old -t app:vulnerable .
docker build -f Dockerfile.new -t app:patched .

trivy image --severity HIGH,CRITICAL app:vulnerable
trivy image --severity HIGH,CRITICAL app:patched
```

### Task 4: Create a Vulnerable Application for Practice

Create an intentionally vulnerable Node.js app to practice fixing issues:

**package.json** (with vulnerable dependencies)
```json
{
  "name": "vulnerable-app",
  "version": "1.0.0",
  "dependencies": {
    "express": "4.17.1",
    "lodash": "4.17.20",
    "axios": "0.21.1",
    "minimist": "1.2.5"
  }
}
```

**Dockerfile**
```dockerfile
FROM node:16
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["node", "server.js"]
```

Build and scan:
```bash
docker build -t vulnerable-app:1.0.0 .
trivy image vulnerable-app:1.0.0
```

### Task 5: Fix the Vulnerabilities

Update the application to fix vulnerabilities:

1. **Update base image** from `node:16` to `node:20-alpine`
2. **Update dependencies** to latest secure versions
3. **Remove unused dependencies**
4. **Use npm audit** to verify

```bash
# Inside your project directory
npm audit
npm audit fix
npm update

# Rebuild and rescan
docker build -t vulnerable-app:1.0.1 .
trivy image vulnerable-app:1.0.1
```

### Task 6: Scan Filesystem (CI Integration)

Scan your project files without building an image:

```bash
# Scan current directory
trivy fs .

# Scan with specific checks
trivy fs --scanners vuln,secret,config .

# Scan for secrets
trivy fs --scanners secret .

# Check IaC files (Dockerfile, Kubernetes manifests)
trivy config .
```

### Task 7: Generate Software Bill of Materials (SBOM)

```bash
# Generate CycloneDX SBOM
trivy image --format cyclonedx --output sbom.json myapp:1.0.0

# Generate SPDX SBOM
trivy image --format spdx-json --output sbom-spdx.json myapp:1.0.0

# Scan from SBOM
trivy sbom sbom.json
```

### Task 8: Set Up CI/CD Integration

Create a GitHub Actions workflow for automated scanning:

**.github/workflows/security-scan.yml**
```yaml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    # Run daily at midnight
    - cron: '0 0 * * *'

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy scan results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Fail on critical vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          exit-code: '1'
          severity: 'CRITICAL'

  filesystem-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Trivy filesystem scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'HIGH,CRITICAL'

      - name: Scan for secrets
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scanners: 'secret'
          scan-ref: '.'
```

## Validation

Create a scanning checklist:

```bash
# Full scan with all checks
trivy image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  myapp:1.0.0

# Expected: Exit code 0 (no HIGH/CRITICAL fixable vulnerabilities)
```

## Success Criteria

- [ ] Successfully scanned multiple images
- [ ] Identified and understood vulnerability severities
- [ ] Fixed vulnerabilities by updating base image
- [ ] Fixed vulnerabilities by updating dependencies
- [ ] Generated SBOM for your application
- [ ] Created CI/CD workflow for automated scanning
- [ ] Achieved zero CRITICAL vulnerabilities

## Solution

<details>
<summary>Click to reveal fixed Dockerfile</summary>

```dockerfile
# Dockerfile - Secure version

FROM node:20-alpine

# Add security metadata
LABEL org.opencontainers.image.source="https://github.com/your-org/app" \
      org.opencontainers.image.description="Secure application" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Copy and install dependencies
COPY package*.json ./
RUN npm ci --only=production && \
    npm cache clean --force && \
    # Remove npm to reduce attack surface
    rm -rf /usr/local/lib/node_modules/npm

# Copy application
COPY --chown=appuser:appgroup . .

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
```

</details>

<details>
<summary>Click to reveal fixed package.json</summary>

```json
{
  "name": "secure-app",
  "version": "1.0.1",
  "dependencies": {
    "express": "^4.18.2",
    "lodash": "^4.17.21",
    "axios": "^1.6.0"
  }
}
```

</details>

## Severity Guidelines

| Severity | Action | Timeline |
|----------|--------|----------|
| CRITICAL | Must fix before deployment | Immediate |
| HIGH | Should fix before deployment | Within 1 week |
| MEDIUM | Fix in next release cycle | Within 1 month |
| LOW | Track and monitor | As resources allow |

## Bonus Challenges

1. **Compare scanners**: Try Grype, Snyk, or Clair and compare results
2. **Create ignore file**: Use `.trivyignore` for accepted risks
3. **Policy as Code**: Use OPA to enforce vulnerability policies

## Next Exercise

Continue to [Exercise 4: Distroless Migration](01-container-fundamentals-exercises-04-distroless.md) to learn about minimal container images.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Installing Trivy
- Severity Guidelines
- Scan a Vulnerable Image
- Understand the Report

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Kubernetes schedules the pod."* |
| ✓ | *"The scheduler watches for pods with no `nodeName`, filters nodes by predicates, scores the survivors, and writes `nodeName` into the pod spec. The kubelet on that node is watching the API for pods bound to it, and starts the containers."* |

**Trace it:** `kubectl apply -f pod.yaml` → a running container. Name every component that acts, in order, and what each one writes.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — one weekend, and "the control plane" stops being a word.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#kubernetes)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
