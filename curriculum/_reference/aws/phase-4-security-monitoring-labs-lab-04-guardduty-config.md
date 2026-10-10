# Lab 04 — GuardDuty & AWS Config

## Objective

Enable Amazon GuardDuty, generate sample findings, enable AWS Config, create compliance rules (S3 encryption required, restricted SSH), and review findings. This lab teaches you how to detect threats and enforce compliance.

## Prerequisites

- AWS CLI configured
- Python 3.9+ with `boto3`
- S3 bucket from earlier labs (or create one)

## Estimated Time: 60-75 minutes

## Cost Estimate

| Resource | Cost | Notes |
|----------|------|-------|
| GuardDuty | Free (30-day trial) | Disable after lab if beyond trial |
| Config | Free tier (25 rule evaluations/month) | Minimal cost if within free tier |
| S3 for Config delivery | Negligible | Tiny files |
| **Total** | **$0-0.50** | Mostly free tier |

---

## Part 1: Enable Amazon GuardDuty

### Step 1.1 — Enable GuardDuty (CLI)

```bash
# Enable GuardDuty in the current region
aws guardduty create-detector \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES \
  --tags Purpose=SAA-Lab

# Save the DetectorId from the output
DETECTOR_ID=$(aws guardduty list-detectors --query "DetectorIds[0]" --output text)
echo "Detector ID: $DETECTOR_ID"
```

### Step 1.2 — Verify GuardDuty Status

```bash
# Check detector status
aws guardduty get-detector --detector-id $DETECTOR_ID

# List data sources being monitored
aws guardduty get-detector --detector-id $DETECTOR_ID \
  --query "DataSources"
```

### Step 1.3 — Generate Sample Findings

```bash
# Generate sample findings to see what GuardDuty detects
aws guardduty create-sample-findings \
  --detector-id $DETECTOR_ID \
  --finding-types \
    "Backdoor:EC2/C&CActivity.B" \
    "CryptoCurrency:EC2/BitcoinTool.B" \
    "UnauthorizedAccess:IAMUser/MaliciousIPCaller.Custom" \
    "Recon:EC2/PortProbeUnprotectedPort" \
    "Exfiltration:S3/MaliciousIPCaller"

echo "Sample findings generated. Wait 30 seconds..."
sleep 30
```

### Step 1.4 — List and Examine Findings (CLI)

```bash
# List all findings
FINDING_IDS=$(aws guardduty list-findings \
  --detector-id $DETECTOR_ID \
  --query "FindingIds[:5]" \
  --output json)

echo "Finding IDs: $FINDING_IDS"

# Get details of the findings
aws guardduty get-findings \
  --detector-id $DETECTOR_ID \
  --finding-ids $FINDING_IDS \
  --query "Findings[*].{Type:Type,Severity:Severity,Title:Title}" \
  --output table
```

### Step 1.5 — Examine Findings with Boto3

Create `guardduty_findings.py`:

```python
"""
List and analyze GuardDuty findings.
Demonstrates how to programmatically review security threats.
"""

import boto3
import json
from datetime import datetime

def main():
    gd = boto3.client("guardduty")

    # Get detector ID
    detectors = gd.list_detectors()
    if not detectors["DetectorIds"]:
        print("No GuardDuty detectors found. Enable GuardDuty first.")
        return

    detector_id = detectors["DetectorIds"][0]
    print(f"Detector ID: {detector_id}")

    # List findings sorted by severity
    findings_response = gd.list_findings(
        DetectorId=detector_id,
        SortCriteria={
            "AttributeName": "severity",
            "OrderBy": "DESC"
        },
        MaxResults=10
    )

    finding_ids = findings_response["FindingIds"]
    if not finding_ids:
        print("No findings. Generate sample findings first.")
        return

    # Get detailed findings
    findings = gd.get_findings(
        DetectorId=detector_id,
        FindingIds=finding_ids
    )

    print(f"\n{'='*80}")
    print(f"{'GUARDDUTY FINDINGS':^80}")
    print(f"{'='*80}")

    for f in findings["Findings"]:
        severity = f["Severity"]
        if severity >= 7:
            level = "HIGH"
        elif severity >= 4:
            level = "MEDIUM"
        else:
            level = "LOW"

        print(f"\n  [{level}] {f['Type']}")
        print(f"  Severity: {severity}")
        print(f"  Title: {f['Title']}")
        print(f"  Description: {f['Description'][:120]}...")
        print(f"  Region: {f['Region']}")
        print(f"  Updated: {f['UpdatedAt']}")

        # Show affected resource
        resource = f.get("Resource", {})
        resource_type = resource.get("ResourceType", "Unknown")
        print(f"  Resource Type: {resource_type}")

        if resource_type == "Instance":
            instance_details = resource.get("InstanceDetails", {})
            print(f"  Instance ID: {instance_details.get('InstanceId', 'N/A')}")
        elif resource_type == "AccessKey":
            access_key = resource.get("AccessKeyDetails", {})
            print(f"  User: {access_key.get('UserName', 'N/A')}")
        print(f"  {'─'*70}")

    # Summary by severity
    print(f"\n{'='*80}")
    print("SUMMARY")
    high = sum(1 for f in findings["Findings"] if f["Severity"] >= 7)
    medium = sum(1 for f in findings["Findings"] if 4 <= f["Severity"] < 7)
    low = sum(1 for f in findings["Findings"] if f["Severity"] < 4)
    print(f"  HIGH: {high} | MEDIUM: {medium} | LOW: {low}")

if __name__ == "__main__":
    main()
```

```bash
python guardduty_findings.py
```

---

## Part 2: Enable AWS Config

### Step 2.1 — Create the Config Delivery S3 Bucket

```bash
CONFIG_BUCKET="saa-lab-config-$(aws sts get-caller-identity --query Account --output text)-$(date +%s)"

aws s3 mb s3://$CONFIG_BUCKET

# Add bucket policy to allow Config to deliver files
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws s3api put-bucket-policy --bucket $CONFIG_BUCKET --policy '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSConfigBucketPermissionsCheck",
      "Effect": "Allow",
      "Principal": { "Service": "config.amazonaws.com" },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::'$CONFIG_BUCKET'"
    },
    {
      "Sid": "AWSConfigBucketDelivery",
      "Effect": "Allow",
      "Principal": { "Service": "config.amazonaws.com" },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::'$CONFIG_BUCKET'/AWSLogs/'$ACCOUNT_ID'/Config/*",
      "Condition": {
        "StringEquals": { "s3:x-amz-acl": "bucket-owner-full-control" }
      }
    }
  ]
}'

echo "Config bucket created: $CONFIG_BUCKET"
```

### Step 2.2 — Create the Config Service Role

```bash
# Create the role for Config
aws iam create-role \
  --role-name saa-lab-config-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "config.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach the AWS managed policy
aws iam attach-role-policy \
  --role-name saa-lab-config-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWS_ConfigRole

# Wait for propagation
sleep 10
```

### Step 2.3 — Enable the Configuration Recorder

```bash
ROLE_ARN=$(aws iam get-role --role-name saa-lab-config-role --query "Role.Arn" --output text)

# Create configuration recorder
aws configservice put-configuration-recorder \
  --configuration-recorder name=default,roleARN=$ROLE_ARN \
  --recording-group allSupported=true,includeGlobalResourceTypes=true

# Create delivery channel
aws configservice put-delivery-channel \
  --delivery-channel name=default,s3BucketName=$CONFIG_BUCKET

# Start recording
aws configservice start-configuration-recorder --configuration-recorder-name default

echo "AWS Config is now recording resource configurations."
```

### Step 2.4 — Verify Config is Running

```bash
# Check recorder status
aws configservice describe-configuration-recorder-status

# Check delivery channel
aws configservice describe-delivery-channels
```

---

## Part 3: Create Config Rules

### Step 3.1 — S3 Bucket Encryption Rule

```bash
# Rule: All S3 buckets must have server-side encryption enabled
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "saa-lab-s3-encryption-required",
    "Description": "Checks that S3 buckets have server-side encryption enabled",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
    },
    "Scope": {
      "ComplianceResourceTypes": ["AWS::S3::Bucket"]
    }
  }'

echo "Config rule created: s3-encryption-required"
```

### Step 3.2 — Restricted SSH Rule

```bash
# Rule: No security group should allow unrestricted SSH (0.0.0.0/0 on port 22)
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "saa-lab-restricted-ssh",
    "Description": "Checks that security groups do not allow unrestricted SSH",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "INCOMING_SSH_DISABLED"
    },
    "Scope": {
      "ComplianceResourceTypes": ["AWS::EC2::SecurityGroup"]
    }
  }'

echo "Config rule created: restricted-ssh"
```

### Step 3.3 — Encrypted EBS Volumes Rule

```bash
# Rule: All EBS volumes must be encrypted
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "saa-lab-encrypted-volumes",
    "Description": "Checks that EBS volumes are encrypted",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "ENCRYPTED_VOLUMES"
    },
    "Scope": {
      "ComplianceResourceTypes": ["AWS::EC2::Volume"]
    }
  }'

echo "Config rule created: encrypted-volumes"
```

### Step 3.4 — Force Rule Evaluation

```bash
# Trigger evaluation for each rule
aws configservice start-config-rules-evaluation \
  --config-rule-names "saa-lab-s3-encryption-required" "saa-lab-restricted-ssh" "saa-lab-encrypted-volumes"

echo "Rule evaluation started. Wait 1-2 minutes for results..."
sleep 60
```

---

## Part 4: Review Config Compliance (Boto3)

Create `config_compliance.py`:

```python
"""
Check AWS Config compliance status for all rules.
Displays compliant and non-compliant resources.
"""

import boto3

def main():
    config = boto3.client("config")

    # Get compliance summary for all rules
    print("=" * 70)
    print("AWS CONFIG COMPLIANCE REPORT")
    print("=" * 70)

    rules = config.describe_config_rules(
        ConfigRuleNames=[
            "saa-lab-s3-encryption-required",
            "saa-lab-restricted-ssh",
            "saa-lab-encrypted-volumes"
        ]
    )

    for rule in rules["ConfigRules"]:
        rule_name = rule["ConfigRuleName"]
        print(f"\nRule: {rule_name}")
        print(f"  Description: {rule['Description']}")
        print(f"  State: {rule['ConfigRuleState']}")

        # Get compliance details
        try:
            compliance = config.get_compliance_details_by_config_rule(
                ConfigRuleName=rule_name,
                Limit=10
            )

            compliant = 0
            non_compliant = 0
            resources = []

            for result in compliance["EvaluationResults"]:
                status = result["ComplianceType"]
                resource_id = result["EvaluationResultIdentifier"]["EvaluationResultQualifier"]["ResourceId"]
                resource_type = result["EvaluationResultIdentifier"]["EvaluationResultQualifier"]["ResourceType"]

                if status == "COMPLIANT":
                    compliant += 1
                elif status == "NON_COMPLIANT":
                    non_compliant += 1
                    resources.append(f"{resource_type}: {resource_id}")

            print(f"  Compliant: {compliant} | Non-Compliant: {non_compliant}")

            if resources:
                print("  Non-compliant resources:")
                for r in resources:
                    print(f"    - {r}")
        except Exception as e:
            print(f"  Status: Evaluation pending or no results yet")

    print(f"\n{'='*70}")

if __name__ == "__main__":
    main()
```

```bash
python config_compliance.py
```

---

## Part 5: Create a Non-Compliant Resource and Observe

### Step 5.1 — Create an S3 Bucket Without Encryption

```bash
# Create a bucket WITHOUT default encryption
NONCOMPLIANT_BUCKET="saa-lab-noncompliant-$(date +%s)"
aws s3 mb s3://$NONCOMPLIANT_BUCKET

# Wait for Config to detect the new resource
echo "Created non-compliant bucket: $NONCOMPLIANT_BUCKET"
echo "Wait 2-3 minutes for Config to evaluate..."
sleep 120

# Trigger re-evaluation
aws configservice start-config-rules-evaluation \
  --config-rule-names "saa-lab-s3-encryption-required"

sleep 60
```

### Step 5.2 — Check Compliance Status

```bash
# Check if the bucket is non-compliant
aws configservice get-compliance-details-by-resource \
  --resource-type "AWS::S3::Bucket" \
  --resource-id "$NONCOMPLIANT_BUCKET" \
  --compliance-types "NON_COMPLIANT"
```

### Step 5.3 — Fix the Non-Compliance

```bash
# Enable encryption on the bucket
aws s3api put-bucket-encryption \
  --bucket $NONCOMPLIANT_BUCKET \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

echo "Encryption enabled. Config will re-evaluate on next cycle."

# Force re-evaluation
sleep 10
aws configservice start-config-rules-evaluation \
  --config-rule-names "saa-lab-s3-encryption-required"
```

---

## Cleanup

```bash
# --- GuardDuty ---
DETECTOR_ID=$(aws guardduty list-detectors --query "DetectorIds[0]" --output text)
aws guardduty delete-detector --detector-id $DETECTOR_ID
echo "GuardDuty detector deleted."

# --- Config Rules ---
aws configservice delete-config-rule --config-rule-name "saa-lab-s3-encryption-required"
aws configservice delete-config-rule --config-rule-name "saa-lab-restricted-ssh"
aws configservice delete-config-rule --config-rule-name "saa-lab-encrypted-volumes"

# Stop Config recorder
aws configservice stop-configuration-recorder --configuration-recorder-name default

# Delete Config recorder and delivery channel
aws configservice delete-delivery-channel --delivery-channel-name default
aws configservice delete-configuration-recorder --configuration-recorder-name default

# --- S3 buckets ---
aws s3 rm s3://$CONFIG_BUCKET --recursive
aws s3 rb s3://$CONFIG_BUCKET
aws s3 rb s3://$NONCOMPLIANT_BUCKET

# --- IAM ---
aws iam detach-role-policy --role-name saa-lab-config-role --policy-arn arn:aws:iam::aws:policy/service-role/AWS_ConfigRole
aws iam delete-role --role-name saa-lab-config-role

echo "Cleanup complete."
```

---

## Review Questions

1. What data sources does GuardDuty analyze?
2. Does GuardDuty prevent attacks or only detect them?
3. What is the difference between a Config managed rule and a custom rule?
4. How often does Config evaluate rules by default?
5. Can Config automatically remediate non-compliant resources?

## Answers

1. CloudTrail management/data events, VPC Flow Logs, DNS logs, EKS audit logs, RDS login activity, Lambda network activity.
2. GuardDuty only detects and reports findings. It does not block or prevent attacks. You must set up EventBridge rules with Lambda or SSM to automate responses.
3. Managed rules are pre-built by AWS (e.g., `S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED`). Custom rules use your own Lambda function to evaluate compliance.
4. Config evaluates when a resource configuration changes (configuration change trigger) or on a periodic schedule you define.
5. Yes — Config can trigger SSM Automation documents to automatically fix non-compliant resources.

---

## Next Lab

Proceed to **Lab 05: CloudWatch Monitoring** to create custom metrics, alarms, and dashboards.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Estimated Time: 60-75 minutes
- Enable Amazon GuardDuty
- Enable AWS Config
- Create Config Rules

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The security group allows the traffic."* |
| ✓ | *"A security group is a stateful allow-list attached to an ENI. Traffic matching an inbound rule is permitted and the reply is permitted automatically, because the connection is tracked — which is why you never write an outbound rule for a reply."* |

**Trace it:** A request from the internet to an instance in a private subnet. Name every hop, every route-table lookup, and every rule evaluated, in order.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — 15 minutes from the AWS Builders' Library, and it changes how you write every client you touch afterwards.
Full list per domain: [`SOURCES.md`](../SOURCES.md#aws)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
