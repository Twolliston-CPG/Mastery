# Lab 8: Compliance as Code

## Objectives

- Implement compliance controls as code
- Automate compliance evidence collection
- Create audit-ready reports
- Build continuous compliance monitoring

## Prerequisites

- Kubernetes cluster
- AWS account
- Terraform knowledge
- Understanding of compliance frameworks (SOC 2, PCI-DSS)

## Duration

2.5 hours

## Part 1: Compliance Controls as Code (45 minutes)

### Task 1.1: AWS Config Rules

```hcl
# terraform/compliance/aws-config.tf
resource "aws_config_configuration_recorder" "main" {
  name     = "compliance-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported = true
    include_global_resources = true
  }
}

# CIS AWS Foundations Benchmark Rules
resource "aws_config_config_rule" "s3_bucket_encryption" {
  name = "s3-bucket-server-side-encryption-enabled"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }
  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "ec2_imdsv2" {
  name = "ec2-imdsv2-check"
  source {
    owner             = "AWS"
    source_identifier = "EC2_IMDSV2_CHECK"
  }
}

resource "aws_config_config_rule" "rds_encryption" {
  name = "rds-storage-encrypted"
  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }
}

resource "aws_config_config_rule" "root_mfa" {
  name = "root-account-mfa-enabled"
  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }
}
```

### Task 1.2: Kyverno Compliance Policies

```yaml
# compliance/kyverno-policies.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pci-dss-compliance
  annotations:
    compliance: "PCI-DSS-3.2.1"
    control: "2.2.1, 6.5.1"
spec:
  validationFailureAction: Enforce
  rules:
  - name: require-encryption-at-rest
    match:
      any:
      - resources:
          kinds: [PersistentVolumeClaim]
    validate:
      message: "PCI-DSS requires encryption at rest"
      pattern:
        spec:
          storageClassName: "encrypted-*"

  - name: require-network-policies
    match:
      any:
      - resources:
          kinds: [Deployment]
    preconditions:
      all:
      - key: "{{request.object.metadata.namespace}}"
        operator: NotEquals
        value: kube-system
    validate:
      message: "PCI-DSS requires network segmentation"
      deny:
        conditions:
          all:
          - key: "{{ request.object.metadata.namespace | x_network_policy_count(@) }}"
            operator: LessThan
            value: 1
```

## Part 2: Evidence Collection (45 minutes)

### Task 2.1: Automated Evidence Collection Script

```python
#!/usr/bin/env python3
# compliance/collect_evidence.py

import boto3
import json
import datetime
from pathlib import Path

class ComplianceEvidenceCollector:
    def __init__(self, output_dir: str = "evidence"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        self.timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

    def collect_aws_config_compliance(self):
        """Collect AWS Config compliance status."""
        config = boto3.client('config')

        # Get compliance summary
        response = config.get_compliance_summary_by_config_rule()

        evidence = {
            "collection_time": self.timestamp,
            "compliance_summary": response.get('ComplianceSummary', {}),
            "rules": []
        }

        # Get detailed rule compliance
        rules = config.describe_config_rules()
        for rule in rules.get('ConfigRules', []):
            compliance = config.get_compliance_details_by_config_rule(
                ConfigRuleName=rule['ConfigRuleName'],
                Limit=100
            )
            evidence["rules"].append({
                "rule_name": rule['ConfigRuleName'],
                "compliance_type": compliance.get('EvaluationResults', [{}])[0].get('ComplianceType', 'UNKNOWN'),
                "evaluation_results": compliance.get('EvaluationResults', [])
            })

        self._save_evidence("aws_config_compliance", evidence)
        return evidence

    def collect_iam_report(self):
        """Collect IAM credential report."""
        iam = boto3.client('iam')

        # Generate credential report
        iam.generate_credential_report()
        import time
        time.sleep(5)

        response = iam.get_credential_report()

        evidence = {
            "collection_time": self.timestamp,
            "report_format": response['ReportFormat'],
            "generated_time": str(response['GeneratedTime']),
            "content": response['Content'].decode('utf-8')
        }

        self._save_evidence("iam_credential_report", evidence)
        return evidence

    def collect_security_hub_findings(self):
        """Collect Security Hub findings."""
        securityhub = boto3.client('securityhub')

        findings = securityhub.get_findings(
            Filters={
                'RecordState': [{'Value': 'ACTIVE', 'Comparison': 'EQUALS'}],
                'WorkflowStatus': [{'Value': 'NEW', 'Comparison': 'EQUALS'}]
            },
            MaxResults=100
        )

        evidence = {
            "collection_time": self.timestamp,
            "findings_count": len(findings.get('Findings', [])),
            "findings": findings.get('Findings', [])
        }

        self._save_evidence("security_hub_findings", evidence)
        return evidence

    def collect_cloudtrail_events(self, hours: int = 24):
        """Collect CloudTrail events for audit."""
        cloudtrail = boto3.client('cloudtrail')

        end_time = datetime.datetime.utcnow()
        start_time = end_time - datetime.timedelta(hours=hours)

        events = cloudtrail.lookup_events(
            StartTime=start_time,
            EndTime=end_time,
            MaxResults=50
        )

        evidence = {
            "collection_time": self.timestamp,
            "time_range": f"{start_time} to {end_time}",
            "events_count": len(events.get('Events', [])),
            "events": [
                {
                    "event_name": e.get('EventName'),
                    "event_time": str(e.get('EventTime')),
                    "username": e.get('Username'),
                    "event_source": e.get('EventSource')
                }
                for e in events.get('Events', [])
            ]
        }

        self._save_evidence("cloudtrail_events", evidence)
        return evidence

    def _save_evidence(self, name: str, data: dict):
        """Save evidence to file."""
        filepath = self.output_dir / f"{name}_{self.timestamp}.json"
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2, default=str)
        print(f"Evidence saved: {filepath}")

if __name__ == "__main__":
    collector = ComplianceEvidenceCollector()
    collector.collect_aws_config_compliance()
    collector.collect_iam_report()
    collector.collect_security_hub_findings()
    collector.collect_cloudtrail_events()
```

### Task 2.2: Kubernetes Compliance Evidence

```python
#!/usr/bin/env python3
# compliance/k8s_evidence.py

from kubernetes import client, config
import json
import datetime

class K8sComplianceCollector:
    def __init__(self):
        config.load_kube_config()
        self.v1 = client.CoreV1Api()
        self.apps_v1 = client.AppsV1Api()
        self.rbac_v1 = client.RbacAuthorizationV1Api()
        self.networking_v1 = client.NetworkingV1Api()

    def collect_rbac_evidence(self):
        """Collect RBAC configuration evidence."""
        roles = self.rbac_v1.list_cluster_role()
        bindings = self.rbac_v1.list_cluster_role_binding()

        return {
            "collection_time": datetime.datetime.now().isoformat(),
            "cluster_roles": [
                {"name": r.metadata.name, "rules": [str(rule) for rule in (r.rules or [])]}
                for r in roles.items
            ],
            "cluster_role_bindings": [
                {"name": b.metadata.name, "role": b.role_ref.name, "subjects": str(b.subjects)}
                for b in bindings.items
            ]
        }

    def collect_network_policies(self):
        """Collect network policy evidence."""
        policies = self.networking_v1.list_network_policy_for_all_namespaces()

        return {
            "collection_time": datetime.datetime.now().isoformat(),
            "total_policies": len(policies.items),
            "policies_by_namespace": {}
        }

    def collect_pod_security(self):
        """Collect pod security configuration."""
        pods = self.v1.list_pod_for_all_namespaces()

        security_analysis = []
        for pod in pods.items:
            for container in pod.spec.containers:
                sc = container.security_context or {}
                security_analysis.append({
                    "namespace": pod.metadata.namespace,
                    "pod": pod.metadata.name,
                    "container": container.name,
                    "privileged": getattr(sc, 'privileged', False),
                    "run_as_root": getattr(sc, 'run_as_user', None) == 0,
                    "read_only_root": getattr(sc, 'read_only_root_filesystem', False)
                })

        return {
            "collection_time": datetime.datetime.now().isoformat(),
            "total_pods": len(pods.items),
            "security_analysis": security_analysis
        }
```

## Part 3: Compliance Reporting (45 minutes)

### Task 3.1: Generate Compliance Report

```python
#!/usr/bin/env python3
# compliance/generate_report.py

import json
from jinja2 import Template
from pathlib import Path

REPORT_TEMPLATE = """
# Compliance Report
Generated: {{ timestamp }}
Framework: {{ framework }}

## Executive Summary
- Total Controls: {{ total_controls }}
- Compliant: {{ compliant_count }} ({{ compliant_percent }}%)
- Non-Compliant: {{ non_compliant_count }}

## Control Assessment

{% for control in controls %}
### {{ control.id }}: {{ control.name }}
- **Status**: {{ control.status }}
- **Evidence**: {{ control.evidence_file }}
- **Description**: {{ control.description }}
{% if control.findings %}
- **Findings**:
{% for finding in control.findings %}
  - {{ finding }}
{% endfor %}
{% endif %}

{% endfor %}

## Recommendations
{% for rec in recommendations %}
- {{ rec }}
{% endfor %}
"""

class ComplianceReportGenerator:
    def __init__(self, framework: str):
        self.framework = framework
        self.controls = self._load_controls()

    def _load_controls(self):
        """Load control definitions for framework."""
        controls = {
            "SOC2": [
                {"id": "CC6.1", "name": "Logical Access Controls", "category": "Security"},
                {"id": "CC6.6", "name": "Encryption", "category": "Security"},
                {"id": "CC7.2", "name": "Security Monitoring", "category": "Security"},
            ],
            "PCI-DSS": [
                {"id": "2.2.1", "name": "System Hardening", "category": "Build"},
                {"id": "3.4", "name": "Data Encryption", "category": "Protect Data"},
                {"id": "6.5.1", "name": "Injection Flaws", "category": "Secure Development"},
            ]
        }
        return controls.get(self.framework, [])

    def generate_report(self, evidence_dir: str, output_file: str):
        """Generate compliance report from collected evidence."""
        evidence_path = Path(evidence_dir)

        # Assess each control
        assessed_controls = []
        for control in self.controls:
            assessment = self._assess_control(control, evidence_path)
            assessed_controls.append(assessment)

        # Calculate summary
        compliant = sum(1 for c in assessed_controls if c['status'] == 'Compliant')
        total = len(assessed_controls)

        # Render report
        template = Template(REPORT_TEMPLATE)
        report = template.render(
            timestamp=datetime.datetime.now().isoformat(),
            framework=self.framework,
            total_controls=total,
            compliant_count=compliant,
            non_compliant_count=total - compliant,
            compliant_percent=round(compliant/total*100, 1) if total > 0 else 0,
            controls=assessed_controls,
            recommendations=self._generate_recommendations(assessed_controls)
        )

        with open(output_file, 'w') as f:
            f.write(report)

        return report

    def _assess_control(self, control: dict, evidence_path: Path):
        """Assess a single control against evidence."""
        # Implementation would check actual evidence files
        return {
            **control,
            "status": "Compliant",
            "evidence_file": "evidence.json",
            "findings": []
        }

    def _generate_recommendations(self, controls):
        """Generate recommendations based on findings."""
        recommendations = []
        for control in controls:
            if control['status'] != 'Compliant':
                recommendations.append(f"Address {control['id']}: {control['name']}")
        return recommendations
```

## Verification

Complete the following checklist:

- [ ] Created AWS Config compliance rules
- [ ] Implemented Kyverno compliance policies
- [ ] Built evidence collection scripts
- [ ] Generated compliance reports
- [ ] Set up continuous compliance monitoring

## Summary

In this lab, you:
- Implemented compliance controls as code
- Automated evidence collection
- Created audit-ready compliance reports
- Built continuous compliance monitoring

## Next Steps

- Lab 9: Security Monitoring and SIEM
- Review SOC 2 Trust Services Criteria
- Study PCI-DSS requirements

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Compliance Controls as Code
- Evidence Collection
- Compliance Reporting
- Control Assessment

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
