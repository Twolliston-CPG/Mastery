# Module 02: Infrastructure Security

## Learning Objectives

By the end of this module, you will be able to:
- Implement secure infrastructure configurations
- Apply CIS benchmarks for hardening
- Configure secure cloud infrastructure
- Implement network security controls
- Use Infrastructure as Code security scanning

## Operating System Hardening

### CIS Benchmarks

The Center for Internet Security (CIS) provides hardening guidelines for operating systems.

```bash
# Example: Linux hardening based on CIS Benchmarks

# 1. Disable unused filesystems
cat >> /etc/modprobe.d/CIS.conf << EOF
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
EOF

# 2. Set secure permissions on boot loader
chown root:root /boot/grub2/grub.cfg
chmod og-rwx /boot/grub2/grub.cfg

# 3. Configure password requirements
cat > /etc/security/pwquality.conf << EOF
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
EOF

# 4. Set account lockout policy
cat >> /etc/pam.d/common-auth << EOF
auth required pam_tally2.so onerr=fail audit silent deny=5 unlock_time=900
EOF

# 5. Disable root login via SSH
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# 6. Configure SSH hardening
cat >> /etc/ssh/sshd_config << EOF
Protocol 2
MaxAuthTries 4
PermitEmptyPasswords no
PasswordAuthentication no
ClientAliveInterval 300
ClientAliveCountMax 0
AllowUsers deploy admin
EOF

# 7. Enable audit logging
systemctl enable auditd
systemctl start auditd
```

### Automated Hardening with Ansible

```yaml
# hardening-playbook.yaml
---
- name: Apply CIS hardening
  hosts: all
  become: yes
  vars:
    ssh_allowed_users:
      - deploy
      - admin
    password_min_length: 14
    password_max_age: 90
    audit_log_retention: 365

  tasks:
    - name: Disable unnecessary services
      systemd:
        name: "{{ item }}"
        state: stopped
        enabled: no
      loop:
        - cups
        - avahi-daemon
        - bluetooth
      ignore_errors: yes

    - name: Configure SSH hardening
      template:
        src: templates/sshd_config.j2
        dest: /etc/ssh/sshd_config
        owner: root
        group: root
        mode: '0600'
      notify: restart sshd

    - name: Set password policy
      lineinfile:
        path: /etc/login.defs
        regexp: "^{{ item.key }}"
        line: "{{ item.key }} {{ item.value }}"
      loop:
        - { key: 'PASS_MAX_DAYS', value: '{{ password_max_age }}' }
        - { key: 'PASS_MIN_DAYS', value: '7' }
        - { key: 'PASS_MIN_LEN', value: '{{ password_min_length }}' }
        - { key: 'PASS_WARN_AGE', value: '7' }

    - name: Configure auditd rules
      template:
        src: templates/audit.rules.j2
        dest: /etc/audit/rules.d/audit.rules
        owner: root
        group: root
        mode: '0600'
      notify: restart auditd

    - name: Enable firewall
      ufw:
        state: enabled
        policy: deny
        direction: incoming

    - name: Allow SSH
      ufw:
        rule: allow
        port: '22'
        proto: tcp

    - name: Configure automatic security updates
      apt:
        name: unattended-upgrades
        state: present
      when: ansible_os_family == "Debian"

  handlers:
    - name: restart sshd
      systemd:
        name: sshd
        state: restarted

    - name: restart auditd
      systemd:
        name: auditd
        state: restarted
```

## Cloud Infrastructure Security

### AWS Security Best Practices

```hcl
# Secure VPC Configuration
resource "aws_vpc" "secure_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "secure-vpc"
  }
}

# Enable VPC Flow Logs
resource "aws_flow_log" "vpc_flow_log" {
  vpc_id                   = aws_vpc.secure_vpc.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn             = aws_iam_role.flow_logs_role.arn
  max_aggregation_interval = 60

  tags = {
    Name = "vpc-flow-logs"
  }
}

# Private subnets (no direct internet access)
resource "aws_subnet" "private" {
  count                   = 3
  vpc_id                  = aws_vpc.secure_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-${count.index + 1}"
    Tier = "private"
  }
}

# Security Group with least privilege
resource "aws_security_group" "app_sg" {
  name        = "app-security-group"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.secure_vpc.id

  # Only allow specific ingress
  ingress {
    description     = "HTTPS from load balancer"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Restrict egress to necessary destinations
  egress {
    description = "HTTPS to AWS services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Consider using VPC endpoints instead
  }

  egress {
    description     = "Database access"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.db_sg.id]
  }

  tags = {
    Name = "app-sg"
  }
}

# Encrypted EBS volumes
resource "aws_ebs_volume" "encrypted_volume" {
  availability_zone = "us-east-1a"
  size              = 100
  encrypted         = true
  kms_key_id        = aws_kms_key.ebs_key.arn

  tags = {
    Name = "encrypted-volume"
  }
}

# KMS Key for encryption
resource "aws_kms_key" "ebs_key" {
  description             = "KMS key for EBS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 Service"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "ebs-encryption-key"
  }
}

# S3 Bucket with security best practices
resource "aws_s3_bucket" "secure_bucket" {
  bucket = "my-secure-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "secure-bucket"
  }
}

resource "aws_s3_bucket_versioning" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "s3-access-logs/"
}
```

### AWS IAM Security

```hcl
# IAM Role with least privilege
resource "aws_iam_role" "app_role" {
  name = "app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = {
    Name = "app-role"
  }
}

# Specific policy - not AdministratorAccess
resource "aws_iam_role_policy" "app_policy" {
  name = "app-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.app_bucket.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:app/*"
        ]
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          aws_kms_key.app_key.arn
        ]
      }
    ]
  })
}

# Service Control Policy (SCP) for organization
resource "aws_organizations_policy" "security_baseline" {
  name        = "security-baseline"
  description = "Enforce security baseline across organization"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnencryptedS3"
        Effect = "Deny"
        Action = "s3:PutObject"
        Resource = "*"
        Condition = {
          Null = {
            "s3:x-amz-server-side-encryption" = "true"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedRDS"
        Effect = "Deny"
        Action = [
          "rds:CreateDBInstance",
          "rds:CreateDBCluster"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "rds:StorageEncrypted" = "false"
          }
        }
      },
      {
        Sid    = "RequireMFA"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      },
      {
        Sid    = "DenyLeaveOrganization"
        Effect = "Deny"
        Action = [
          "organizations:LeaveOrganization"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## Network Security

### Firewall Configuration

```yaml
# Network Policy (Kubernetes)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-network-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: web-app
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow traffic from ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
          podSelector:
            matchLabels:
              app: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080
  egress:
    # Allow DNS
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
    # Allow database access
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
    # Allow external HTTPS
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
      ports:
        - protocol: TCP
          port: 443
```

### Web Application Firewall (WAF)

```hcl
# AWS WAF Configuration
resource "aws_wafv2_web_acl" "main" {
  name        = "main-waf"
  description = "WAF for web application"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rules - Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  # Geo blocking rule
  rule {
    name     = "GeoBlockRule"
    priority = 4

    action {
      block {}
    }

    statement {
      geo_match_statement {
        country_codes = ["CN", "RU", "KP"]  # Example blocked countries
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoBlockRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  # Custom rule for specific paths
  rule {
    name     = "ProtectAdminPaths"
    priority = 5

    action {
      block {}
    }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "/admin"
            positional_constraint = "STARTS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          not_statement {
            statement {
              ip_set_reference_statement {
                arn = aws_wafv2_ip_set.admin_ips.arn
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ProtectAdminPathsMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "mainWafMetric"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "main-waf"
  }
}
```

## Infrastructure as Code Security

### Terraform Security Scanning

```yaml
# tfsec scanning in CI/CD
name: Infrastructure Security
on:
  pull_request:
    paths:
      - 'terraform/**'

jobs:
  tfsec:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          working_directory: terraform/
          soft_fail: false
          format: sarif
          out: tfsec.sarif

      - name: Upload SARIF file
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: tfsec.sarif

  checkov:
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
          soft_fail: false

      - name: Upload Checkov results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: checkov.sarif
```

### Custom Security Policies

```python
# custom_policies/aws_security.py
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
from checkov.common.models.enums import CheckCategories, CheckResult

class S3BucketEncryptionCheck(BaseResourceCheck):
    def __init__(self):
        name = "Ensure S3 bucket has server-side encryption enabled"
        id = "CUSTOM_AWS_001"
        supported_resources = ['aws_s3_bucket']
        categories = [CheckCategories.ENCRYPTION]
        super().__init__(name=name, id=id, categories=categories,
                        supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        # Check for encryption configuration
        if 'server_side_encryption_configuration' in conf:
            encryption_conf = conf['server_side_encryption_configuration']
            if encryption_conf and len(encryption_conf) > 0:
                rule = encryption_conf[0].get('rule', [{}])[0]
                apply_sse = rule.get('apply_server_side_encryption_by_default', [{}])[0]
                if apply_sse.get('sse_algorithm'):
                    return CheckResult.PASSED
        return CheckResult.FAILED

class RDSEncryptionCheck(BaseResourceCheck):
    def __init__(self):
        name = "Ensure RDS instance has encryption enabled"
        id = "CUSTOM_AWS_002"
        supported_resources = ['aws_db_instance']
        categories = [CheckCategories.ENCRYPTION]
        super().__init__(name=name, id=id, categories=categories,
                        supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        storage_encrypted = conf.get('storage_encrypted', [False])
        if isinstance(storage_encrypted, list):
            storage_encrypted = storage_encrypted[0]
        return CheckResult.PASSED if storage_encrypted else CheckResult.FAILED

check_s3 = S3BucketEncryptionCheck()
check_rds = RDSEncryptionCheck()
```

## Audit Logging

### CloudTrail Configuration

```hcl
# AWS CloudTrail for audit logging
resource "aws_cloudtrail" "main" {
  name                          = "main-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.cloudtrail.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  insight_selector {
    insight_type = "ApiErrorRateInsight"
  }

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  tags = {
    Name = "main-cloudtrail"
  }
}

# CloudWatch Alerts for security events
resource "aws_cloudwatch_metric_alarm" "root_login" {
  alarm_name          = "root-account-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "CloudTrailMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when root account is used"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

resource "aws_cloudwatch_log_metric_filter" "root_login" {
  name           = "RootAccountUsage"
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  metric_transformation {
    name      = "RootAccountUsage"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}
```

## Summary

Infrastructure security requires a comprehensive approach:

1. **OS Hardening** - Apply CIS benchmarks and security baselines
2. **Cloud Security** - Use native cloud security features and encryption
3. **Network Security** - Implement segmentation, WAF, and firewall rules
4. **IaC Security** - Scan infrastructure code for misconfigurations
5. **Audit Logging** - Enable comprehensive logging for compliance

## Additional Resources

- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [Terraform Security Best Practices](https://www.terraform.io/docs/cloud/architectural-details/security-model.html)
- [NIST Cloud Security Guidelines](https://csrc.nist.gov/publications/detail/sp/800-144/final)

## Next Module

Continue to [Module 03: Container Security](content-module-03-container-security.md) to learn about securing containers and container images.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Operating System Hardening
- Cloud Infrastructure Security
- Network Security
- Infrastructure as Code Security

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
