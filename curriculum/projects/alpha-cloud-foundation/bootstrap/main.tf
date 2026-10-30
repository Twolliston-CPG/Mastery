# Bootstrap: creates the S3 bucket that holds every other environment's state.
#
# Chicken-and-egg: you cannot store this configuration's own state in a bucket
# it has not created yet. So this directory keeps LOCAL state, committed to git.
# It is applied once and changed rarely.
#
#   cd bootstrap && terraform init && terraform apply
#
# What it builds, in dependency order: the bucket, then versioning, encryption, the public-access
# block, a TLS-only policy and a lifecycle rule on it. Locking needs no table: the environments'
# backends set use_lockfile = true, so Terraform 1.10+ writes a .tflock object in this bucket
# with an only-if-absent precondition, and two applies cannot both win that race.

# Pinned to the same provider line as the modules and environments, so a provider upgrade is one
# change across every root. No backend block: this is the one root whose state stays local.
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.68" }
  }
}

# default_tags puts these three tags on everything the provider creates here, the bucket
# included, with Component telling the state bucket apart from the environments' resources in
# Cost Explorer.
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

# Read, not created: the account id makes the bucket name unique, because S3 bucket names are
# global across every AWS account.
data "aws_caller_identity" "current" {}

# tfstate-<account>-<region>: unique, and it says what it is and where. The region is in the
# name because the environments' backend blocks must name the bucket's region too.
locals {
  bucket_name = "tfstate-${data.aws_caller_identity.current.account_id}-${var.region}"
}

# The bucket. Every environment's state is an object under alpha/<env>/ here, and the lock
# objects beside them. The four scanner findings skipped inside are each a trade-off a single
# person's project makes on purpose; each carries its reason.
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

# Encryption at rest with AES256, applied by default to every object written, so no backend block
# can forget it; the backends also set encrypt = true, which is the same thing requested twice.
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

# All four switches on: no ACL can make an object public, no policy can make the bucket public,
# and existing public ACLs are ignored. State holds secrets in plaintext; this is the floor.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# aws:SecureTransport is false on a plain-HTTP request; the Deny wins over any Allow, so the only
# way to read or write state is over TLS, whatever IAM says.
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

# 90 days of noncurrent versions is roughly a quarter of history for a state file that changes a
# few times a week. Multipart uploads abandoned for 7 days are deleted so they stop billing.
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
