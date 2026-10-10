# Lab 01: CloudFront Distribution with S3 Static Website

## Objective

Create an S3 static website, set up a CloudFront distribution with Origin Access Control (OAC), configure cache behaviors, and test cache invalidation. You will use the AWS CLI, Boto3, and Terraform to complete this lab.

## Estimated Cost

- **Free to $0.50.** CloudFront offers 1 TB of free data transfer and 10 million HTTP requests per month in the first 12 months. S3 storage for a few HTML files is negligible. Tear down when done to avoid any lingering charges.

## Prerequisites

- AWS CLI v2 configured with a named profile.
- Python 3.10+ with `boto3` installed.
- Terraform >= 1.5 installed.
- Completed Phase 5 notes 01-03.

## Architecture

```
User (Browser)
    |
    | HTTPS
    v
+-------------------+
| CloudFront        |
| Distribution      |
| (edge locations)  |
+-------------------+
    |
    | OAC (Origin Access Control)
    v
+-------------------+
| S3 Bucket         |
| (static website   |
|  files, NOT       |
|  public)          |
+-------------------+
```

**Key design point:** The S3 bucket is NOT configured as a public website. All access goes through CloudFront. The bucket policy only allows the CloudFront distribution (via OAC) to read objects.

---

## Part 1: Create the Static Website Files

Create a simple HTML website to serve through CloudFront.

### Create the website content

```bash
# Create a local directory for website files
mkdir -p ~/cloudfront-lab/website

cat > ~/cloudfront-lab/website/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CloudFront Lab - SAA-C03 Study</title>
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <h1>CloudFront + S3 Lab</h1>
    <p>This page is served through Amazon CloudFront with OAC.</p>
    <p>Version: 1.0</p>
    <p>If you can see this, your CloudFront distribution is working.</p>
    <img src="/images/architecture.png" alt="Architecture diagram placeholder">
</body>
</html>
EOF

cat > ~/cloudfront-lab/website/error.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>404 - Page Not Found</title>
</head>
<body>
    <h1>404 - Page Not Found</h1>
    <p>The page you requested does not exist.</p>
    <a href="/">Go Home</a>
</body>
</html>
EOF

mkdir -p ~/cloudfront-lab/website/css
cat > ~/cloudfront-lab/website/css/style.css << 'EOF'
body {
    font-family: Arial, sans-serif;
    max-width: 800px;
    margin: 50px auto;
    padding: 0 20px;
    background-color: #f5f5f5;
}
h1 { color: #232f3e; }
p { color: #545b64; line-height: 1.6; }
EOF
```

---

## Part 2: Deploy with AWS CLI

### Step 1: Create the S3 Bucket

```bash
BUCKET_NAME="cloudfront-lab-$(date +%s)"
AWS_REGION="us-east-1"

# Create the bucket
aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION

# Block all public access (CloudFront will access via OAC, not public URL)
aws s3api put-public-access-block \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Upload website files
aws s3 sync ~/cloudfront-lab/website/ s3://$BUCKET_NAME/ \
    --content-type "text/html" \
    --exclude "*.css" --exclude "*.png" --exclude "*.jpg"

aws s3 sync ~/cloudfront-lab/website/css/ s3://$BUCKET_NAME/css/ \
    --content-type "text/css"

echo "Bucket created: $BUCKET_NAME"
```

### Step 2: Create the CloudFront OAC

```bash
# Create Origin Access Control
OAC_ID=$(aws cloudfront create-origin-access-control \
    --origin-access-control-config \
    "Name=S3OAC-Lab,Description=OAC for CloudFront lab,SigningProtocol=sigv4,SigningBehavior=always,OriginAccessControlOriginType=s3" \
    --query 'OriginAccessControl.Id' --output text)

echo "OAC ID: $OAC_ID"
```

### Step 3: Create the CloudFront Distribution

```bash
# Create distribution configuration
cat > ~/cloudfront-lab/cf-config.json << CFEOF
{
    "CallerReference": "cloudfront-lab-$(date +%s)",
    "Comment": "CloudFront Lab - SAA-C03 Study",
    "Enabled": true,
    "DefaultRootObject": "index.html",
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "S3Origin",
                "DomainName": "${BUCKET_NAME}.s3.${AWS_REGION}.amazonaws.com",
                "OriginAccessControlId": "${OAC_ID}",
                "S3OriginConfig": {
                    "OriginAccessIdentity": ""
                }
            }
        ]
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3Origin",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"]
        },
        "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
        "Compress": true
    },
    "CustomErrorResponses": {
        "Quantity": 1,
        "Items": [
            {
                "ErrorCode": 403,
                "ResponseCode": "404",
                "ResponsePagePath": "/error.html",
                "ErrorCachingMinTTL": 300
            }
        ]
    },
    "PriceClass": "PriceClass_100",
    "ViewerCertificate": {
        "CloudFrontDefaultCertificate": true
    }
}
CFEOF

# Create the distribution
DISTRIBUTION_INFO=$(aws cloudfront create-distribution \
    --distribution-config file://~/cloudfront-lab/cf-config.json)

DISTRIBUTION_ID=$(echo $DISTRIBUTION_INFO | python3 -c "import sys, json; print(json.load(sys.stdin)['Distribution']['Id'])")
DISTRIBUTION_DOMAIN=$(echo $DISTRIBUTION_INFO | python3 -c "import sys, json; print(json.load(sys.stdin)['Distribution']['DomainName'])")

echo "Distribution ID: $DISTRIBUTION_ID"
echo "Distribution Domain: $DISTRIBUTION_DOMAIN"
```

### Step 4: Update S3 Bucket Policy for OAC

```bash
# Get the AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

# Create the bucket policy allowing CloudFront OAC
cat > ~/cloudfront-lab/bucket-policy.json << BPEOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCloudFrontServicePrincipalReadOnly",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "arn:aws:cloudfront::${ACCOUNT_ID}:distribution/${DISTRIBUTION_ID}"
                }
            }
        }
    ]
}
BPEOF

aws s3api put-bucket-policy \
    --bucket $BUCKET_NAME \
    --policy file://~/cloudfront-lab/bucket-policy.json

echo "Bucket policy applied."
```

### Step 5: Test the Distribution

```bash
# Wait for the distribution to deploy (this takes 5-15 minutes)
echo "Waiting for distribution to deploy..."
aws cloudfront wait distribution-deployed --id $DISTRIBUTION_ID
echo "Distribution deployed."

# Test with curl
curl -I https://$DISTRIBUTION_DOMAIN/
curl https://$DISTRIBUTION_DOMAIN/

# Check cache headers
curl -v https://$DISTRIBUTION_DOMAIN/index.html 2>&1 | grep -i "x-cache"
# Should show "Miss from cloudfront" on first request, "Hit from cloudfront" on second
```

---

## Part 3: Deploy with Boto3 (Python)

```python
#!/usr/bin/env python3
"""
CloudFront + S3 Lab - Boto3 Implementation
Creates an S3 bucket and CloudFront distribution with OAC.
"""

import boto3
import json
import time
import os

REGION = "us-east-1"
BUCKET_NAME = f"cloudfront-lab-boto3-{int(time.time())}"

s3 = boto3.client("s3", region_name=REGION)
cf = boto3.client("cloudfront")
sts = boto3.client("sts")

account_id = sts.get_caller_identity()["Account"]


def create_bucket():
    """Create S3 bucket with public access blocked."""
    print(f"Creating bucket: {BUCKET_NAME}")
    s3.create_bucket(Bucket=BUCKET_NAME)

    # Block all public access
    s3.put_public_access_block(
        Bucket=BUCKET_NAME,
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": True,
            "IgnorePublicAcls": True,
            "BlockPublicPolicy": True,
            "RestrictPublicBuckets": True,
        },
    )

    # Upload index.html
    s3.put_object(
        Bucket=BUCKET_NAME,
        Key="index.html",
        Body=b"<html><body><h1>CloudFront Lab (Boto3)</h1><p>Version 1.0</p></body></html>",
        ContentType="text/html",
    )

    # Upload error.html
    s3.put_object(
        Bucket=BUCKET_NAME,
        Key="error.html",
        Body=b"<html><body><h1>404 Not Found</h1></body></html>",
        ContentType="text/html",
    )

    print(f"Bucket created and files uploaded.")
    return BUCKET_NAME


def create_oac():
    """Create Origin Access Control."""
    print("Creating OAC...")
    response = cf.create_origin_access_control(
        OriginAccessControlConfig={
            "Name": f"S3OAC-Boto3-{int(time.time())}",
            "Description": "OAC for CloudFront Boto3 lab",
            "SigningProtocol": "sigv4",
            "SigningBehavior": "always",
            "OriginAccessControlOriginType": "s3",
        }
    )
    oac_id = response["OriginAccessControl"]["Id"]
    print(f"OAC created: {oac_id}")
    return oac_id


def create_distribution(oac_id):
    """Create CloudFront distribution with OAC."""
    print("Creating CloudFront distribution...")
    caller_reference = f"boto3-lab-{int(time.time())}"

    response = cf.create_distribution(
        DistributionConfig={
            "CallerReference": caller_reference,
            "Comment": "CloudFront Lab - Boto3",
            "Enabled": True,
            "DefaultRootObject": "index.html",
            "Origins": {
                "Quantity": 1,
                "Items": [
                    {
                        "Id": "S3Origin",
                        "DomainName": f"{BUCKET_NAME}.s3.{REGION}.amazonaws.com",
                        "OriginAccessControlId": oac_id,
                        "S3OriginConfig": {"OriginAccessIdentity": ""},
                    }
                ],
            },
            "DefaultCacheBehavior": {
                "TargetOriginId": "S3Origin",
                "ViewerProtocolPolicy": "redirect-to-https",
                "AllowedMethods": {
                    "Quantity": 2,
                    "Items": ["GET", "HEAD"],
                },
                "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                "Compress": True,
            },
            "PriceClass": "PriceClass_100",
            "ViewerCertificate": {"CloudFrontDefaultCertificate": True},
        }
    )

    dist_id = response["Distribution"]["Id"]
    domain = response["Distribution"]["DomainName"]
    print(f"Distribution created: {dist_id}")
    print(f"Domain: {domain}")
    return dist_id, domain


def update_bucket_policy(distribution_id):
    """Update S3 bucket policy to allow CloudFront OAC."""
    policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowCloudFrontOAC",
                "Effect": "Allow",
                "Principal": {"Service": "cloudfront.amazonaws.com"},
                "Action": "s3:GetObject",
                "Resource": f"arn:aws:s3:::{BUCKET_NAME}/*",
                "Condition": {
                    "StringEquals": {
                        "AWS:SourceArn": f"arn:aws:cloudfront::{account_id}:distribution/{distribution_id}"
                    }
                },
            }
        ],
    }
    s3.put_bucket_policy(Bucket=BUCKET_NAME, Policy=json.dumps(policy))
    print("Bucket policy updated for OAC.")


def test_invalidation(distribution_id):
    """Create a cache invalidation."""
    print("Creating cache invalidation for /index.html...")
    response = cf.create_invalidation(
        DistributionId=distribution_id,
        InvalidationBatch={
            "Paths": {"Quantity": 1, "Items": ["/index.html"]},
            "CallerReference": f"invalidation-{int(time.time())}",
        },
    )
    inv_id = response["Invalidation"]["Id"]
    print(f"Invalidation created: {inv_id}")
    return inv_id


def main():
    bucket = create_bucket()
    oac_id = create_oac()
    dist_id, domain = create_distribution(oac_id)
    update_bucket_policy(dist_id)

    print(f"\nDistribution is deploying. This takes 5-15 minutes.")
    print(f"Test URL: https://{domain}/")
    print(f"\nTo invalidate cache later:")
    print(f"  python3 -c \"... test_invalidation('{dist_id}') ...\"")

    # Save resource IDs for cleanup
    with open(os.path.expanduser("~/cloudfront-lab/resources.json"), "w") as f:
        json.dump(
            {
                "bucket": bucket,
                "distribution_id": dist_id,
                "domain": domain,
                "oac_id": oac_id,
            },
            f,
            indent=2,
        )
    print(f"\nResource IDs saved to ~/cloudfront-lab/resources.json")


if __name__ == "__main__":
    main()
```

---

## Part 4: Deploy with Terraform

```hcl
# File: ~/cloudfront-lab/terraform/main.tf

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

resource "random_id" "suffix" {
  byte_length = 4
}

# --- S3 Bucket ---
resource "aws_s3_bucket" "website" {
  bucket = "cloudfront-lab-tf-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content      = <<-HTML
    <!DOCTYPE html>
    <html><head><title>CloudFront Lab (Terraform)</title></head>
    <body><h1>CloudFront + S3 Lab</h1><p>Deployed with Terraform. Version 1.0</p></body></html>
  HTML
  content_type = "text/html"
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.website.id
  key          = "error.html"
  content      = "<html><body><h1>404 Not Found</h1></body></html>"
  content_type = "text/html"
}

# --- CloudFront OAC ---
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "S3OAC-Lab-TF"
  description                       = "OAC for CloudFront Lab"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- CloudFront Distribution ---
resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  enabled             = true
  default_root_object = "index.html"
  comment             = "CloudFront Lab - Terraform"
  price_class         = "PriceClass_100"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
  }

  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/error.html"
    error_caching_min_ttl = 300
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# --- S3 Bucket Policy for OAC ---
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })
}

# --- Outputs ---
output "cloudfront_domain" {
  value       = aws_cloudfront_distribution.website.domain_name
  description = "CloudFront distribution domain name"
}

output "cloudfront_id" {
  value       = aws_cloudfront_distribution.website.id
  description = "CloudFront distribution ID"
}

output "s3_bucket" {
  value       = aws_s3_bucket.website.id
  description = "S3 bucket name"
}
```

### Deploy with Terraform

```bash
cd ~/cloudfront-lab/terraform
terraform init
terraform plan
terraform apply -auto-approve

# Note the outputs
# cloudfront_domain = "d1234567890.cloudfront.net"
```

---

## Part 5: Test Cache Invalidation

### Update the content

```bash
# Update the HTML file (change version to 2.0)
aws s3 cp - s3://$BUCKET_NAME/index.html --content-type "text/html" << 'EOF'
<html><body><h1>CloudFront Lab</h1><p>Version 2.0 - UPDATED</p></body></html>
EOF

# Visit the CloudFront URL -- you will still see version 1.0 (cached)
curl https://$DISTRIBUTION_DOMAIN/

# Create an invalidation
aws cloudfront create-invalidation \
    --distribution-id $DISTRIBUTION_ID \
    --paths "/index.html"

# Wait a minute, then visit again -- you should see version 2.0
sleep 60
curl https://$DISTRIBUTION_DOMAIN/
```

---

## Part 6: Verify and Explore

### Check cache behavior with headers

```bash
# First request (cache miss)
curl -s -o /dev/null -w "Status: %{http_code}\n" -D - https://$DISTRIBUTION_DOMAIN/ | grep -i x-cache
# Expected: X-Cache: Miss from cloudfront

# Second request (cache hit)
curl -s -o /dev/null -w "Status: %{http_code}\n" -D - https://$DISTRIBUTION_DOMAIN/ | grep -i x-cache
# Expected: X-Cache: Hit from cloudfront
```

### Verify S3 direct access is blocked

```bash
# Try to access S3 directly (should fail with 403)
curl -I https://$BUCKET_NAME.s3.us-east-1.amazonaws.com/index.html
# Expected: 403 Forbidden (public access is blocked, only OAC can read)
```

---

## Cleanup (IMPORTANT -- Do This Immediately)

### CLI Cleanup

```bash
# 1. Disable the distribution
ETAG=$(aws cloudfront get-distribution-config --id $DISTRIBUTION_ID --query 'ETag' --output text)
aws cloudfront get-distribution-config --id $DISTRIBUTION_ID --query 'DistributionConfig' --output json > /tmp/cf-disable.json
python3 -c "
import json
with open('/tmp/cf-disable.json') as f: c = json.load(f)
c['Enabled'] = False
with open('/tmp/cf-disable.json', 'w') as f: json.dump(c, f)
"
aws cloudfront update-distribution --id $DISTRIBUTION_ID --if-match $ETAG --distribution-config file:///tmp/cf-disable.json

# 2. Wait for distribution to be disabled
echo "Waiting for distribution to be disabled (this takes several minutes)..."
aws cloudfront wait distribution-deployed --id $DISTRIBUTION_ID

# 3. Delete the distribution
ETAG=$(aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'ETag' --output text)
aws cloudfront delete-distribution --id $DISTRIBUTION_ID --if-match $ETAG

# 4. Delete the OAC
aws cloudfront delete-origin-access-control --id $OAC_ID --if-match $(aws cloudfront get-origin-access-control --id $OAC_ID --query 'ETag' --output text)

# 5. Empty and delete the S3 bucket
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME
```

### Terraform Cleanup

```bash
cd ~/cloudfront-lab/terraform
terraform destroy -auto-approve
```

---

## What You Learned

1. How to create an S3 bucket with all public access blocked.
2. How to configure CloudFront OAC to securely access S3.
3. How CloudFront caches content and when cache misses/hits occur.
4. How to invalidate cached content.
5. How to verify that direct S3 access is blocked while CloudFront access works.
6. The same deployment using CLI, Boto3, and Terraform.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Create the Static Website Files
- Deploy with AWS CLI
- Deploy with Boto3 (Python)
- Deploy with Terraform

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
