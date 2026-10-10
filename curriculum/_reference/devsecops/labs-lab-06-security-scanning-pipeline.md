# Lab 6: Security Scanning Pipeline

## Objectives

- Implement SAST scanning with Semgrep and CodeQL
- Configure SCA scanning with Trivy and Snyk
- Set up DAST scanning with OWASP ZAP
- Build a complete security pipeline in GitHub Actions

## Prerequisites

- GitHub repository with code access
- Docker installed
- Node.js or Python application to scan
- API keys for Snyk (optional)

## Duration

3 hours

## Lab Environment Setup

```bash
# Create lab directory with sample application
mkdir -p ~/security-lab/scanning
cd ~/security-lab/scanning

# Create sample vulnerable application
mkdir -p src
cat > src/app.py << 'EOF'
from flask import Flask, request, render_template_string
import sqlite3
import subprocess
import os

app = Flask(__name__)

# Vulnerable: SQL Injection
@app.route('/user')
def get_user():
    user_id = request.args.get('id')
    conn = sqlite3.connect('users.db')
    cursor = conn.cursor()
    # VULNERABLE: SQL Injection
    cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
    return str(cursor.fetchone())

# Vulnerable: Command Injection
@app.route('/ping')
def ping():
    host = request.args.get('host')
    # VULNERABLE: Command Injection
    result = subprocess.check_output(f"ping -c 1 {host}", shell=True)
    return result

# Vulnerable: XSS
@app.route('/greet')
def greet():
    name = request.args.get('name')
    # VULNERABLE: XSS
    return render_template_string(f"<h1>Hello {name}!</h1>")

# Vulnerable: Path Traversal
@app.route('/file')
def read_file():
    filename = request.args.get('name')
    # VULNERABLE: Path Traversal
    with open(f"/app/files/{filename}", 'r') as f:
        return f.read()

# Vulnerable: Hardcoded credentials
DB_PASSWORD = "admin123"  # VULNERABLE: Hardcoded secret
API_KEY = "sk-1234567890abcdef"  # VULNERABLE: Hardcoded secret

if __name__ == '__main__':
    app.run(debug=True)
EOF

# Create requirements.txt with known vulnerable packages
cat > requirements.txt << 'EOF'
flask==2.0.0
requests==2.25.0
pyyaml==5.3.1
jinja2==2.11.3
urllib3==1.26.4
EOF

# Create package.json for Node.js scanning
cat > package.json << 'EOF'
{
  "name": "vulnerable-app",
  "version": "1.0.0",
  "dependencies": {
    "lodash": "4.17.19",
    "express": "4.17.1",
    "moment": "2.29.1",
    "axios": "0.21.1"
  }
}
EOF
```

## Part 1: SAST with Semgrep (45 minutes)

### Task 1.1: Install and Configure Semgrep

```bash
# Install Semgrep
pip install semgrep

# Run basic scan
semgrep scan --config auto src/

# Run with specific rulesets
semgrep scan \
  --config p/security-audit \
  --config p/python \
  --config p/secrets \
  src/

# Output JSON report
semgrep scan \
  --config p/security-audit \
  --json \
  --output semgrep-results.json \
  src/
```

### Task 1.2: Create Custom Semgrep Rules

```yaml
# semgrep-rules/custom-rules.yaml
rules:
  - id: sql-injection-formatted-string
    patterns:
      - pattern: cursor.execute(f"...")
      - pattern: cursor.execute("..." % ...)
      - pattern: cursor.execute("..." + ...)
    message: |
      Possible SQL injection vulnerability. Use parameterized queries instead.
    languages: [python]
    severity: ERROR
    metadata:
      cwe: "CWE-89"
      owasp: "A03:2021 - Injection"

  - id: command-injection-subprocess
    patterns:
      - pattern: subprocess.$FUNC(..., shell=True, ...)
    message: |
      Command injection vulnerability. Avoid shell=True with user input.
    languages: [python]
    severity: ERROR
    metadata:
      cwe: "CWE-78"
      owasp: "A03:2021 - Injection"

  - id: xss-flask-template-string
    pattern: render_template_string($EXPR)
    message: |
      XSS vulnerability. User input in template string can lead to XSS.
    languages: [python]
    severity: ERROR
    metadata:
      cwe: "CWE-79"
      owasp: "A03:2021 - Injection"

  - id: hardcoded-credentials
    patterns:
      - pattern-regex: (PASSWORD|SECRET|API_KEY|TOKEN)\s*=\s*["'][^"']+["']
    paths:
      include:
        - "*.py"
        - "*.js"
        - "*.ts"
    message: |
      Hardcoded credentials detected. Use environment variables or secrets management.
    languages: [python, javascript, typescript]
    severity: WARNING
    metadata:
      cwe: "CWE-798"
      owasp: "A07:2021 - Identification and Authentication Failures"

  - id: path-traversal
    patterns:
      - pattern: open($PATH, ...)
      - pattern-not: open("/...", ...)
    message: |
      Potential path traversal vulnerability. Validate file paths.
    languages: [python]
    severity: WARNING
    metadata:
      cwe: "CWE-22"
      owasp: "A01:2021 - Broken Access Control"
```

```bash
# Run with custom rules
semgrep scan \
  --config semgrep-rules/custom-rules.yaml \
  --config p/security-audit \
  src/

# Generate SARIF output for GitHub
semgrep scan \
  --config p/security-audit \
  --sarif \
  --output semgrep.sarif \
  src/
```

### Task 1.3: Configure Semgrep CI

```yaml
# .github/workflows/semgrep.yml
name: Semgrep SAST

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  semgrep:
    runs-on: ubuntu-latest
    container:
      image: returntocorp/semgrep

    steps:
    - uses: actions/checkout@v4

    - name: Run Semgrep
      run: |
        semgrep ci \
          --config p/security-audit \
          --config p/secrets \
          --sarif --output results.sarif

    - name: Upload SARIF
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: results.sarif
```

## Part 2: SAST with CodeQL (45 minutes)

### Task 2.1: Initialize CodeQL

```bash
# Install CodeQL CLI
wget https://github.com/github/codeql-cli-binaries/releases/latest/download/codeql-linux64.zip
unzip codeql-linux64.zip

# Clone CodeQL queries
git clone https://github.com/github/codeql.git codeql-queries

# Create CodeQL database
./codeql/codeql database create \
  --language=python \
  --source-root=src/ \
  codeql-db

# Run analysis
./codeql/codeql database analyze \
  codeql-db \
  codeql-queries/python/ql/src/Security \
  --format=sarif-latest \
  --output=codeql-results.sarif
```

### Task 2.2: Custom CodeQL Query

```ql
// queries/sql-injection.ql
/**
 * @name SQL Injection
 * @description Building SQL queries from user-controlled sources is vulnerable to injection
 * @kind path-problem
 * @problem.severity error
 * @security-severity 9.8
 * @precision high
 * @id py/sql-injection
 * @tags security
 *       external/cwe/cwe-089
 */

import python
import semmle.python.security.dataflow.SqlInjection
import semmle.python.ApiGraphs

from SqlInjectionFlowConfig config, DataFlow::PathNode source, DataFlow::PathNode sink
where config.hasFlowPath(source, sink)
select sink.getNode(), source, sink, "SQL query depends on $@.", source.getNode(), "user-provided value"
```

### Task 2.3: GitHub Actions CodeQL

```yaml
# .github/workflows/codeql.yml
name: CodeQL Analysis

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 0 * * 0'  # Weekly

jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      packages: read
      actions: read
      contents: read

    strategy:
      fail-fast: false
      matrix:
        language: ['python', 'javascript']

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Initialize CodeQL
      uses: github/codeql-action/init@v2
      with:
        languages: ${{ matrix.language }}
        queries: security-extended

    - name: Autobuild
      uses: github/codeql-action/autobuild@v2

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v2
      with:
        category: "/language:${{ matrix.language }}"
```

## Part 3: SCA Scanning (45 minutes)

### Task 3.1: Scan with Trivy

```bash
# Scan filesystem for vulnerabilities
trivy fs --severity HIGH,CRITICAL .

# Scan with specific formats
trivy fs \
  --format json \
  --output trivy-fs.json \
  --severity CRITICAL,HIGH \
  .

# Generate SBOM
trivy fs --format spdx-json --output sbom.spdx.json .

# Scan container image
trivy image myapp:latest

# Scan specific file types
trivy fs --scanners vuln,secret,config .
```

### Task 3.2: Scan with Snyk

```bash
# Authenticate with Snyk
snyk auth

# Test for vulnerabilities
snyk test

# Test with severity threshold
snyk test --severity-threshold=high

# Test container image
snyk container test myapp:latest

# Monitor project
snyk monitor

# Generate JSON report
snyk test --json > snyk-results.json

# Test IaC
snyk iac test terraform/
```

### Task 3.3: Dependency-Check

```bash
# Run OWASP Dependency-Check
docker run --rm \
  -v $(pwd):/src \
  -v $(pwd)/dc-data:/usr/share/dependency-check/data \
  owasp/dependency-check \
  --scan /src \
  --format JSON \
  --out /src/dependency-check-report.json

# Analyze results
cat dependency-check-report.json | jq '.dependencies[] | select(.vulnerabilities != null) | {name: .fileName, vulns: [.vulnerabilities[].name]}'
```

### Task 3.4: Generate and Analyze SBOM

```bash
# Install Syft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Generate SBOM
syft . -o spdx-json > sbom.spdx.json
syft . -o cyclonedx-json > sbom.cdx.json

# Analyze SBOM for vulnerabilities
grype sbom:./sbom.spdx.json

# Upload to Dependency-Track (if available)
curl -X POST \
  -H "X-Api-Key: $DTRACK_API_KEY" \
  -H "Content-Type: application/vnd.cyclonedx+json" \
  -d @sbom.cdx.json \
  https://dependency-track.company.com/api/v1/bom
```

## Part 4: DAST with OWASP ZAP (45 minutes)

### Task 4.1: Run ZAP Baseline Scan

```bash
# Start vulnerable application
docker run -d -p 8080:8080 --name juice-shop bkimminich/juice-shop

# Run ZAP baseline scan
docker run --rm -t \
  --network host \
  -v $(pwd):/zap/wrk:rw \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py \
  -t http://localhost:8080 \
  -r zap-baseline-report.html \
  -J zap-baseline-report.json
```

### Task 4.2: Run ZAP Full Scan

```bash
# Run full active scan
docker run --rm -t \
  --network host \
  -v $(pwd):/zap/wrk:rw \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-full-scan.py \
  -t http://localhost:8080 \
  -r zap-full-report.html \
  -J zap-full-report.json \
  -c zap-rules.conf
```

### Task 4.3: ZAP with API Scanning

```yaml
# zap-api-scan.yaml
env:
  contexts:
    - name: "API Context"
      urls:
        - "http://localhost:8080/api/*"
      authentication:
        method: "http"
        parameters:
          loginUrl: "http://localhost:8080/api/login"
          loginRequestData: "username={%username%}&password={%password%}"
        verification:
          method: "response"
          loggedInRegex: "\\Qtoken\\E"

jobs:
  - type: openapi
    parameters:
      apiUrl: "http://localhost:8080/api/swagger.json"
      context: "API Context"

  - type: activeScan
    parameters:
      context: "API Context"
      policy: "API-Scan"

  - type: report
    parameters:
      template: "traditional-html"
      reportDir: "/zap/wrk"
      reportFile: "zap-api-report.html"
```

```bash
# Run API scan
docker run --rm -t \
  --network host \
  -v $(pwd):/zap/wrk:rw \
  ghcr.io/zaproxy/zaproxy:stable \
  zap.sh -cmd \
  -autorun /zap/wrk/zap-api-scan.yaml
```

### Task 4.4: Nuclei Scanning

```bash
# Install Nuclei
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# Run with default templates
nuclei -u http://localhost:8080 -o nuclei-results.txt

# Run with specific templates
nuclei -u http://localhost:8080 \
  -t cves/ \
  -t vulnerabilities/ \
  -t misconfiguration/ \
  -severity critical,high \
  -json -o nuclei-results.json

# Run against multiple targets
echo "http://localhost:8080" > targets.txt
nuclei -l targets.txt -t cves/ -o nuclei-cves.txt
```

## Part 5: Complete Security Pipeline (45 minutes)

### Task 5.1: Unified Security Pipeline

```yaml
# .github/workflows/security-pipeline.yml
name: Security Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 0 * * *'  # Daily

env:
  FAIL_ON_CRITICAL: true
  FAIL_ON_HIGH: false

jobs:
  # SAST - Static Analysis
  sast:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Run Semgrep
      uses: returntocorp/semgrep-action@v1
      with:
        config: >-
          p/security-audit
          p/secrets
          p/owasp-top-ten

    - name: Initialize CodeQL
      uses: github/codeql-action/init@v2
      with:
        languages: python, javascript

    - name: Autobuild
      uses: github/codeql-action/autobuild@v2

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v2

  # SCA - Dependency Scanning
  sca:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'

    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

    - name: Generate SBOM
      uses: anchore/sbom-action@v0
      with:
        format: spdx-json
        output-file: sbom.spdx.json

    - name: Upload SBOM
      uses: actions/upload-artifact@v3
      with:
        name: sbom
        path: sbom.spdx.json

  # Container Security
  container-scan:
    runs-on: ubuntu-latest
    needs: [sast, sca]
    steps:
    - uses: actions/checkout@v4

    - name: Build image
      run: docker build -t app:${{ github.sha }} .

    - name: Scan image with Trivy
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'app:${{ github.sha }}'
        format: 'sarif'
        output: 'trivy-image.sarif'

    - name: Run Dockle
      uses: erzz/dockle-action@v1
      with:
        image: 'app:${{ github.sha }}'
        failure-threshold: high

  # Infrastructure Security
  iac-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Run Checkov
      uses: bridgecrewio/checkov-action@master
      with:
        directory: terraform/
        framework: terraform
        output_format: sarif
        output_file_path: checkov.sarif

    - name: Run tfsec
      uses: aquasecurity/tfsec-action@v1.0.0
      with:
        working_directory: terraform/

  # DAST - Dynamic Testing (on staging)
  dast:
    runs-on: ubuntu-latest
    needs: [container-scan]
    if: github.ref == 'refs/heads/develop'
    environment: staging
    steps:
    - uses: actions/checkout@v4

    - name: Deploy to staging
      run: |
        # Deploy application to staging
        echo "Deploying to staging..."

    - name: Run ZAP Scan
      uses: zaproxy/action-baseline@v0.10.0
      with:
        target: 'https://staging.example.com'
        rules_file_name: '.zap/rules.tsv'

    - name: Run Nuclei
      uses: projectdiscovery/nuclei-action@main
      with:
        target: 'https://staging.example.com'
        templates: 'cves,vulnerabilities'
        output: nuclei-results.txt

  # Security Gate
  security-gate:
    runs-on: ubuntu-latest
    needs: [sast, sca, container-scan, iac-scan]
    steps:
    - name: Download scan results
      uses: actions/download-artifact@v3

    - name: Evaluate security posture
      run: |
        # Parse results and fail if thresholds exceeded
        python scripts/security-gate.py \
          --sarif "**/*.sarif" \
          --fail-on-critical ${{ env.FAIL_ON_CRITICAL }} \
          --fail-on-high ${{ env.FAIL_ON_HIGH }}
```

## Verification

Complete the following checklist:

- [ ] Ran Semgrep and identified SQL injection
- [ ] Created custom Semgrep rules
- [ ] Set up CodeQL analysis
- [ ] Scanned dependencies with Trivy
- [ ] Generated SBOM in SPDX format
- [ ] Ran OWASP ZAP baseline scan
- [ ] Ran Nuclei vulnerability scan
- [ ] Created complete security pipeline
- [ ] Configured security gates

## Challenge Tasks

1. **DefectDojo Integration**: Set up DefectDojo and import scan results for centralized tracking

2. **Custom Security Gate**: Create a sophisticated security gate that considers vulnerability age and business context

3. **Automated Remediation**: Create automated PRs that fix known vulnerable dependencies

## Summary

In this lab, you:
- Implemented SAST with Semgrep and CodeQL
- Created custom security scanning rules
- Configured SCA with Trivy and generated SBOMs
- Set up DAST with OWASP ZAP and Nuclei
- Built a comprehensive security pipeline

## Next Steps

- Lab 7: Identity and Access Management
- Review OWASP Testing Guide
- Study DevSecOps Maturity Model

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- SAST with Semgrep
- SAST with CodeQL
- SCA Scanning
- DAST with OWASP ZAP

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
