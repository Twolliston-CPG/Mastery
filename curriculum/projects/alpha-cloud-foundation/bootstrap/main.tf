# Bootstrap: creates the S3 bucket that holds every other environment's state.
#
# Chicken-and-egg: you cannot store this configuration's own state in a bucket
# it has not created yet. So this directory keeps LOCAL state, committed to git.
# It is applied once and changed rarely.
#
#   cd bootstrap && terraform init && terraform apply

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.68" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "alpha-cloud-foundation"
      ManagedBy = "terraform"
      Component = "bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "tfstate-${data.aws_caller_identity.current.account_id}-${var.region}"
}

resource "aws_s3_bucket" "state" {
  # checkov:skip=CKV_AWS_18: Access logging needs a second bucket to log into. For one person's project state, CloudTrail already records who touched the bucket.
  # checkov:skip=CKV_AWS_144: Cross-region replication is disaster recovery for production state. Versioning is the recovery path here.
  # checkov:skip=CKV_AWS_145: Encrypted with S3-managed keys (below). A customer-managed KMS key costs money monthly and adds a way to lock yourself out of your own state.
  # checkov:skip=CKV2_AWS_62: Nothing needs to react to state changes in a single-person project.
  bucket = local.bucket_name

  # Losing the state bucket means losing the mapping from config to real
  # resources. This is the single most important prevent_destroy in the repo.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning is the recovery path for corrupted or deleted state. Non-negotiable.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# trivy: S3-managed keys, not a customer-managed KMS key. A CMK costs money monthly and adds a way
# to lock yourself out of your own state; versioning is the recovery path here.
#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Deny any non-TLS access to state. State contains secrets in plaintext.
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}

# Expire old state versions so the bucket does not grow without bound,
# but keep enough history to recover from a bad apply.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
