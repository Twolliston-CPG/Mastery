# Module 12: DevSecOps Practices and Culture

## Learning Objectives

By the end of this module, you will be able to:
- Build a comprehensive DevSecOps program from the ground up
- Integrate security throughout the entire software development lifecycle
- Create security champions programs and foster security culture
- Implement security metrics and maturity models
- Automate security governance and policy enforcement
- Build secure-by-default platforms and golden paths

## Introduction to DevSecOps

DevSecOps integrates security practices within the DevOps process, making security a shared responsibility throughout the entire IT lifecycle.

### DevSecOps Principles

```yaml
# DevSecOps Foundation
devsecops_principles:
  shift_left:
    description: Move security earlier in the development lifecycle
    practices:
      - Threat modeling during design
      - Security requirements in user stories
      - IDE security plugins
      - Pre-commit hooks
      - Security unit tests

  automation_first:
    description: Automate security testing and enforcement
    practices:
      - Automated SAST/DAST/SCA
      - Policy-as-code
      - Infrastructure scanning
      - Automated remediation
      - Security gates in pipelines

  continuous_security:
    description: Security is ongoing, not a one-time event
    practices:
      - Continuous vulnerability scanning
      - Runtime protection
      - Security monitoring
      - Regular penetration testing
      - Threat intelligence integration

  shared_responsibility:
    description: Everyone owns security
    practices:
      - Security champions program
      - Security training
      - Blameless postmortems
      - Collaborative threat modeling
      - Cross-functional security reviews

  risk_based_approach:
    description: Prioritize based on risk, not just vulnerability count
    practices:
      - Asset criticality assessment
      - Business impact analysis
      - Risk-based prioritization
      - Context-aware alerting
      - Exception management
```

## Security in the SDLC

### Secure Development Lifecycle Integration

```yaml
# secure-sdlc-pipeline.yaml
# Complete CI/CD pipeline with security integrated at every stage

name: Secure SDLC Pipeline
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  SECURITY_GATE_ENABLED: true
  FAIL_ON_CRITICAL: true
  FAIL_ON_HIGH: false

jobs:
  # Stage 1: Pre-commit (should also run locally)
  pre-commit:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Run pre-commit hooks
      uses: pre-commit/action@v3.0.0
      with:
        extra_args: --all-files

    - name: Detect secrets
      uses: trufflesecurity/trufflehog@main
      with:
        path: ./
        base: ${{ github.event.repository.default_branch }}
        head: HEAD
        extra_args: --only-verified

  # Stage 2: Code Quality and SAST
  code-analysis:
    runs-on: ubuntu-latest
    needs: pre-commit
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0  # Full history for better analysis

    - name: Initialize CodeQL
      uses: github/codeql-action/init@v2
      with:
        languages: javascript, python
        queries: security-extended

    - name: Autobuild
      uses: github/codeql-action/autobuild@v2

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v2
      with:
        category: "/language:javascript"

    - name: Run Semgrep
      uses: returntocorp/semgrep-action@v1
      with:
        config: >-
          p/security-audit
          p/secrets
          p/owasp-top-ten
        generateSarif: true

    - name: Upload SARIF results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: semgrep.sarif

  # Stage 3: Dependency Scanning (SCA)
  dependency-scan:
    runs-on: ubuntu-latest
    needs: pre-commit
    steps:
    - uses: actions/checkout@v4

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH,MEDIUM'

    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

    - name: Run Snyk to check for vulnerabilities
      uses: snyk/actions/node@master
      continue-on-error: true
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

  # Stage 4: Build with security checks
  build:
    runs-on: ubuntu-latest
    needs: [code-analysis, dependency-scan]
    steps:
    - uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Build Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        push: false
        load: true
        tags: ${{ github.repository }}:${{ github.sha }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        build-args: |
          BUILD_DATE=${{ github.event.head_commit.timestamp }}
          VCS_REF=${{ github.sha }}

    - name: Scan Docker image
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: '${{ github.repository }}:${{ github.sha }}'
        format: 'sarif'
        output: 'trivy-image.sarif'
        severity: 'CRITICAL,HIGH'

    - name: Run Dockle linter
      uses: erzz/dockle-action@v1
      with:
        image: '${{ github.repository }}:${{ github.sha }}'
        failure-threshold: high

    - name: Sign container image
      if: github.ref == 'refs/heads/main'
      uses: sigstore/cosign-installer@main

    - name: Sign image with Cosign
      if: github.ref == 'refs/heads/main'
      run: |
        cosign sign --key env://COSIGN_PRIVATE_KEY \
          ${{ github.repository }}:${{ github.sha }}
      env:
        COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
        COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}

  # Stage 5: Infrastructure Security Scan
  infrastructure-scan:
    runs-on: ubuntu-latest
    needs: pre-commit
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
        format: sarif
        sarif_file: tfsec.sarif

    - name: Scan Kubernetes manifests
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'config'
        scan-ref: 'k8s/'
        format: 'sarif'
        output: 'trivy-k8s.sarif'

    - name: Run Kubesec
      uses: controlplaneio/kubesec-action@v0.0.2
      with:
        input: k8s/

  # Stage 6: Security Gate
  security-gate:
    runs-on: ubuntu-latest
    needs: [code-analysis, dependency-scan, build, infrastructure-scan]
    if: ${{ github.event_name == 'pull_request' }}
    steps:
    - name: Download all scan results
      uses: actions/download-artifact@v3

    - name: Evaluate security posture
      id: security-eval
      run: |
        # Aggregate results from all scans
        python3 scripts/security-gate.py \
          --sarif-files "*.sarif" \
          --sbom sbom/sbom.spdx.json \
          --fail-on-critical ${{ env.FAIL_ON_CRITICAL }} \
          --fail-on-high ${{ env.FAIL_ON_HIGH }}

    - name: Post security summary to PR
      uses: actions/github-script@v6
      with:
        script: |
          const fs = require('fs');
          const summary = fs.readFileSync('security-summary.md', 'utf8');
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: summary
          });

  # Stage 7: Dynamic Testing (DAST)
  dast:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/develop'
    steps:
    - uses: actions/checkout@v4

    - name: Deploy to staging
      run: |
        # Deploy to staging environment for DAST
        kubectl apply -f k8s/staging/

    - name: Wait for deployment
      run: |
        kubectl rollout status deployment/app -n staging --timeout=300s

    - name: Run OWASP ZAP scan
      uses: zaproxy/action-full-scan@v0.7.0
      with:
        target: 'https://staging.example.com'
        rules_file_name: '.zap/rules.tsv'
        cmd_options: '-a'

    - name: Run Nuclei scan
      uses: projectdiscovery/nuclei-action@main
      with:
        target: 'https://staging.example.com'
        templates: 'cves,vulnerabilities,misconfiguration'
        output: nuclei-results.txt

  # Stage 8: Deploy to Production
  deploy-production:
    runs-on: ubuntu-latest
    needs: [security-gate]
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://app.example.com
    steps:
    - uses: actions/checkout@v4

    - name: Verify image signature
      run: |
        cosign verify --key env://COSIGN_PUBLIC_KEY \
          ${{ github.repository }}:${{ github.sha }}
      env:
        COSIGN_PUBLIC_KEY: ${{ secrets.COSIGN_PUBLIC_KEY }}

    - name: Deploy to production
      run: |
        kubectl apply -f k8s/production/

    - name: Verify deployment
      run: |
        kubectl rollout status deployment/app -n production --timeout=300s

    - name: Notify security team
      uses: slackapi/slack-github-action@v1.24.0
      with:
        channel-id: 'security-notifications'
        payload: |
          {
            "text": "Production deployment completed",
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "*Production Deployment*\nCommit: ${{ github.sha }}\nSecurity scans: Passed"
                }
              }
            ]
          }
      env:
        SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
```

### Security Gate Evaluator

```python
#!/usr/bin/env python3
# scripts/security-gate.py - Evaluate security scan results

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Any
from dataclasses import dataclass
from enum import Enum
import glob

class Severity(Enum):
    CRITICAL = 4
    HIGH = 3
    MEDIUM = 2
    LOW = 1
    INFO = 0

@dataclass
class Finding:
    id: str
    severity: Severity
    title: str
    description: str
    file: str
    line: int
    tool: str
    cwe: str = ""
    cve: str = ""

class SecurityGate:
    def __init__(self):
        self.findings: List[Finding] = []
        self.sbom_vulnerabilities: List[Dict] = []

    def load_sarif(self, sarif_path: str):
        """Load SARIF format scan results."""
        with open(sarif_path) as f:
            data = json.load(f)

        for run in data.get('runs', []):
            tool_name = run.get('tool', {}).get('driver', {}).get('name', 'unknown')
            rules = {r['id']: r for r in run.get('tool', {}).get('driver', {}).get('rules', [])}

            for result in run.get('results', []):
                rule_id = result.get('ruleId', '')
                rule = rules.get(rule_id, {})

                severity = self._map_sarif_severity(
                    result.get('level', 'warning'),
                    rule.get('defaultConfiguration', {}).get('level', 'warning')
                )

                location = result.get('locations', [{}])[0]
                physical_location = location.get('physicalLocation', {})

                finding = Finding(
                    id=rule_id,
                    severity=severity,
                    title=rule.get('shortDescription', {}).get('text', rule_id),
                    description=result.get('message', {}).get('text', ''),
                    file=physical_location.get('artifactLocation', {}).get('uri', ''),
                    line=physical_location.get('region', {}).get('startLine', 0),
                    tool=tool_name,
                    cwe=self._extract_cwe(rule),
                    cve=self._extract_cve(rule)
                )
                self.findings.append(finding)

    def _map_sarif_severity(self, level: str, default: str) -> Severity:
        """Map SARIF severity levels to our enum."""
        severity_map = {
            'error': Severity.HIGH,
            'warning': Severity.MEDIUM,
            'note': Severity.LOW,
            'none': Severity.INFO
        }
        return severity_map.get(level, severity_map.get(default, Severity.MEDIUM))

    def _extract_cwe(self, rule: Dict) -> str:
        """Extract CWE from rule properties."""
        for tag in rule.get('properties', {}).get('tags', []):
            if tag.startswith('CWE-'):
                return tag
        return ""

    def _extract_cve(self, rule: Dict) -> str:
        """Extract CVE from rule properties."""
        for tag in rule.get('properties', {}).get('tags', []):
            if tag.startswith('CVE-'):
                return tag
        return ""

    def load_sbom(self, sbom_path: str):
        """Load SBOM and check for known vulnerabilities."""
        with open(sbom_path) as f:
            sbom = json.load(f)

        # Parse SPDX format
        for package in sbom.get('packages', []):
            # Would typically query vulnerability database here
            pass

    def evaluate(self, fail_on_critical: bool = True, fail_on_high: bool = False) -> bool:
        """Evaluate findings against policy thresholds."""
        critical_count = sum(1 for f in self.findings if f.severity == Severity.CRITICAL)
        high_count = sum(1 for f in self.findings if f.severity == Severity.HIGH)
        medium_count = sum(1 for f in self.findings if f.severity == Severity.MEDIUM)
        low_count = sum(1 for f in self.findings if f.severity == Severity.LOW)

        print(f"\n{'='*60}")
        print("SECURITY GATE EVALUATION")
        print(f"{'='*60}")
        print(f"\nFindings Summary:")
        print(f"  Critical: {critical_count}")
        print(f"  High:     {high_count}")
        print(f"  Medium:   {medium_count}")
        print(f"  Low:      {low_count}")
        print(f"  Total:    {len(self.findings)}")

        passed = True
        if fail_on_critical and critical_count > 0:
            print(f"\n❌ FAILED: {critical_count} critical vulnerabilities found")
            passed = False
        if fail_on_high and high_count > 0:
            print(f"\n❌ FAILED: {high_count} high vulnerabilities found")
            passed = False

        if passed:
            print("\n✅ PASSED: Security gate requirements met")

        return passed

    def generate_report(self, output_path: str):
        """Generate markdown report for PR comment."""
        report_lines = [
            "## 🔒 Security Scan Results",
            "",
            "### Summary",
            "",
            "| Severity | Count |",
            "|----------|-------|",
        ]

        severity_counts = {}
        for severity in Severity:
            count = sum(1 for f in self.findings if f.severity == severity)
            severity_counts[severity] = count
            emoji = {"CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡", "LOW": "🟢", "INFO": "ℹ️"}
            report_lines.append(f"| {emoji.get(severity.name, '')} {severity.name} | {count} |")

        report_lines.extend([
            "",
            "### Critical & High Findings",
            ""
        ])

        critical_high = [f for f in self.findings if f.severity in (Severity.CRITICAL, Severity.HIGH)]
        if critical_high:
            for finding in critical_high[:20]:  # Limit to 20
                report_lines.extend([
                    f"#### {finding.severity.name}: {finding.title}",
                    f"- **Tool:** {finding.tool}",
                    f"- **File:** `{finding.file}:{finding.line}`",
                    f"- **CWE:** {finding.cwe}" if finding.cwe else "",
                    f"- **Description:** {finding.description[:200]}...",
                    ""
                ])
        else:
            report_lines.append("✅ No critical or high severity findings")

        report_lines.extend([
            "",
            "---",
            "*Generated by Security Gate*"
        ])

        with open(output_path, 'w') as f:
            f.write('\n'.join(report_lines))


def main():
    parser = argparse.ArgumentParser(description='Security Gate Evaluator')
    parser.add_argument('--sarif-files', required=True, help='Glob pattern for SARIF files')
    parser.add_argument('--sbom', help='Path to SBOM file')
    parser.add_argument('--fail-on-critical', type=bool, default=True)
    parser.add_argument('--fail-on-high', type=bool, default=False)
    parser.add_argument('--output', default='security-summary.md')
    args = parser.parse_args()

    gate = SecurityGate()

    # Load all SARIF files
    for sarif_file in glob.glob(args.sarif_files):
        print(f"Loading: {sarif_file}")
        gate.load_sarif(sarif_file)

    # Load SBOM if provided
    if args.sbom and Path(args.sbom).exists():
        gate.load_sbom(args.sbom)

    # Generate report
    gate.generate_report(args.output)

    # Evaluate and exit with appropriate code
    passed = gate.evaluate(args.fail_on_critical, args.fail_on_high)
    sys.exit(0 if passed else 1)


if __name__ == '__main__':
    main()
```

## Security Champions Program

### Program Structure

```yaml
# security-champions-program.yaml
security_champions_program:
  overview:
    description: |
      Security Champions are developers who act as security advocates
      within their teams, bridging the gap between security and development.

  objectives:
    - Embed security expertise within development teams
    - Scale security knowledge across the organization
    - Improve security awareness and culture
    - Reduce security review bottlenecks
    - Foster security-first mindset

  structure:
    levels:
      bronze:
        requirements:
          - Complete security fundamentals training
          - Pass security basics assessment
          - Participate in 2 threat modeling sessions
        responsibilities:
          - Promote security awareness in team
          - Escalate security concerns
          - Participate in security reviews
        time_commitment: "2-4 hours/month"

      silver:
        requirements:
          - 6 months as Bronze champion
          - Complete secure coding training
          - Lead 2 threat modeling sessions
          - Mentor 1 Bronze champion
        responsibilities:
          - Lead security reviews for team
          - Conduct threat modeling sessions
          - Review security scan results
          - Train team on security tools
        time_commitment: "4-8 hours/month"

      gold:
        requirements:
          - 12 months as Silver champion
          - Complete advanced security training
          - Contribute to security tooling
          - Present at security community
        responsibilities:
          - Define security standards
          - Evaluate new security tools
          - Lead security initiatives
          - Mentor other champions
        time_commitment: "8-12 hours/month"

  activities:
    monthly:
      - Security champions meeting
      - Review security metrics
      - Share learnings and best practices
      - Tool demos and training

    quarterly:
      - Security awareness campaigns
      - Capture-the-flag competitions
      - Security tool evaluations
      - Cross-team security reviews

    annual:
      - Security champion summit
      - Advanced training workshops
      - Recognition and awards
      - Program retrospective

  metrics:
    engagement:
      - Champion participation rate
      - Training completion rate
      - Meeting attendance
      - Mentorship activity

    impact:
      - Security findings by champion teams
      - Time to remediation
      - Security review coverage
      - Developer feedback scores

  recognition:
    - Monthly shout-outs
    - Quarterly awards
    - Annual security champion of the year
    - Conference attendance sponsorship
    - Career growth opportunities
```

### Security Training Platform

```python
#!/usr/bin/env python3
# security_training_platform.py - Manage security training and assessments

from dataclasses import dataclass
from datetime import datetime
from typing import Dict, List, Optional
from enum import Enum
import json

class TrainingLevel(Enum):
    BEGINNER = "beginner"
    INTERMEDIATE = "intermediate"
    ADVANCED = "advanced"

class TrainingCategory(Enum):
    SECURE_CODING = "secure_coding"
    THREAT_MODELING = "threat_modeling"
    SECURITY_TESTING = "security_testing"
    CLOUD_SECURITY = "cloud_security"
    CONTAINER_SECURITY = "container_security"
    COMPLIANCE = "compliance"

@dataclass
class Course:
    id: str
    title: str
    description: str
    level: TrainingLevel
    category: TrainingCategory
    duration_hours: float
    modules: List[Dict]
    assessment_required: bool
    passing_score: int = 80

@dataclass
class UserProgress:
    user_id: str
    course_id: str
    started_at: datetime
    completed_at: Optional[datetime]
    modules_completed: List[str]
    assessment_score: Optional[int]
    certificate_issued: bool

class SecurityTrainingPlatform:
    def __init__(self):
        self.courses = self._load_courses()
        self.user_progress: Dict[str, List[UserProgress]] = {}

    def _load_courses(self) -> List[Course]:
        """Load course catalog."""
        return [
            Course(
                id="SEC101",
                title="Security Fundamentals for Developers",
                description="Introduction to application security concepts",
                level=TrainingLevel.BEGINNER,
                category=TrainingCategory.SECURE_CODING,
                duration_hours=4,
                modules=[
                    {"id": "m1", "title": "Why Security Matters", "duration": 30},
                    {"id": "m2", "title": "OWASP Top 10 Overview", "duration": 60},
                    {"id": "m3", "title": "Common Vulnerabilities", "duration": 60},
                    {"id": "m4", "title": "Security in SDLC", "duration": 45},
                    {"id": "m5", "title": "Security Testing Basics", "duration": 45},
                ],
                assessment_required=True,
                passing_score=70
            ),
            Course(
                id="SEC201",
                title="Secure Coding Practices",
                description="Hands-on secure coding for web applications",
                level=TrainingLevel.INTERMEDIATE,
                category=TrainingCategory.SECURE_CODING,
                duration_hours=8,
                modules=[
                    {"id": "m1", "title": "Input Validation", "duration": 60},
                    {"id": "m2", "title": "Output Encoding", "duration": 60},
                    {"id": "m3", "title": "Authentication & Sessions", "duration": 90},
                    {"id": "m4", "title": "Access Control", "duration": 60},
                    {"id": "m5", "title": "Cryptography Basics", "duration": 90},
                    {"id": "m6", "title": "Error Handling & Logging", "duration": 60},
                    {"id": "m7", "title": "Secure API Design", "duration": 60},
                ],
                assessment_required=True,
                passing_score=80
            ),
            Course(
                id="SEC301",
                title="Threat Modeling Workshop",
                description="Learn to identify and analyze threats",
                level=TrainingLevel.INTERMEDIATE,
                category=TrainingCategory.THREAT_MODELING,
                duration_hours=6,
                modules=[
                    {"id": "m1", "title": "Threat Modeling Introduction", "duration": 45},
                    {"id": "m2", "title": "STRIDE Methodology", "duration": 60},
                    {"id": "m3", "title": "Attack Trees", "duration": 60},
                    {"id": "m4", "title": "Data Flow Diagrams", "duration": 60},
                    {"id": "m5", "title": "Risk Assessment", "duration": 60},
                    {"id": "m6", "title": "Practical Workshop", "duration": 90},
                ],
                assessment_required=True,
                passing_score=75
            ),
            Course(
                id="SEC401",
                title="Container Security Deep Dive",
                description="Securing containers and Kubernetes",
                level=TrainingLevel.ADVANCED,
                category=TrainingCategory.CONTAINER_SECURITY,
                duration_hours=10,
                modules=[
                    {"id": "m1", "title": "Container Security Model", "duration": 60},
                    {"id": "m2", "title": "Secure Image Building", "duration": 90},
                    {"id": "m3", "title": "Image Scanning & Signing", "duration": 60},
                    {"id": "m4", "title": "Runtime Security", "duration": 90},
                    {"id": "m5", "title": "Kubernetes Security", "duration": 120},
                    {"id": "m6", "title": "Network Policies", "duration": 60},
                    {"id": "m7", "title": "Secrets Management", "duration": 60},
                    {"id": "m8", "title": "Security Monitoring", "duration": 60},
                ],
                assessment_required=True,
                passing_score=80
            ),
        ]

    def get_recommended_courses(self, user_id: str, role: str) -> List[Course]:
        """Get personalized course recommendations."""
        completed = self._get_completed_courses(user_id)

        # Role-based recommendations
        role_courses = {
            "developer": ["SEC101", "SEC201", "SEC301"],
            "devops": ["SEC101", "SEC401", "SEC501"],
            "architect": ["SEC101", "SEC201", "SEC301", "SEC401"],
            "security_champion": ["SEC101", "SEC201", "SEC301", "SEC401", "SEC501"],
        }

        recommended_ids = role_courses.get(role, ["SEC101"])
        return [c for c in self.courses
                if c.id in recommended_ids and c.id not in completed]

    def _get_completed_courses(self, user_id: str) -> List[str]:
        """Get list of completed course IDs for user."""
        progress_list = self.user_progress.get(user_id, [])
        return [p.course_id for p in progress_list
                if p.completed_at is not None and
                (not self._get_course(p.course_id).assessment_required or
                 (p.assessment_score and p.assessment_score >= self._get_course(p.course_id).passing_score))]

    def _get_course(self, course_id: str) -> Optional[Course]:
        """Get course by ID."""
        for course in self.courses:
            if course.id == course_id:
                return course
        return None

    def enroll_user(self, user_id: str, course_id: str) -> UserProgress:
        """Enroll user in a course."""
        progress = UserProgress(
            user_id=user_id,
            course_id=course_id,
            started_at=datetime.now(),
            completed_at=None,
            modules_completed=[],
            assessment_score=None,
            certificate_issued=False
        )

        if user_id not in self.user_progress:
            self.user_progress[user_id] = []
        self.user_progress[user_id].append(progress)

        return progress

    def complete_module(self, user_id: str, course_id: str, module_id: str) -> UserProgress:
        """Mark a module as completed."""
        progress = self._get_progress(user_id, course_id)
        if progress and module_id not in progress.modules_completed:
            progress.modules_completed.append(module_id)

            # Check if all modules completed
            course = self._get_course(course_id)
            if course and len(progress.modules_completed) == len(course.modules):
                if not course.assessment_required:
                    progress.completed_at = datetime.now()

        return progress

    def submit_assessment(self, user_id: str, course_id: str, score: int) -> UserProgress:
        """Submit assessment score."""
        progress = self._get_progress(user_id, course_id)
        course = self._get_course(course_id)

        if progress and course:
            progress.assessment_score = score
            if score >= course.passing_score:
                progress.completed_at = datetime.now()
                progress.certificate_issued = True

        return progress

    def _get_progress(self, user_id: str, course_id: str) -> Optional[UserProgress]:
        """Get user's progress for a course."""
        progress_list = self.user_progress.get(user_id, [])
        for progress in progress_list:
            if progress.course_id == course_id:
                return progress
        return None

    def get_user_dashboard(self, user_id: str) -> Dict:
        """Get user's training dashboard data."""
        progress_list = self.user_progress.get(user_id, [])

        in_progress = []
        completed = []
        certificates = []

        for progress in progress_list:
            course = self._get_course(progress.course_id)
            if not course:
                continue

            course_data = {
                "course_id": course.id,
                "title": course.title,
                "level": course.level.value,
                "progress_percent": len(progress.modules_completed) / len(course.modules) * 100,
                "assessment_score": progress.assessment_score
            }

            if progress.completed_at:
                completed.append(course_data)
                if progress.certificate_issued:
                    certificates.append({
                        "course_id": course.id,
                        "title": course.title,
                        "completed_at": progress.completed_at.isoformat()
                    })
            else:
                in_progress.append(course_data)

        return {
            "user_id": user_id,
            "in_progress": in_progress,
            "completed": completed,
            "certificates": certificates,
            "total_hours_completed": sum(
                self._get_course(p.course_id).duration_hours
                for p in progress_list
                if p.completed_at and self._get_course(p.course_id)
            )
        }

    def generate_team_report(self, team_members: List[str]) -> Dict:
        """Generate training report for a team."""
        team_stats = {
            "total_members": len(team_members),
            "courses_completed": 0,
            "total_hours": 0,
            "completion_by_course": {},
            "members_needing_training": []
        }

        for member in team_members:
            dashboard = self.get_user_dashboard(member)
            team_stats["courses_completed"] += len(dashboard["completed"])
            team_stats["total_hours"] += dashboard["total_hours_completed"]

            if not dashboard["completed"]:
                team_stats["members_needing_training"].append(member)

            for course in dashboard["completed"]:
                course_id = course["course_id"]
                if course_id not in team_stats["completion_by_course"]:
                    team_stats["completion_by_course"][course_id] = 0
                team_stats["completion_by_course"][course_id] += 1

        return team_stats
```

## Security Metrics and Maturity

### Security Metrics Dashboard

```python
#!/usr/bin/env python3
# security_metrics.py - Security metrics collection and reporting

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Dict, List, Any
from enum import Enum
import json

class MetricCategory(Enum):
    VULNERABILITY = "vulnerability"
    COMPLIANCE = "compliance"
    INCIDENT = "incident"
    PROCESS = "process"
    TRAINING = "training"

@dataclass
class SecurityMetric:
    name: str
    category: MetricCategory
    value: float
    unit: str
    target: float
    trend: str  # up, down, stable
    timestamp: datetime

class SecurityMetricsCollector:
    def __init__(self, data_sources: Dict[str, Any]):
        self.data_sources = data_sources

    def collect_vulnerability_metrics(self) -> List[SecurityMetric]:
        """Collect vulnerability-related metrics."""
        # Would query vulnerability management system
        return [
            SecurityMetric(
                name="Mean Time to Remediate (Critical)",
                category=MetricCategory.VULNERABILITY,
                value=5.2,
                unit="days",
                target=7.0,
                trend="down",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Mean Time to Remediate (High)",
                category=MetricCategory.VULNERABILITY,
                value=14.5,
                unit="days",
                target=30.0,
                trend="stable",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Open Critical Vulnerabilities",
                category=MetricCategory.VULNERABILITY,
                value=3,
                unit="count",
                target=0,
                trend="down",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Vulnerability Density",
                category=MetricCategory.VULNERABILITY,
                value=0.8,
                unit="per 1000 LoC",
                target=1.0,
                trend="down",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Scan Coverage",
                category=MetricCategory.VULNERABILITY,
                value=95.5,
                unit="percent",
                target=100,
                trend="up",
                timestamp=datetime.now()
            ),
        ]

    def collect_compliance_metrics(self) -> List[SecurityMetric]:
        """Collect compliance-related metrics."""
        return [
            SecurityMetric(
                name="Policy Compliance Rate",
                category=MetricCategory.COMPLIANCE,
                value=94.2,
                unit="percent",
                target=95.0,
                trend="up",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Security Controls Implemented",
                category=MetricCategory.COMPLIANCE,
                value=142,
                unit="count",
                target=150,
                trend="up",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Audit Findings Open",
                category=MetricCategory.COMPLIANCE,
                value=5,
                unit="count",
                target=0,
                trend="down",
                timestamp=datetime.now()
            ),
        ]

    def collect_incident_metrics(self) -> List[SecurityMetric]:
        """Collect incident-related metrics."""
        return [
            SecurityMetric(
                name="Security Incidents (30 days)",
                category=MetricCategory.INCIDENT,
                value=12,
                unit="count",
                target=10,
                trend="stable",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Mean Time to Detect",
                category=MetricCategory.INCIDENT,
                value=4.5,
                unit="hours",
                target=1.0,
                trend="down",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Mean Time to Respond",
                category=MetricCategory.INCIDENT,
                value=2.3,
                unit="hours",
                target=4.0,
                trend="down",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Mean Time to Contain",
                category=MetricCategory.INCIDENT,
                value=6.8,
                unit="hours",
                target=8.0,
                trend="stable",
                timestamp=datetime.now()
            ),
        ]

    def collect_process_metrics(self) -> List[SecurityMetric]:
        """Collect process-related metrics."""
        return [
            SecurityMetric(
                name="Security Review Coverage",
                category=MetricCategory.PROCESS,
                value=78.5,
                unit="percent",
                target=90.0,
                trend="up",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Threat Models Completed",
                category=MetricCategory.PROCESS,
                value=45,
                unit="count",
                target=50,
                trend="up",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Security Exceptions Active",
                category=MetricCategory.PROCESS,
                value=8,
                unit="count",
                target=5,
                trend="stable",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Pipeline Security Gate Pass Rate",
                category=MetricCategory.PROCESS,
                value=92.3,
                unit="percent",
                target=95.0,
                trend="up",
                timestamp=datetime.now()
            ),
        ]

    def collect_training_metrics(self) -> List[SecurityMetric]:
        """Collect training-related metrics."""
        return [
            SecurityMetric(
                name="Security Training Completion",
                category=MetricCategory.TRAINING,
                value=85.2,
                unit="percent",
                target=100.0,
                trend="up",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Security Champions Active",
                category=MetricCategory.TRAINING,
                value=24,
                unit="count",
                target=30,
                trend="up",
                timestamp=datetime.now()
            ),
            SecurityMetric(
                name="Phishing Test Click Rate",
                category=MetricCategory.TRAINING,
                value=3.2,
                unit="percent",
                target=5.0,
                trend="down",
                timestamp=datetime.now()
            ),
        ]

    def generate_executive_report(self) -> Dict:
        """Generate executive-level security report."""
        all_metrics = (
            self.collect_vulnerability_metrics() +
            self.collect_compliance_metrics() +
            self.collect_incident_metrics() +
            self.collect_process_metrics() +
            self.collect_training_metrics()
        )

        # Calculate overall security score
        metrics_on_target = sum(1 for m in all_metrics if self._is_on_target(m))
        security_score = (metrics_on_target / len(all_metrics)) * 100

        # Categorize metrics
        by_category = {}
        for metric in all_metrics:
            category = metric.category.value
            if category not in by_category:
                by_category[category] = []
            by_category[category].append({
                "name": metric.name,
                "value": metric.value,
                "unit": metric.unit,
                "target": metric.target,
                "on_target": self._is_on_target(metric),
                "trend": metric.trend
            })

        # Identify top risks
        risks = [m for m in all_metrics if not self._is_on_target(m)]
        risks.sort(key=lambda m: abs(m.value - m.target) / m.target if m.target else 0, reverse=True)

        return {
            "report_date": datetime.now().isoformat(),
            "overall_security_score": round(security_score, 1),
            "metrics_by_category": by_category,
            "top_risks": [
                {
                    "name": r.name,
                    "current": r.value,
                    "target": r.target,
                    "gap_percent": round(abs(r.value - r.target) / r.target * 100 if r.target else 0, 1)
                }
                for r in risks[:5]
            ],
            "trends": {
                "improving": sum(1 for m in all_metrics if m.trend == "down" and m.target < m.value or m.trend == "up" and m.target > m.value),
                "stable": sum(1 for m in all_metrics if m.trend == "stable"),
                "declining": sum(1 for m in all_metrics if m.trend == "up" and m.target < m.value or m.trend == "down" and m.target > m.value)
            }
        }

    def _is_on_target(self, metric: SecurityMetric) -> bool:
        """Check if metric is meeting target."""
        # For metrics where lower is better (incidents, vulnerabilities)
        lower_is_better = ["vulnerability", "incident"]
        if any(cat in metric.name.lower() for cat in lower_is_better):
            return metric.value <= metric.target
        # For metrics where higher is better (compliance, coverage)
        return metric.value >= metric.target


class SecurityMaturityModel:
    """OWASP SAMM-based maturity assessment."""

    def __init__(self):
        self.practices = {
            "governance": {
                "strategy_metrics": ["Security policy exists", "Security roadmap defined", "Budget allocated"],
                "policy_compliance": ["Standards documented", "Compliance monitoring", "Exception process"],
                "education_guidance": ["Training program", "Security champions", "Knowledge base"]
            },
            "design": {
                "threat_assessment": ["Threat modeling", "Attack surface analysis", "Risk prioritization"],
                "security_requirements": ["Security requirements process", "Supplier security", "Secure by default"],
                "security_architecture": ["Reference architectures", "Security patterns", "Technology standards"]
            },
            "implementation": {
                "secure_build": ["Build security", "Dependency management", "Secret management"],
                "secure_deployment": ["Deployment security", "Infrastructure hardening", "Container security"],
                "defect_management": ["Vulnerability tracking", "Patch management", "Security debt"]
            },
            "verification": {
                "architecture_assessment": ["Design review", "Architecture analysis", "Threat model review"],
                "requirements_testing": ["Security testing", "Abuse case testing", "Security acceptance"],
                "security_testing": ["SAST", "DAST", "Penetration testing"]
            },
            "operations": {
                "incident_management": ["Detection capability", "Response process", "Post-incident"],
                "environment_management": ["Asset inventory", "Configuration management", "Patch process"],
                "operational_management": ["Monitoring", "Alerting", "Continuous improvement"]
            }
        }

    def assess_practice(self, practice: str, sub_practice: str, evidence: List[str]) -> int:
        """Assess maturity level (0-3) for a practice."""
        requirements = self.practices.get(practice, {}).get(sub_practice, [])
        if not requirements:
            return 0

        fulfilled = sum(1 for req in requirements if any(e.lower() in req.lower() for e in evidence))
        return min(3, fulfilled)

    def calculate_maturity_score(self, assessments: Dict[str, Dict[str, int]]) -> Dict:
        """Calculate overall maturity score."""
        scores = []
        by_practice = {}

        for practice, sub_practices in assessments.items():
            practice_scores = list(sub_practices.values())
            practice_avg = sum(practice_scores) / len(practice_scores) if practice_scores else 0
            by_practice[practice] = round(practice_avg, 2)
            scores.extend(practice_scores)

        return {
            "overall_score": round(sum(scores) / len(scores) if scores else 0, 2),
            "max_score": 3.0,
            "by_practice": by_practice,
            "maturity_level": self._get_maturity_level(sum(scores) / len(scores) if scores else 0)
        }

    def _get_maturity_level(self, score: float) -> str:
        """Convert score to maturity level."""
        if score >= 2.5:
            return "Optimizing"
        elif score >= 2.0:
            return "Managed"
        elif score >= 1.5:
            return "Defined"
        elif score >= 1.0:
            return "Developing"
        else:
            return "Initial"

    def generate_roadmap(self, current_assessments: Dict, target_level: str = "Managed") -> List[Dict]:
        """Generate improvement roadmap."""
        target_score = {"Initial": 0.5, "Developing": 1.0, "Defined": 1.5, "Managed": 2.0, "Optimizing": 2.5}[target_level]

        improvements = []
        for practice, sub_practices in current_assessments.items():
            for sub_practice, score in sub_practices.items():
                if score < target_score:
                    improvements.append({
                        "practice": practice,
                        "sub_practice": sub_practice,
                        "current_score": score,
                        "target_score": target_score,
                        "gap": target_score - score,
                        "recommendations": self._get_recommendations(practice, sub_practice, score)
                    })

        # Sort by gap (prioritize biggest gaps)
        improvements.sort(key=lambda x: x["gap"], reverse=True)
        return improvements

    def _get_recommendations(self, practice: str, sub_practice: str, current_score: int) -> List[str]:
        """Get recommendations for improving a practice."""
        recommendations = {
            ("governance", "strategy_metrics"): [
                "Establish formal security strategy document",
                "Define security KPIs and metrics",
                "Allocate dedicated security budget"
            ],
            ("implementation", "secure_build"): [
                "Implement SAST in CI/CD pipeline",
                "Deploy dependency scanning",
                "Implement secrets management solution"
            ],
            ("verification", "security_testing"): [
                "Implement automated security testing",
                "Conduct regular penetration testing",
                "Deploy DAST for web applications"
            ]
        }
        return recommendations.get((practice, sub_practice), ["Review OWASP SAMM guidance for this practice"])
```

## Secure Platform Engineering

### Golden Path Templates

```yaml
# golden-path/secure-application-template/template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: secure-web-application
  title: Secure Web Application
  description: Production-ready web application with security controls built-in
  tags:
    - recommended
    - secure
    - web
spec:
  owner: platform-team
  type: service

  parameters:
    - title: Application Details
      required:
        - name
        - owner
      properties:
        name:
          title: Name
          type: string
          description: Unique name for the application
          pattern: '^[a-z0-9-]+$'
        owner:
          title: Owner
          type: string
          description: Team that owns this application
          ui:field: OwnerPicker
        description:
          title: Description
          type: string
        classification:
          title: Data Classification
          type: string
          enum:
            - public
            - internal
            - confidential
            - restricted
          default: internal

    - title: Security Configuration
      properties:
        authMethod:
          title: Authentication Method
          type: string
          enum:
            - oauth2
            - oidc
            - api-key
          default: oidc
        requireMfa:
          title: Require MFA
          type: boolean
          default: false
        encryptionAtRest:
          title: Encrypt Data at Rest
          type: boolean
          default: true
        networkPolicy:
          title: Network Policy
          type: string
          enum:
            - strict
            - standard
            - permissive
          default: standard

    - title: Infrastructure
      properties:
        environment:
          title: Target Environment
          type: string
          enum:
            - development
            - staging
            - production
        kubernetes:
          title: Deploy to Kubernetes
          type: boolean
          default: true

  steps:
    - id: fetch-base
      name: Fetch Base Template
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}
          owner: ${{ parameters.owner }}
          classification: ${{ parameters.classification }}

    - id: generate-security-config
      name: Generate Security Configuration
      action: fetch:template
      input:
        url: ./security
        targetPath: ./security
        values:
          authMethod: ${{ parameters.authMethod }}
          requireMfa: ${{ parameters.requireMfa }}
          networkPolicy: ${{ parameters.networkPolicy }}

    - id: generate-k8s-manifests
      name: Generate Kubernetes Manifests
      action: fetch:template
      input:
        url: ./kubernetes
        targetPath: ./k8s
        values:
          name: ${{ parameters.name }}
          classification: ${{ parameters.classification }}
          networkPolicy: ${{ parameters.networkPolicy }}

    - id: create-repo
      name: Create Repository
      action: publish:github
      input:
        repoUrl: github.com?owner=company&repo=${{ parameters.name }}
        defaultBranch: main
        protectDefaultBranch: true
        requireCodeOwnerReviews: true

    - id: setup-branch-protection
      name: Setup Branch Protection
      action: github:branch-protection
      input:
        repoUrl: ${{ steps.create-repo.output.remoteUrl }}
        branch: main
        requirePullRequest: true
        requiredReviewers: 2
        dismissStaleReviews: true
        requireCodeOwners: true
        requireStatusChecks:
          - security-scan
          - build
          - test

    - id: register-component
      name: Register in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.create-repo.output.repoContentsUrl }}
        catalogInfoPath: '/catalog-info.yaml'

  output:
    links:
      - title: Repository
        url: ${{ steps.create-repo.output.remoteUrl }}
      - title: Open in Backstage
        icon: catalog
        entityRef: ${{ steps.register-component.output.entityRef }}
```

### Secure Application Skeleton

```dockerfile
# golden-path/secure-application-template/skeleton/Dockerfile
# Secure multi-stage Dockerfile template

# Build stage
FROM node:20-alpine AS builder

# Create non-root user for build
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copy package files first for better caching
COPY --chown=appuser:appgroup package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy source code
COPY --chown=appuser:appgroup . .

# Build application
RUN npm run build

# Production stage
FROM gcr.io/distroless/nodejs20-debian12:nonroot

# Copy built application
COPY --from=builder /app/dist /app
COPY --from=builder /app/node_modules /app/node_modules

WORKDIR /app

# Use non-root user (65532 is the nonroot user in distroless)
USER 65532:65532

# Expose port (non-privileged)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/nodejs/bin/node", "-e", "require('http').get('http://localhost:8080/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"]

# Start application
CMD ["/app/server.js"]
```

```yaml
# golden-path/secure-application-template/kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${{ values.name }}
  labels:
    app: ${{ values.name }}
    data-classification: ${{ values.classification }}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ${{ values.name }}
  template:
    metadata:
      labels:
        app: ${{ values.name }}
        data-classification: ${{ values.classification }}
      annotations:
        seccomp.security.alpha.kubernetes.io/pod: runtime/default
    spec:
      serviceAccountName: ${{ values.name }}
      automountServiceAccountToken: false

      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
        fsGroup: 65532
        seccompProfile:
          type: RuntimeDefault

      containers:
      - name: app
        image: ${{ values.name }}:latest
        imagePullPolicy: Always

        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
              - ALL

        ports:
        - containerPort: 8080
          name: http
          protocol: TCP

        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"

        env:
        - name: NODE_ENV
          value: "production"
        - name: LOG_LEVEL
          value: "info"
        # Secrets from External Secrets Operator
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: ${{ values.name }}-secrets
              key: database-url

        livenessProbe:
          httpGet:
            path: /health/live
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10

        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5

        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/.cache

      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}

      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: ${{ values.name }}
              topologyKey: kubernetes.io/hostname

      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: ${{ values.name }}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${{ values.name }}-network-policy
spec:
  podSelector:
    matchLabels:
      app: ${{ values.name }}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # Database (example)
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
```

## Summary

DevSecOps success requires:
- **Culture**: Security is everyone's responsibility
- **Automation**: Security gates in every pipeline
- **Measurement**: Track security metrics continuously
- **Training**: Invest in security champions and education
- **Platforms**: Provide secure-by-default golden paths

Key principles:
1. Shift security left into design and development
2. Automate security testing and enforcement
3. Build security champions in every team
4. Measure and improve continuously
5. Make secure choices the easy choices

## References

- [OWASP SAMM](https://owaspsamm.org/)
- [NIST Secure Software Development Framework](https://csrc.nist.gov/Projects/ssdf)
- [DevSecOps Playbook](https://www.devsecops.org/)
- [BSIMM (Building Security In Maturity Model)](https://www.bsimm.com/)
- [Security Champions Playbook](https://github.com/c0rdis/security-champions-playbook)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Introduction to DevSecOps
- Security in the SDLC
- Security Champions Program
- Security Metrics and Maturity

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
