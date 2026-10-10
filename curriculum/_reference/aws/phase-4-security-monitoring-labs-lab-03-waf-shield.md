# Lab 03 — WAF & Shield

## Objective

Create a WAF Web ACL with a rate-based rule and managed rule group, associate it with an ALB, and test the rules. Deploy with both CLI and Terraform. Understand Shield Standard (automatic) and Shield Advanced (when to use).

## Prerequisites

- AWS CLI configured
- Terraform installed (v1.0+)
- A VPC with public subnets (from Phase 1 or Phase 2 labs)
- Basic ALB knowledge (Phase 2)

## Estimated Time: 75-90 minutes

## Cost Estimate

| Resource | Cost | Notes |
|----------|------|-------|
| WAF Web ACL | $5/month (prorated) | **Delete immediately after lab** |
| WAF Rules | $1/month per rule | Delete with ACL |
| WAF Request inspection | ~$0.01 | Minimal traffic |
| ALB | ~$0.02/hour | Delete after lab |
| EC2 instance (optional) | Free tier | t2.micro |
| **Total** | **~$1-2** | Delete all resources immediately after lab |

**Budget Warning:** WAF charges $5/month per Web ACL even with zero traffic. Delete promptly.

---

## Part 1: Create a WAF Web ACL (CLI)

### Step 1.1 — Create an IP Set (for allow/block lists)

```bash
# Create an IP set to block specific IPs
aws wafv2 create-ip-set \
  --name "saa-lab-blocked-ips" \
  --scope REGIONAL \
  --ip-address-version IPV4 \
  --addresses "198.51.100.0/24" "203.0.113.0/24" \
  --description "IPs to block in SAA lab"

# Save the IP Set ID and ARN from the output
```

### Step 1.2 — Create the Web ACL

```bash
# Create Web ACL with multiple rule types
aws wafv2 create-web-acl \
  --name "saa-lab-web-acl" \
  --scope REGIONAL \
  --default-action '{"Allow": {}}' \
  --description "SAA Lab WAF Web ACL" \
  --visibility-config '{
    "SampledRequestsEnabled": true,
    "CloudWatchMetricsEnabled": true,
    "MetricName": "saaLabWebACL"
  }' \
  --rules '[
    {
      "Name": "RateLimitRule",
      "Priority": 1,
      "Statement": {
        "RateBasedStatement": {
          "Limit": 100,
          "AggregateKeyType": "IP"
        }
      },
      "Action": { "Block": {} },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "RateLimitRule"
      }
    },
    {
      "Name": "BlockBadIPs",
      "Priority": 2,
      "Statement": {
        "IPSetReferenceStatement": {
          "ARN": "YOUR_IP_SET_ARN"
        }
      },
      "Action": { "Block": {} },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "BlockBadIPs"
      }
    },
    {
      "Name": "AWSCommonRules",
      "Priority": 3,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesCommonRuleSet"
        }
      },
      "OverrideAction": { "None": {} },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "AWSCommonRules"
      }
    },
    {
      "Name": "AWSSQLiRules",
      "Priority": 4,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesSQLiRuleSet"
        }
      },
      "OverrideAction": { "None": {} },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "AWSSQLiRules"
      }
    }
  ]'

# Note: Replace YOUR_IP_SET_ARN with the actual ARN from Step 1.1
```

### Step 1.3 — List and Describe the Web ACL

```bash
# List Web ACLs
aws wafv2 list-web-acls --scope REGIONAL

# Describe the Web ACL
aws wafv2 get-web-acl \
  --name "saa-lab-web-acl" \
  --scope REGIONAL \
  --id "YOUR_WEB_ACL_ID"
```

### Step 1.4 — Associate with an ALB

```bash
# If you have an existing ALB, associate the Web ACL
# Replace with your ALB ARN
aws wafv2 associate-web-acl \
  --web-acl-arn "YOUR_WEB_ACL_ARN" \
  --resource-arn "YOUR_ALB_ARN"

# Verify association
aws wafv2 get-web-acl-for-resource \
  --resource-arn "YOUR_ALB_ARN"
```

---

## Part 2: Deploy WAF with Terraform

### Step 2.1 — Create Terraform Configuration

Create a directory and files:

```bash
mkdir -p /tmp/saa-lab-waf && cd /tmp/saa-lab-waf
```

Create `main.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- IP Set ---
resource "aws_wafv2_ip_set" "blocked_ips" {
  name               = "saa-lab-tf-blocked-ips"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = ["198.51.100.0/24", "203.0.113.0/24"]

  tags = {
    Purpose = "SAA-Lab"
  }
}

# --- Web ACL ---
resource "aws_wafv2_web_acl" "main" {
  name        = "saa-lab-tf-web-acl"
  scope       = "REGIONAL"
  description = "SAA Lab WAF Web ACL (Terraform)"

  default_action {
    allow {}
  }

  # Rule 1: Rate limiting
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
    }
  }

  # Rule 2: Block specific IPs
  rule {
    name     = "BlockBadIPs"
    priority = 2

    action {
      block {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.blocked_ips.arn
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockBadIPs"
    }
  }

  # Rule 3: AWS Managed Common Rule Set
  rule {
    name     = "AWSCommonRules"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSCommonRules"
    }
  }

  # Rule 4: AWS SQL Injection Rules
  rule {
    name     = "AWSSQLiRules"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSSQLiRules"
    }
  }

  # Rule 5: Geo blocking (block traffic from specific countries)
  rule {
    name     = "GeoBlockRule"
    priority = 5

    action {
      block {}
    }

    statement {
      geo_match_statement {
        country_codes = ["CN", "RU"]  # Example: block China and Russia
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoBlockRule"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "saaLabTFWebACL"
  }

  tags = {
    Purpose = "SAA-Lab"
  }
}

# --- Outputs ---
output "web_acl_arn" {
  value = aws_wafv2_web_acl.main.arn
}

output "web_acl_id" {
  value = aws_wafv2_web_acl.main.id
}

output "ip_set_arn" {
  value = aws_wafv2_ip_set.blocked_ips.arn
}
```

### Step 2.2 — Deploy with Terraform

```bash
cd /tmp/saa-lab-waf
terraform init
terraform plan
terraform apply -auto-approve
```

### Step 2.3 — Verify Deployment

```bash
# List Web ACLs (should show both CLI and Terraform versions)
aws wafv2 list-web-acls --scope REGIONAL

# Check WAF CloudWatch metrics
aws cloudwatch list-metrics --namespace "AWS/WAFV2" --dimensions Name=WebACL,Value=saa-lab-tf-web-acl
```

---

## Part 3: Test WAF Rules (Optional — Requires ALB)

If you have an ALB running from a previous lab:

### Step 3.1 — Test SQL Injection Blocking

```bash
# This request should be blocked by SQL injection rules
curl -v "http://YOUR_ALB_DNS/?id=1'+OR+'1'='1"

# This normal request should be allowed
curl -v "http://YOUR_ALB_DNS/"
```

### Step 3.2 — View Sampled Requests

```bash
# Get sampled requests for the Web ACL
aws wafv2 get-sampled-requests \
  --web-acl-arn "YOUR_WEB_ACL_ARN" \
  --rule-metric-name "AWSSQLiRules" \
  --scope REGIONAL \
  --time-window '{"StartTime": "2024-01-01T00:00:00Z", "EndTime": "2025-12-31T23:59:59Z"}' \
  --max-items 10
```

---

## Part 4: Shield Standard Verification

Shield Standard is automatic and free. Verify it is protecting your resources.

```bash
# Shield Standard is always enabled — you cannot see it directly
# Shield Advanced (paid) can be checked:
aws shield describe-subscription 2>/dev/null || echo "Shield Advanced is NOT enabled (this is expected — it costs \$3,000/month)"

# List protections (only shows Shield Advanced protections)
aws shield list-protections 2>/dev/null || echo "No Shield Advanced protections (expected)"
```

**Key takeaway:** Shield Standard provides automatic Layer 3/4 DDoS protection at no cost. You do not need to enable or configure it.

---

## Cleanup

**Important: WAF charges $5/month per Web ACL. Delete immediately.**

```bash
# --- Terraform cleanup ---
cd /tmp/saa-lab-waf
terraform destroy -auto-approve

# --- CLI cleanup ---
# 1. Disassociate from ALB (if associated)
aws wafv2 disassociate-web-acl --resource-arn "YOUR_ALB_ARN" 2>/dev/null

# 2. Delete Web ACL (need the ID and lock token)
WEB_ACL_INFO=$(aws wafv2 list-web-acls --scope REGIONAL --query "WebACLs[?Name=='saa-lab-web-acl']" --output json)
WEB_ACL_ID=$(echo $WEB_ACL_INFO | python -c "import sys,json; print(json.load(sys.stdin)[0]['Id'])")
LOCK_TOKEN=$(aws wafv2 get-web-acl --name saa-lab-web-acl --scope REGIONAL --id $WEB_ACL_ID --query "LockToken" --output text)
aws wafv2 delete-web-acl --name saa-lab-web-acl --scope REGIONAL --id $WEB_ACL_ID --lock-token $LOCK_TOKEN

# 3. Delete IP Set
IP_SET_INFO=$(aws wafv2 list-ip-sets --scope REGIONAL --query "IPSets[?Name=='saa-lab-blocked-ips']" --output json)
IP_SET_ID=$(echo $IP_SET_INFO | python -c "import sys,json; print(json.load(sys.stdin)[0]['Id'])")
IP_SET_LOCK=$(aws wafv2 get-ip-set --name saa-lab-blocked-ips --scope REGIONAL --id $IP_SET_ID --query "LockToken" --output text)
aws wafv2 delete-ip-set --name saa-lab-blocked-ips --scope REGIONAL --id $IP_SET_ID --lock-token $IP_SET_LOCK

# 4. Clean up Terraform directory
rm -rf /tmp/saa-lab-waf
```

---

## Review Questions

1. What is the minimum rate limit you can set in a WAF rate-based rule?
2. What is the difference between `Action` and `OverrideAction` in WAF rules?
3. Can you associate one Web ACL with multiple ALBs?
4. What does Shield Standard protect against, and does it cost anything?
5. Why would you choose Shield Advanced over Standard?

## Answers

1. 100 requests per 5-minute period.
2. `Action` (Allow/Block/Count) is used for your own rules. `OverrideAction` is used for managed rule groups — it lets you override the rule group's actions (use `None` to keep the group's actions, or `Count` to only count without blocking).
3. Yes, one Web ACL can be associated with multiple resources of the same type. But each resource can only have ONE Web ACL.
4. Shield Standard protects against Layer 3/4 DDoS attacks (SYN floods, UDP reflection, etc.) at no cost. It is always on.
5. Shield Advanced ($3K/month) provides: 24/7 DDoS Response Team, cost protection during attacks, advanced Layer 7 mitigation, real-time metrics, and WAF at no extra cost for protected resources.

---

## Next Lab

Proceed to **Lab 04: GuardDuty & Config** to enable threat detection and compliance monitoring.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Estimated Time: 75-90 minutes
- Create a WAF Web ACL (CLI)
- Deploy WAF with Terraform
- Test WAF Rules (Optional — Requires ALB)

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
