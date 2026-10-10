# Lab 12: DevSecOps Implementation

## Objectives

- Build a complete DevSecOps pipeline
- Implement security gates and quality controls
- Create secure-by-default templates
- Establish security metrics and dashboards

## Prerequisites

- GitHub repository with CI/CD pipeline
- Container registry access
- Kubernetes cluster
- Security scanning tools installed

## Duration

3 hours

## Part 1: Complete DevSecOps Pipeline (60 minutes)

### Task 1.1: Full Security Pipeline

```yaml
# .github/workflows/devsecops-pipeline.yml
name: DevSecOps Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # Stage 1: Secret Detection
  secret-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: GitLeaks Scan
      uses: gitleaks/gitleaks-action@v2
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

    - name: TruffleHog Scan
      uses: trufflesecurity/trufflehog@main
      with:
        path: ./
        base: ${{ github.event.repository.default_branch }}
        extra_args: --only-verified

  # Stage 2: SAST
  sast:
    runs-on: ubuntu-latest
    needs: secret-scan
    steps:
    - uses: actions/checkout@v4

    - name: Semgrep SAST
      uses: returntocorp/semgrep-action@v1
      with:
        config: >-
          p/security-audit
          p/secrets
          p/owasp-top-ten
        generateSarif: "1"

    - name: Upload SARIF
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: semgrep.sarif

    - name: CodeQL Analysis
      uses: github/codeql-action/init@v2
      with:
        languages: javascript, python

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v2

  # Stage 3: SCA
  sca:
    runs-on: ubuntu-latest
    needs: secret-scan
    steps:
    - uses: actions/checkout@v4

    - name: Dependency Check
      uses: dependency-check/Dependency-Check_Action@main
      with:
        project: '${{ github.repository }}'
        path: '.'
        format: 'SARIF'
        args: >
          --failOnCVSS 7
          --enableRetired

    - name: Snyk SCA
      uses: snyk/actions/node@master
      env:
        SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
      with:
        args: --severity-threshold=high

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

  # Stage 4: Build & Container Scan
  build-scan:
    runs-on: ubuntu-latest
    needs: [sast, sca]
    outputs:
      digest: ${{ steps.build.outputs.digest }}
    steps:
    - uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Login to Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Build Image
      id: build
      uses: docker/build-push-action@v5
      with:
        context: .
        push: false
        load: true
        tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

    - name: Trivy Container Scan
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'
        exit-code: '1'

    - name: Grype Scan
      uses: anchore/scan-action@v3
      with:
        image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
        fail-build: true
        severity-cutoff: high

    - name: Push Image
      if: github.event_name == 'push'
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: |
          ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest

  # Stage 5: Sign Image
  sign:
    runs-on: ubuntu-latest
    needs: build-scan
    if: github.event_name == 'push'
    steps:
    - name: Install Cosign
      uses: sigstore/cosign-installer@v3

    - name: Login to Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Sign Image
      env:
        COSIGN_EXPERIMENTAL: "true"
      run: |
        cosign sign --yes ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build-scan.outputs.digest }}

  # Stage 6: Deploy to Staging
  deploy-staging:
    runs-on: ubuntu-latest
    needs: sign
    environment: staging
    if: github.event_name == 'push'
    steps:
    - uses: actions/checkout@v4

    - name: Setup kubectl
      uses: azure/setup-kubectl@v3

    - name: Deploy to Staging
      run: |
        kubectl set image deployment/app \
          app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
          -n staging

  # Stage 7: DAST
  dast:
    runs-on: ubuntu-latest
    needs: deploy-staging
    steps:
    - uses: actions/checkout@v4

    - name: Wait for deployment
      run: sleep 60

    - name: OWASP ZAP Scan
      uses: zaproxy/action-full-scan@v0.8.0
      with:
        target: 'https://staging.example.com'
        rules_file_name: '.zap/rules.tsv'
        allow_issue_writing: false

    - name: Nuclei Scan
      uses: projectdiscovery/nuclei-action@main
      with:
        target: https://staging.example.com
        templates: cves,vulnerabilities,misconfigurations
        output: nuclei-results.txt

  # Stage 8: Compliance Check
  compliance:
    runs-on: ubuntu-latest
    needs: deploy-staging
    steps:
    - uses: actions/checkout@v4

    - name: InSpec Compliance
      run: |
        docker run --rm \
          -v $(pwd)/compliance:/share \
          chef/inspec exec /share/profiles/cis-kubernetes \
          --reporter json:compliance-results.json

    - name: Upload Compliance Results
      uses: actions/upload-artifact@v3
      with:
        name: compliance-results
        path: compliance-results.json

  # Stage 9: Security Gate
  security-gate:
    runs-on: ubuntu-latest
    needs: [dast, compliance]
    steps:
    - name: Download all artifacts
      uses: actions/download-artifact@v3

    - name: Evaluate Security Gate
      run: |
        python scripts/security-gate.py \
          --sast-results sast-results/ \
          --sca-results sca-results/ \
          --dast-results dast-results/ \
          --compliance-results compliance-results/ \
          --fail-on critical \
          --output gate-results.json

    - name: Notify on Failure
      if: failure()
      uses: slackapi/slack-github-action@v1
      with:
        payload: |
          {
            "text": "Security Gate Failed for ${{ github.repository }}",
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": ":x: *Security Gate Failed*\nRepository: ${{ github.repository }}\nBranch: ${{ github.ref }}"
                }
              }
            ]
          }
      env:
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

  # Stage 10: Deploy to Production
  deploy-production:
    runs-on: ubuntu-latest
    needs: security-gate
    environment: production
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v4

    - name: Deploy to Production
      run: |
        kubectl set image deployment/app \
          app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
          -n production
```

### Task 1.2: Security Gate Implementation

```python
#!/usr/bin/env python3
# scripts/security-gate.py

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List
from dataclasses import dataclass
from enum import Enum

class Severity(Enum):
    CRITICAL = 4
    HIGH = 3
    MEDIUM = 2
    LOW = 1
    INFO = 0

@dataclass
class Finding:
    tool: str
    severity: Severity
    title: str
    description: str
    file: str = ""
    line: int = 0

class SecurityGate:
    def __init__(self, fail_on: Severity = Severity.CRITICAL):
        self.fail_on = fail_on
        self.findings: List[Finding] = []
        self.thresholds = {
            Severity.CRITICAL: 0,
            Severity.HIGH: 5,
            Severity.MEDIUM: 20,
            Severity.LOW: 50
        }

    def parse_sarif(self, sarif_file: Path, tool: str) -> List[Finding]:
        """Parse SARIF format results."""
        findings = []
        with open(sarif_file) as f:
            data = json.load(f)

        for run in data.get('runs', []):
            for result in run.get('results', []):
                severity_map = {
                    'error': Severity.HIGH,
                    'warning': Severity.MEDIUM,
                    'note': Severity.LOW
                }
                level = result.get('level', 'warning')
                severity = severity_map.get(level, Severity.MEDIUM)

                # Check for security-severity tag
                tags = result.get('properties', {}).get('tags', [])
                if 'security-severity' in result.get('properties', {}):
                    score = float(result['properties']['security-severity'])
                    if score >= 9.0:
                        severity = Severity.CRITICAL
                    elif score >= 7.0:
                        severity = Severity.HIGH

                location = result.get('locations', [{}])[0]
                physical = location.get('physicalLocation', {})

                findings.append(Finding(
                    tool=tool,
                    severity=severity,
                    title=result.get('ruleId', 'Unknown'),
                    description=result.get('message', {}).get('text', ''),
                    file=physical.get('artifactLocation', {}).get('uri', ''),
                    line=physical.get('region', {}).get('startLine', 0)
                ))

        return findings

    def parse_trivy(self, trivy_file: Path) -> List[Finding]:
        """Parse Trivy JSON results."""
        findings = []
        with open(trivy_file) as f:
            data = json.load(f)

        for result in data.get('Results', []):
            for vuln in result.get('Vulnerabilities', []):
                severity_map = {
                    'CRITICAL': Severity.CRITICAL,
                    'HIGH': Severity.HIGH,
                    'MEDIUM': Severity.MEDIUM,
                    'LOW': Severity.LOW
                }
                findings.append(Finding(
                    tool='trivy',
                    severity=severity_map.get(vuln.get('Severity', 'MEDIUM'), Severity.MEDIUM),
                    title=vuln.get('VulnerabilityID', ''),
                    description=vuln.get('Title', ''),
                    file=vuln.get('PkgName', '')
                ))

        return findings

    def load_results(self, results_dir: Path, tool: str):
        """Load results from a directory."""
        for file in results_dir.glob('*.sarif'):
            self.findings.extend(self.parse_sarif(file, tool))
        for file in results_dir.glob('*.json'):
            if 'trivy' in file.name:
                self.findings.extend(self.parse_trivy(file))

    def evaluate(self) -> Dict:
        """Evaluate security gate."""
        counts = {s: 0 for s in Severity}
        for finding in self.findings:
            counts[finding.severity] += 1

        passed = True
        failures = []

        for severity, count in counts.items():
            threshold = self.thresholds.get(severity, 0)
            if count > threshold:
                passed = False
                failures.append(f"{severity.name}: {count} (threshold: {threshold})")

        # Check fail_on severity
        for severity in Severity:
            if severity.value >= self.fail_on.value:
                if counts[severity] > 0:
                    passed = False
                    failures.append(f"Found {counts[severity]} {severity.name} findings")

        return {
            'passed': passed,
            'findings_count': counts,
            'total_findings': len(self.findings),
            'failures': failures,
            'findings': [
                {
                    'tool': f.tool,
                    'severity': f.severity.name,
                    'title': f.title,
                    'file': f.file
                }
                for f in self.findings
            ]
        }

def main():
    parser = argparse.ArgumentParser(description='Security Gate Evaluator')
    parser.add_argument('--sast-results', type=Path, help='SAST results directory')
    parser.add_argument('--sca-results', type=Path, help='SCA results directory')
    parser.add_argument('--dast-results', type=Path, help='DAST results directory')
    parser.add_argument('--compliance-results', type=Path, help='Compliance results directory')
    parser.add_argument('--fail-on', choices=['critical', 'high', 'medium', 'low'],
                        default='critical', help='Fail on this severity or higher')
    parser.add_argument('--output', type=Path, default='gate-results.json',
                        help='Output file')
    args = parser.parse_args()

    severity_map = {
        'critical': Severity.CRITICAL,
        'high': Severity.HIGH,
        'medium': Severity.MEDIUM,
        'low': Severity.LOW
    }

    gate = SecurityGate(fail_on=severity_map[args.fail_on])

    if args.sast_results and args.sast_results.exists():
        gate.load_results(args.sast_results, 'sast')

    if args.sca_results and args.sca_results.exists():
        gate.load_results(args.sca_results, 'sca')

    if args.dast_results and args.dast_results.exists():
        gate.load_results(args.dast_results, 'dast')

    results = gate.evaluate()

    with open(args.output, 'w') as f:
        json.dump(results, f, indent=2)

    print(f"Security Gate: {'PASSED' if results['passed'] else 'FAILED'}")
    print(f"Total Findings: {results['total_findings']}")
    for severity, count in results['findings_count'].items():
        print(f"  {severity.name}: {count}")

    if not results['passed']:
        print("\nFailures:")
        for failure in results['failures']:
            print(f"  - {failure}")
        sys.exit(1)

if __name__ == '__main__':
    main()
```

## Part 2: Secure-by-Default Templates (45 minutes)

### Task 2.1: Golden Path Templates

```yaml
# templates/secure-deployment/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: APP_NAME
  labels:
    app: APP_NAME
    security.company.com/scanned: "true"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: APP_NAME
  template:
    metadata:
      labels:
        app: APP_NAME
      annotations:
        container.apparmor.security.beta.kubernetes.io/app: runtime/default
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10000
        runAsGroup: 10000
        fsGroup: 10000
        seccompProfile:
          type: RuntimeDefault
      serviceAccountName: APP_NAME
      automountServiceAccountToken: false
      containers:
      - name: app
        image: IMAGE_PLACEHOLDER
        imagePullPolicy: Always
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
              - ALL
        ports:
        - containerPort: 8080
          protocol: TCP
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /var/cache
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: APP_NAME
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: APP_NAME
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: APP_NAME
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: APP_NAME
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/APP_NAME-role
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: APP_NAME
spec:
  podSelector:
    matchLabels:
      app: APP_NAME
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
```

### Task 2.2: Secure Dockerfile Template

```dockerfile
# templates/secure-dockerfile/Dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder

# Security: Run as non-root during build
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Security: Copy package files first for better caching
COPY --chown=appuser:appgroup package*.json ./

# Security: Use npm ci for reproducible builds
RUN npm ci --only=production && \
    npm cache clean --force

COPY --chown=appuser:appgroup . .

RUN npm run build

# Stage 2: Production
FROM gcr.io/distroless/nodejs20-debian12:nonroot

# Security: Labels for tracking
LABEL org.opencontainers.image.source="https://github.com/company/app"
LABEL org.opencontainers.image.description="Secure application image"
LABEL security.scan.required="true"

WORKDIR /app

# Copy only production artifacts
COPY --from=builder --chown=nonroot:nonroot /app/dist ./dist
COPY --from=builder --chown=nonroot:nonroot /app/node_modules ./node_modules
COPY --from=builder --chown=nonroot:nonroot /app/package.json ./

# Security: Expose non-privileged port
EXPOSE 8080

# Security: Use numeric user ID
USER 65532

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/nodejs/bin/node", "-e", "require('http').get('http://localhost:8080/health')"]

CMD ["dist/server.js"]
```

### Task 2.3: Template Generator Script

```python
#!/usr/bin/env python3
# scripts/generate-secure-app.py

import argparse
import os
import shutil
from pathlib import Path
from jinja2 import Environment, FileSystemLoader

class SecureAppGenerator:
    def __init__(self, templates_dir: str = "templates"):
        self.templates_dir = Path(templates_dir)
        self.env = Environment(loader=FileSystemLoader(str(self.templates_dir)))

    def generate(self, app_name: str, output_dir: str, options: dict):
        """Generate secure application scaffold."""
        output = Path(output_dir) / app_name
        output.mkdir(parents=True, exist_ok=True)

        # Generate Kubernetes manifests
        self._generate_k8s_manifests(app_name, output, options)

        # Generate Dockerfile
        self._generate_dockerfile(app_name, output, options)

        # Generate CI/CD pipeline
        self._generate_pipeline(app_name, output, options)

        # Generate security policies
        self._generate_security_policies(app_name, output, options)

        print(f"Generated secure application scaffold in {output}")

    def _generate_k8s_manifests(self, app_name: str, output: Path, options: dict):
        """Generate Kubernetes manifests."""
        k8s_dir = output / "k8s"
        k8s_dir.mkdir(exist_ok=True)

        # Deployment
        template = self.env.get_template("secure-deployment/base/deployment.yaml")
        rendered = template.render(
            app_name=app_name,
            namespace=options.get('namespace', 'default'),
            replicas=options.get('replicas', 3),
            image=options.get('image', f"ghcr.io/company/{app_name}:latest")
        )
        (k8s_dir / "deployment.yaml").write_text(rendered)

        # Kyverno policies
        self._generate_kyverno_policies(app_name, k8s_dir, options)

    def _generate_kyverno_policies(self, app_name: str, k8s_dir: Path, options: dict):
        """Generate Kyverno policies for the application."""
        policies = f"""
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: {app_name}-security
  namespace: {options.get('namespace', 'default')}
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: require-labels
    match:
      any:
      - resources:
          kinds: [Pod]
          selector:
            matchLabels:
              app: {app_name}
    validate:
      message: "Required labels missing"
      pattern:
        metadata:
          labels:
            app: {app_name}
            version: "?*"
            owner: "?*"
  - name: restrict-image-registries
    match:
      any:
      - resources:
          kinds: [Pod]
    validate:
      message: "Images must come from approved registries"
      pattern:
        spec:
          containers:
          - image: "ghcr.io/company/* | gcr.io/company/*"
"""
        (k8s_dir / "kyverno-policy.yaml").write_text(policies)

    def _generate_dockerfile(self, app_name: str, output: Path, options: dict):
        """Generate secure Dockerfile."""
        dockerfile = output / "Dockerfile"
        template = self.env.get_template("secure-dockerfile/Dockerfile")
        rendered = template.render(
            app_name=app_name,
            base_image=options.get('base_image', 'node:20-alpine'),
            port=options.get('port', 8080)
        )
        dockerfile.write_text(rendered)

    def _generate_pipeline(self, app_name: str, output: Path, options: dict):
        """Generate CI/CD pipeline."""
        workflows_dir = output / ".github" / "workflows"
        workflows_dir.mkdir(parents=True, exist_ok=True)

        template = self.env.get_template("devsecops-pipeline.yml")
        rendered = template.render(
            app_name=app_name,
            registry=options.get('registry', 'ghcr.io'),
            enable_dast=options.get('enable_dast', True)
        )
        (workflows_dir / "devsecops.yml").write_text(rendered)

    def _generate_security_policies(self, app_name: str, output: Path, options: dict):
        """Generate security policy files."""
        security_dir = output / "security"
        security_dir.mkdir(exist_ok=True)

        # Semgrep config
        semgrep_config = """
rules:
  - id: custom-sql-injection
    patterns:
      - pattern: $QUERY = "..." + $INPUT
      - pattern-not: $QUERY = "..." + sanitize($INPUT)
    message: Potential SQL injection
    languages: [python, javascript]
    severity: ERROR
"""
        (security_dir / ".semgrep.yml").write_text(semgrep_config)

        # Security requirements
        security_requirements = f"""
# Security Requirements for {app_name}

## Authentication
- [ ] All endpoints require authentication except /health
- [ ] JWT tokens with short expiration (15 min)
- [ ] Refresh tokens stored securely

## Authorization
- [ ] RBAC implemented for all resources
- [ ] Principle of least privilege enforced

## Data Protection
- [ ] All data encrypted at rest
- [ ] TLS 1.3 for all communications
- [ ] Sensitive data masked in logs

## Input Validation
- [ ] All user input validated and sanitized
- [ ] File uploads scanned for malware
- [ ] Rate limiting on all endpoints

## Logging & Monitoring
- [ ] Security events logged
- [ ] Failed authentication attempts tracked
- [ ] Anomaly detection enabled
"""
        (security_dir / "SECURITY_REQUIREMENTS.md").write_text(security_requirements)

def main():
    parser = argparse.ArgumentParser(description='Generate secure application scaffold')
    parser.add_argument('app_name', help='Application name')
    parser.add_argument('--output', default='.', help='Output directory')
    parser.add_argument('--namespace', default='default', help='Kubernetes namespace')
    parser.add_argument('--replicas', type=int, default=3, help='Number of replicas')
    parser.add_argument('--port', type=int, default=8080, help='Application port')
    args = parser.parse_args()

    generator = SecureAppGenerator()
    generator.generate(
        args.app_name,
        args.output,
        {
            'namespace': args.namespace,
            'replicas': args.replicas,
            'port': args.port
        }
    )

if __name__ == '__main__':
    main()
```

## Part 3: Security Metrics Dashboard (45 minutes)

### Task 3.1: Metrics Collection

```python
#!/usr/bin/env python3
# metrics/security_metrics.py

import json
from datetime import datetime, timedelta
from typing import Dict, List
from dataclasses import dataclass, asdict
from prometheus_client import Counter, Gauge, Histogram, start_http_server
import sqlite3

# Prometheus metrics
vulnerabilities_total = Gauge(
    'security_vulnerabilities_total',
    'Total vulnerabilities by severity',
    ['severity', 'status']
)

mttr_seconds = Histogram(
    'security_mttr_seconds',
    'Mean time to remediate vulnerabilities',
    ['severity'],
    buckets=[3600, 86400, 259200, 604800, 1209600, 2592000]  # 1h, 1d, 3d, 7d, 14d, 30d
)

security_score = Gauge(
    'security_posture_score',
    'Overall security posture score (0-100)',
    ['component']
)

pipeline_security_failures = Counter(
    'security_pipeline_failures_total',
    'Security gate failures in CI/CD',
    ['stage', 'severity']
)

compliance_status = Gauge(
    'compliance_control_status',
    'Compliance control status (1=pass, 0=fail)',
    ['framework', 'control_id']
)

@dataclass
class SecurityMetrics:
    timestamp: str
    vulnerabilities: Dict[str, int]
    mttr_by_severity: Dict[str, float]
    security_score: float
    compliance_percentage: float
    open_findings: int
    pipeline_pass_rate: float

class SecurityMetricsCollector:
    def __init__(self, db_path: str = "security_metrics.db"):
        self.conn = sqlite3.connect(db_path)
        self._init_db()

    def _init_db(self):
        self.conn.execute('''
            CREATE TABLE IF NOT EXISTS vulnerabilities (
                id TEXT PRIMARY KEY,
                severity TEXT,
                status TEXT,
                discovered_at TIMESTAMP,
                resolved_at TIMESTAMP
            )
        ''')
        self.conn.execute('''
            CREATE TABLE IF NOT EXISTS pipeline_runs (
                id TEXT PRIMARY KEY,
                timestamp TIMESTAMP,
                passed BOOLEAN,
                failure_stage TEXT,
                failure_severity TEXT
            )
        ''')
        self.conn.commit()

    def collect_vulnerability_metrics(self) -> Dict[str, int]:
        """Collect current vulnerability counts."""
        cursor = self.conn.execute('''
            SELECT severity, status, COUNT(*) as count
            FROM vulnerabilities
            GROUP BY severity, status
        ''')

        metrics = {}
        for row in cursor.fetchall():
            severity, status, count = row
            key = f"{severity}_{status}"
            metrics[key] = count
            vulnerabilities_total.labels(severity=severity, status=status).set(count)

        return metrics

    def calculate_mttr(self) -> Dict[str, float]:
        """Calculate MTTR for resolved vulnerabilities."""
        cursor = self.conn.execute('''
            SELECT severity,
                   AVG(julianday(resolved_at) - julianday(discovered_at)) * 86400 as mttr_seconds
            FROM vulnerabilities
            WHERE status = 'resolved'
            AND resolved_at IS NOT NULL
            AND discovered_at > datetime('now', '-30 days')
            GROUP BY severity
        ''')

        mttr = {}
        for row in cursor.fetchall():
            severity, seconds = row
            mttr[severity] = seconds or 0
            if seconds:
                mttr_seconds.labels(severity=severity).observe(seconds)

        return mttr

    def calculate_security_score(self) -> float:
        """Calculate overall security posture score."""
        cursor = self.conn.execute('''
            SELECT
                (SELECT COUNT(*) FROM vulnerabilities WHERE status = 'open' AND severity = 'critical') as critical,
                (SELECT COUNT(*) FROM vulnerabilities WHERE status = 'open' AND severity = 'high') as high,
                (SELECT COUNT(*) FROM vulnerabilities WHERE status = 'open' AND severity = 'medium') as medium,
                (SELECT COUNT(*) FROM vulnerabilities WHERE status = 'open' AND severity = 'low') as low
        ''')

        critical, high, medium, low = cursor.fetchone()

        # Weighted score calculation
        base_score = 100
        deductions = (critical * 20) + (high * 10) + (medium * 3) + (low * 1)
        score = max(0, base_score - deductions)

        security_score.labels(component='overall').set(score)
        return score

    def get_pipeline_pass_rate(self, days: int = 30) -> float:
        """Calculate security pipeline pass rate."""
        cursor = self.conn.execute('''
            SELECT
                SUM(CASE WHEN passed THEN 1 ELSE 0 END) as passed,
                COUNT(*) as total
            FROM pipeline_runs
            WHERE timestamp > datetime('now', ?)
        ''', (f'-{days} days',))

        passed, total = cursor.fetchone()
        if total == 0:
            return 1.0
        return passed / total

    def collect_all_metrics(self) -> SecurityMetrics:
        """Collect all security metrics."""
        return SecurityMetrics(
            timestamp=datetime.now().isoformat(),
            vulnerabilities=self.collect_vulnerability_metrics(),
            mttr_by_severity=self.calculate_mttr(),
            security_score=self.calculate_security_score(),
            compliance_percentage=self._get_compliance_percentage(),
            open_findings=self._get_open_findings_count(),
            pipeline_pass_rate=self.get_pipeline_pass_rate()
        )

    def _get_compliance_percentage(self) -> float:
        """Get compliance percentage (placeholder)."""
        return 95.0

    def _get_open_findings_count(self) -> int:
        """Get count of open findings."""
        cursor = self.conn.execute(
            "SELECT COUNT(*) FROM vulnerabilities WHERE status = 'open'"
        )
        return cursor.fetchone()[0]

    def export_metrics_json(self, output_file: str):
        """Export metrics to JSON."""
        metrics = self.collect_all_metrics()
        with open(output_file, 'w') as f:
            json.dump(asdict(metrics), f, indent=2)

def start_metrics_server(port: int = 9090):
    """Start Prometheus metrics server."""
    start_http_server(port)
    print(f"Metrics server started on port {port}")

if __name__ == '__main__':
    import time

    collector = SecurityMetricsCollector()
    start_metrics_server()

    while True:
        collector.collect_all_metrics()
        time.sleep(60)
```

### Task 3.2: Grafana Dashboard

```json
{
  "dashboard": {
    "title": "Security Operations Dashboard",
    "uid": "security-ops",
    "panels": [
      {
        "title": "Security Posture Score",
        "type": "gauge",
        "gridPos": {"x": 0, "y": 0, "w": 6, "h": 8},
        "targets": [
          {
            "expr": "security_posture_score{component=\"overall\"}",
            "legendFormat": "Score"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "orange", "value": 50},
                {"color": "yellow", "value": 70},
                {"color": "green", "value": 85}
              ]
            },
            "min": 0,
            "max": 100
          }
        }
      },
      {
        "title": "Open Vulnerabilities by Severity",
        "type": "piechart",
        "gridPos": {"x": 6, "y": 0, "w": 6, "h": 8},
        "targets": [
          {
            "expr": "security_vulnerabilities_total{status=\"open\"}",
            "legendFormat": "{{severity}}"
          }
        ]
      },
      {
        "title": "Pipeline Security Pass Rate",
        "type": "stat",
        "gridPos": {"x": 12, "y": 0, "w": 6, "h": 8},
        "targets": [
          {
            "expr": "sum(rate(security_pipeline_failures_total[24h])) / sum(rate(ci_pipeline_runs_total[24h]))",
            "legendFormat": "Pass Rate"
          }
        ]
      },
      {
        "title": "MTTR by Severity",
        "type": "barchart",
        "gridPos": {"x": 18, "y": 0, "w": 6, "h": 8},
        "targets": [
          {
            "expr": "histogram_quantile(0.5, security_mttr_seconds_bucket) / 86400",
            "legendFormat": "{{severity}} (days)"
          }
        ]
      },
      {
        "title": "Vulnerability Trend",
        "type": "timeseries",
        "gridPos": {"x": 0, "y": 8, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "security_vulnerabilities_total{status=\"open\", severity=\"critical\"}",
            "legendFormat": "Critical"
          },
          {
            "expr": "security_vulnerabilities_total{status=\"open\", severity=\"high\"}",
            "legendFormat": "High"
          }
        ]
      },
      {
        "title": "Compliance Status",
        "type": "table",
        "gridPos": {"x": 12, "y": 8, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "compliance_control_status",
            "format": "table"
          }
        ]
      }
    ]
  }
}
```

## Part 4: Security Champions Program (30 minutes)

### Task 4.1: Security Champion Toolkit

````yaml
# security-champions/toolkit/README.md
---
title: Security Champion Toolkit
---

## Security Champion Responsibilities

### Weekly Tasks
- [ ] Review security findings in team's applications
- [ ] Triage new vulnerabilities within 48 hours
- [ ] Update security backlog in sprint planning
- [ ] Respond to security questions from team members

### Monthly Tasks
- [ ] Attend Security Champions meeting
- [ ] Review and update threat models
- [ ] Conduct security code review for critical PRs
- [ ] Report security metrics to leadership

### Quarterly Tasks
- [ ] Participate in security training updates
- [ ] Lead team security awareness session
- [ ] Review and update security documentation
- [ ] Conduct tabletop exercise for incident response

## Quick Reference

### Severity Classification
| Severity | Response Time | Examples |
|----------|--------------|----------|
| Critical | 24 hours | RCE, SQL injection in prod |
| High | 7 days | Auth bypass, sensitive data exposure |
| Medium | 30 days | XSS, CSRF, info disclosure |
| Low | 90 days | Missing headers, verbose errors |

### Escalation Path
1. Team Lead → Security Champion
2. Security Champion → Security Team
3. Security Team → CISO (Critical only)

### Useful Commands
```bash
# Run security scan locally
make security-scan

# Generate SBOM
make sbom

# Check for secrets
gitleaks detect --source . -v

# Validate Kubernetes security
kubesec scan deployment.yaml
```
````

### Task 4.2: Security Review Checklist

```markdown
# Security Code Review Checklist

## Authentication & Authorization
- [ ] Authentication required for all non-public endpoints
- [ ] Authorization checks at every access point
- [ ] Password requirements meet policy (12+ chars, complexity)
- [ ] MFA implemented for sensitive operations
- [ ] Session management follows best practices

## Input Validation
- [ ] All user input validated on server side
- [ ] Parameterized queries used for database access
- [ ] Output encoding applied for all dynamic content
- [ ] File uploads validated (type, size, content)
- [ ] API rate limiting implemented

## Data Protection
- [ ] Sensitive data encrypted at rest
- [ ] TLS 1.2+ for all connections
- [ ] No secrets in code or logs
- [ ] PII handled according to policy
- [ ] Data retention limits enforced

## Error Handling & Logging
- [ ] Generic error messages to users
- [ ] Detailed errors logged internally
- [ ] No stack traces exposed
- [ ] Security events logged
- [ ] Log injection prevented

## Dependencies
- [ ] All dependencies from approved sources
- [ ] No known critical/high vulnerabilities
- [ ] SBOM generated and stored
- [ ] License compliance verified
- [ ] Dependency pinning used

## Container Security
- [ ] Non-root user in container
- [ ] Read-only filesystem where possible
- [ ] No privileged containers
- [ ] Resource limits defined
- [ ] Base image from approved registry

## Kubernetes Security
- [ ] Network policies defined
- [ ] RBAC properly configured
- [ ] Secrets not in environment variables
- [ ] Pod security standards applied
- [ ] Service account tokens not auto-mounted
```

## Verification

Complete the following checklist:

- [ ] Implemented complete DevSecOps pipeline
- [ ] Created security gate with multiple stages
- [ ] Built secure-by-default templates
- [ ] Set up security metrics collection
- [ ] Created Grafana security dashboard
- [ ] Established security champion toolkit

## Challenge Tasks

1. **Add SLSA Provenance**: Generate and verify SLSA provenance for build artifacts
2. **Implement Break-Glass**: Create emergency bypass for security gates with audit logging
3. **Policy as Code**: Implement all security policies using OPA/Rego
4. **Security Chaos Engineering**: Create security chaos experiments

## Summary

In this lab, you:
- Built a complete DevSecOps pipeline with multiple security stages
- Implemented security gates with configurable thresholds
- Created secure-by-default templates for applications
- Set up security metrics and dashboards
- Established a security champions program

## Next Steps

- Review NIST Secure Software Development Framework
- Study Supply Chain Levels for Software Artifacts (SLSA)
- Implement software bill of materials (SBOM) management
- Explore security chaos engineering practices

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Complete DevSecOps Pipeline
- Secure-by-Default Templates
- Authentication
- Authorization

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
