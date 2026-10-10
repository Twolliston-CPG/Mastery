# Module 08: Compliance Frameworks

## Learning Objectives

By the end of this module, you will be able to:
- Understand major compliance frameworks (SOC 2, ISO 27001, PCI DSS, HIPAA)
- Implement compliance controls as code
- Automate compliance evidence collection
- Prepare for compliance audits
- Build compliance into CI/CD pipelines

## Compliance Frameworks Overview

### Framework Comparison

| Framework | Focus | Industry | Key Requirements |
|-----------|-------|----------|------------------|
| SOC 2 | Service Organizations | SaaS, Cloud | Trust Services Criteria |
| ISO 27001 | Information Security | Any | ISMS Implementation |
| PCI DSS | Payment Card Data | Financial | 12 Requirements |
| HIPAA | Health Information | Healthcare | Privacy & Security Rules |
| GDPR | Data Protection | Any (EU data) | Data Subject Rights |
| FedRAMP | Federal Cloud | Government | NIST 800-53 Controls |

### SOC 2 Trust Services Criteria

**SOC 2 Trust Services Criteria**

| Criterion | Required? | Covers |
|---|---|---|
| **Security** | **Yes — in every SOC 2 report** | logical and physical access controls · system operations and monitoring · change management · risk mitigation |
| Availability | optional | uptime commitments · capacity · disaster recovery |
| Processing integrity | optional | complete, valid, accurate, timely processing |
| Confidentiality | optional | protection of information designated confidential |
| Privacy | optional | collection, use, retention and disposal of personal information |

Most vendors report on **Security** alone, sometimes plus Availability. "SOC 2 compliant" on its own
does not say which criteria were in scope — that is a reasonable question to ask a vendor, and a
good thing to know in an interview.

A **Type I** report assesses the design of controls at a point in time; a **Type II** assesses their
operating effectiveness over a period, usually 6–12 months. Type II is the one that means something.

## Compliance as Code

### Policy Definitions

```yaml
# compliance-policies/soc2-security.yaml
apiVersion: compliance.company.com/v1
kind: CompliancePolicy
metadata:
  name: soc2-security-controls
  labels:
    framework: soc2
    category: security
spec:
  controls:
    - id: CC6.1
      name: "Logical Access Security Software"
      description: "The entity implements logical access security software"
      checks:
        - type: kubernetes
          resource: pods
          rule: |
            spec.securityContext.runAsNonRoot == true
        - type: aws
          service: iam
          rule: |
            all IAM users have MFA enabled
        - type: code
          tool: semgrep
          rule: |
            no hardcoded credentials

    - id: CC6.2
      name: "Authentication Mechanisms"
      description: "Prior to issuing system credentials and granting access"
      checks:
        - type: configuration
          target: identity-provider
          rule: |
            password_policy.min_length >= 12
            password_policy.require_mfa == true

    - id: CC6.6
      name: "System Boundary Protection"
      description: "The entity implements boundary protection"
      checks:
        - type: kubernetes
          resource: networkpolicies
          rule: |
            default deny policy exists for all namespaces
        - type: aws
          service: vpc
          rule: |
            security groups follow least privilege

    - id: CC7.1
      name: "Security Event Monitoring"
      description: "The entity monitors system components"
      checks:
        - type: configuration
          target: logging
          rule: |
            audit_logging.enabled == true
            log_retention_days >= 365
```

### Automated Compliance Checks

```python
# compliance_checker.py
from dataclasses import dataclass
from typing import List, Dict, Any
from enum import Enum
import yaml

class ComplianceStatus(Enum):
    PASS = "pass"
    FAIL = "fail"
    WARNING = "warning"
    NOT_APPLICABLE = "n/a"

@dataclass
class ControlResult:
    control_id: str
    control_name: str
    status: ComplianceStatus
    evidence: Dict[str, Any]
    findings: List[str]

class ComplianceChecker:
    def __init__(self, policy_path: str):
        with open(policy_path) as f:
            self.policy = yaml.safe_load(f)

    async def check_all_controls(self) -> List[ControlResult]:
        """Run all compliance checks."""
        results = []

        for control in self.policy['spec']['controls']:
            result = await self.check_control(control)
            results.append(result)

        return results

    async def check_control(self, control: dict) -> ControlResult:
        """Check a single compliance control."""
        findings = []
        evidence = {}

        for check in control['checks']:
            if check['type'] == 'kubernetes':
                check_result = await self.check_kubernetes(check)
            elif check['type'] == 'aws':
                check_result = await self.check_aws(check)
            elif check['type'] == 'code':
                check_result = await self.check_code(check)
            elif check['type'] == 'configuration':
                check_result = await self.check_configuration(check)

            evidence[check['type']] = check_result['evidence']
            if not check_result['passed']:
                findings.extend(check_result['findings'])

        status = ComplianceStatus.PASS if not findings else ComplianceStatus.FAIL

        return ControlResult(
            control_id=control['id'],
            control_name=control['name'],
            status=status,
            evidence=evidence,
            findings=findings
        )

    async def check_kubernetes(self, check: dict) -> dict:
        """Check Kubernetes resources for compliance."""
        from kubernetes import client, config

        config.load_incluster_config()
        v1 = client.CoreV1Api()

        findings = []
        evidence = []

        if check['resource'] == 'pods':
            pods = v1.list_pod_for_all_namespaces()
            for pod in pods.items:
                if pod.metadata.namespace in ['kube-system']:
                    continue

                # Check security context
                if not pod.spec.security_context:
                    findings.append(
                        f"Pod {pod.metadata.namespace}/{pod.metadata.name} "
                        "has no security context"
                    )
                elif not pod.spec.security_context.run_as_non_root:
                    findings.append(
                        f"Pod {pod.metadata.namespace}/{pod.metadata.name} "
                        "can run as root"
                    )
                else:
                    evidence.append({
                        "pod": f"{pod.metadata.namespace}/{pod.metadata.name}",
                        "runAsNonRoot": True
                    })

        return {
            "passed": len(findings) == 0,
            "findings": findings,
            "evidence": evidence
        }

    async def check_aws(self, check: dict) -> dict:
        """Check AWS resources for compliance."""
        import boto3

        findings = []
        evidence = []

        if check['service'] == 'iam':
            iam = boto3.client('iam')

            # Check MFA for all users
            users = iam.list_users()['Users']
            for user in users:
                mfa_devices = iam.list_mfa_devices(UserName=user['UserName'])
                if not mfa_devices['MFADevices']:
                    findings.append(f"User {user['UserName']} has no MFA enabled")
                else:
                    evidence.append({
                        "user": user['UserName'],
                        "mfa_enabled": True
                    })

        return {
            "passed": len(findings) == 0,
            "findings": findings,
            "evidence": evidence
        }

    def generate_report(self, results: List[ControlResult]) -> dict:
        """Generate compliance report."""
        total = len(results)
        passed = sum(1 for r in results if r.status == ComplianceStatus.PASS)
        failed = sum(1 for r in results if r.status == ComplianceStatus.FAIL)

        return {
            "summary": {
                "total_controls": total,
                "passed": passed,
                "failed": failed,
                "compliance_percentage": (passed / total) * 100 if total > 0 else 0
            },
            "controls": [
                {
                    "id": r.control_id,
                    "name": r.control_name,
                    "status": r.status.value,
                    "findings": r.findings,
                    "evidence_count": len(r.evidence)
                }
                for r in results
            ]
        }
```

## Evidence Collection

### Automated Evidence Collection

```python
# evidence_collector.py
import boto3
from datetime import datetime, timedelta
from typing import Dict, Any, List
import json

class EvidenceCollector:
    def __init__(self, s3_bucket: str):
        self.s3 = boto3.client('s3')
        self.bucket = s3_bucket
        self.timestamp = datetime.utcnow().strftime('%Y-%m-%d')

    async def collect_all_evidence(self) -> Dict[str, Any]:
        """Collect evidence for all compliance controls."""
        evidence = {
            "collection_date": self.timestamp,
            "categories": {}
        }

        # Access Controls
        evidence["categories"]["access_controls"] = await self.collect_access_evidence()

        # Change Management
        evidence["categories"]["change_management"] = await self.collect_change_evidence()

        # Monitoring
        evidence["categories"]["monitoring"] = await self.collect_monitoring_evidence()

        # Encryption
        evidence["categories"]["encryption"] = await self.collect_encryption_evidence()

        # Store evidence
        await self.store_evidence(evidence)

        return evidence

    async def collect_access_evidence(self) -> Dict[str, Any]:
        """Collect access control evidence."""
        iam = boto3.client('iam')

        evidence = {
            "users": [],
            "roles": [],
            "policies": [],
            "mfa_status": []
        }

        # List all users and their policies
        for user in iam.list_users()['Users']:
            user_info = {
                "username": user['UserName'],
                "created": user['CreateDate'].isoformat(),
                "password_last_used": user.get('PasswordLastUsed', 'Never').isoformat()
                    if user.get('PasswordLastUsed') else 'Never',
                "attached_policies": [],
                "groups": []
            }

            # Get attached policies
            policies = iam.list_attached_user_policies(UserName=user['UserName'])
            user_info["attached_policies"] = [p['PolicyName'] for p in policies['AttachedPolicies']]

            # Get groups
            groups = iam.list_groups_for_user(UserName=user['UserName'])
            user_info["groups"] = [g['GroupName'] for g in groups['Groups']]

            # Check MFA
            mfa = iam.list_mfa_devices(UserName=user['UserName'])
            user_info["mfa_enabled"] = len(mfa['MFADevices']) > 0

            evidence["users"].append(user_info)

        # Get password policy
        try:
            password_policy = iam.get_account_password_policy()
            evidence["password_policy"] = password_policy['PasswordPolicy']
        except iam.exceptions.NoSuchEntityException:
            evidence["password_policy"] = "No password policy configured"

        return evidence

    async def collect_change_evidence(self) -> Dict[str, Any]:
        """Collect change management evidence."""
        evidence = {
            "deployments": [],
            "pull_requests": [],
            "approvals": []
        }

        # Get recent deployments from ArgoCD
        # This would integrate with your deployment system
        deployments = await self.get_argocd_deployments()
        evidence["deployments"] = deployments

        # Get pull request data from GitHub
        # This would integrate with GitHub API
        prs = await self.get_github_prs()
        evidence["pull_requests"] = prs

        return evidence

    async def collect_monitoring_evidence(self) -> Dict[str, Any]:
        """Collect monitoring and logging evidence."""
        cloudwatch = boto3.client('cloudwatch')
        logs = boto3.client('logs')

        evidence = {
            "alarms": [],
            "log_groups": [],
            "metrics": []
        }

        # Get CloudWatch alarms
        alarms = cloudwatch.describe_alarms()
        evidence["alarms"] = [
            {
                "name": a['AlarmName'],
                "metric": a['MetricName'],
                "state": a['StateValue'],
                "actions": a['AlarmActions']
            }
            for a in alarms['MetricAlarms']
        ]

        # Get log groups and retention
        log_groups = logs.describe_log_groups()
        evidence["log_groups"] = [
            {
                "name": lg['logGroupName'],
                "retention_days": lg.get('retentionInDays', 'Never expires'),
                "stored_bytes": lg.get('storedBytes', 0)
            }
            for lg in log_groups['logGroups']
        ]

        return evidence

    async def collect_encryption_evidence(self) -> Dict[str, Any]:
        """Collect encryption evidence."""
        s3 = boto3.client('s3')
        rds = boto3.client('rds')
        kms = boto3.client('kms')

        evidence = {
            "s3_buckets": [],
            "rds_instances": [],
            "kms_keys": []
        }

        # Check S3 bucket encryption
        buckets = s3.list_buckets()
        for bucket in buckets['Buckets']:
            try:
                encryption = s3.get_bucket_encryption(Bucket=bucket['Name'])
                evidence["s3_buckets"].append({
                    "name": bucket['Name'],
                    "encryption": encryption['ServerSideEncryptionConfiguration']
                })
            except s3.exceptions.ClientError:
                evidence["s3_buckets"].append({
                    "name": bucket['Name'],
                    "encryption": "Not configured"
                })

        # Check RDS encryption
        instances = rds.describe_db_instances()
        for db in instances['DBInstances']:
            evidence["rds_instances"].append({
                "identifier": db['DBInstanceIdentifier'],
                "encrypted": db['StorageEncrypted'],
                "kms_key": db.get('KmsKeyId', 'N/A')
            })

        # List KMS keys
        keys = kms.list_keys()
        for key in keys['Keys']:
            key_info = kms.describe_key(KeyId=key['KeyId'])
            evidence["kms_keys"].append({
                "id": key['KeyId'],
                "description": key_info['KeyMetadata'].get('Description', ''),
                "enabled": key_info['KeyMetadata']['Enabled'],
                "rotation_enabled": key_info['KeyMetadata'].get('KeyRotationEnabled', False)
            })

        return evidence

    async def store_evidence(self, evidence: Dict[str, Any]):
        """Store evidence in S3."""
        key = f"compliance-evidence/{self.timestamp}/evidence.json"

        self.s3.put_object(
            Bucket=self.bucket,
            Key=key,
            Body=json.dumps(evidence, indent=2, default=str),
            ServerSideEncryption='aws:kms'
        )
```

## Compliance CI/CD Integration

```yaml
# .github/workflows/compliance.yml
name: Compliance Checks
on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 0 * * *'  # Daily

jobs:
  compliance-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # SOC 2 - Security scanning
      - name: SAST Scan (CC6.1)
        uses: returntocorp/semgrep-action@v1
        with:
          config: p/security-audit

      # SOC 2 - Dependency scanning
      - name: SCA Scan (CC6.8)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'CRITICAL,HIGH'

      # SOC 2 - Infrastructure scanning
      - name: IaC Security Scan (CC6.6)
        uses: bridgecrewio/checkov-action@master
        with:
          directory: terraform/
          framework: terraform

      # Custom compliance checks
      - name: Run Compliance Checks
        run: |
          python compliance_checker.py \
            --policy compliance-policies/soc2-security.yaml \
            --output compliance-report.json

      - name: Upload Compliance Report
        uses: actions/upload-artifact@v4
        with:
          name: compliance-report
          path: compliance-report.json

      # Fail if critical findings
      - name: Check Compliance Status
        run: |
          FAILURES=$(jq '.summary.failed' compliance-report.json)
          if [ "$FAILURES" -gt 0 ]; then
            echo "Compliance check failed with $FAILURES failures"
            exit 1
          fi

  evidence-collection:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    needs: compliance-scan
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Collect Evidence
        run: |
          python evidence_collector.py \
            --bucket ${{ secrets.EVIDENCE_BUCKET }}

      - name: Generate Compliance Dashboard
        run: |
          python generate_dashboard.py \
            --input compliance-report.json \
            --output dashboard.html
```

## Audit Preparation

### Audit Readiness Checklist

```yaml
# audit-checklist.yaml
audit_preparation:
  documentation:
    - name: "System Description"
      status: required
      owner: "Platform Team"
      artifacts:
        - architecture_diagrams
        - data_flow_diagrams
        - network_diagrams

    - name: "Security Policies"
      status: required
      owner: "Security Team"
      artifacts:
        - information_security_policy
        - access_control_policy
        - incident_response_policy
        - change_management_policy

    - name: "Risk Assessment"
      status: required
      owner: "Security Team"
      artifacts:
        - risk_register
        - risk_treatment_plan
        - vulnerability_assessment

  evidence_requirements:
    access_controls:
      - user_access_reviews
      - privileged_access_logs
      - mfa_enrollment_reports
      - terminated_user_removal

    change_management:
      - change_requests
      - approval_records
      - deployment_logs
      - rollback_procedures

    monitoring:
      - security_event_logs
      - alert_configurations
      - incident_tickets
      - vulnerability_scans

    availability:
      - uptime_reports
      - backup_logs
      - dr_test_results
      - capacity_planning

  interview_preparation:
    topics:
      - security_awareness_training
      - incident_response_procedures
      - access_provisioning_process
      - change_management_workflow
      - vendor_management
```

## Summary

Compliance frameworks require systematic implementation:

1. **Understand Requirements** - Know which frameworks apply to your organization
2. **Implement Controls** - Build security controls into your infrastructure
3. **Automate Checks** - Use compliance-as-code for continuous monitoring
4. **Collect Evidence** - Automate evidence collection for audits
5. **Continuous Improvement** - Treat compliance as an ongoing process

## Additional Resources

- [AICPA SOC 2 Guide](https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2)
- [ISO 27001 Standard](https://www.iso.org/isoiec-27001-information-security.html)
- [PCI DSS Requirements](https://www.pcisecuritystandards.org/)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/)

## Next Module

Continue to [Module 09: Security Monitoring](module-09-security-monitoring.md) to learn about SIEM and security event management.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Compliance Frameworks Overview
- Compliance as Code
- Evidence Collection
- Compliance CI/CD Integration

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
