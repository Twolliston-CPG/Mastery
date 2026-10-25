# Creates the S3 bucket that holds the lab's Terraform state.
#
# Chicken-and-egg: this configuration cannot store its own state in a bucket it has
# not created yet, so THIS directory keeps local state. It manages one bucket, is
# applied once, and is changed rarely.
#
#   terraform init && terraform apply
#   terraform output -raw backend_config > ../backend.hcl

# The same pins as the lab, repeated on purpose: this root shares nothing with the lab, so it can
# exist before the lab does and outlive it.
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
  }
}

# The provider again, with a third default tag so the bucket is told apart from lab resources in
# Cost Explorer and in the teardown script's listings.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      purpose    = "lab"
      managed-by = "terraform"
      component  = "state"
    }
  }
}

# Must match the lab's region: backend_config below writes it into ../backend.hcl, and state in
# another region works but adds a round trip to every plan.
variable "region" {
  description = "Region for the state bucket. Keep it the same as the lab"
  type        = string
  default     = "us-east-1"
}

variable "force_destroy" {
  description = "Allow `terraform destroy` to delete the bucket even though it still holds state versions. Set true only when tearing the lab down for good"
  type        = bool
  default     = false
}

# The account ID goes into the bucket name. S3 bucket names are global across every AWS account,
# and account plus region is the simplest name that is both unique and reproducible.
data "aws_caller_identity" "this" {}

# The bucket. Everything that makes it fit for state is a separate resource below, because the
# provider splits bucket configuration into one resource per feature. Each checkov skip inside is
# a deliberate decision, explained where it sits.
resource "aws_s3_bucket" "state" {
  # checkov:skip=CKV_AWS_18: Access logging needs a second bucket to log into. For one person's lab state, CloudTrail already records who touched the bucket.
  # checkov:skip=CKV_AWS_144: Cross-region replication is disaster recovery for production state. Versioning is the recovery path here.
  # checkov:skip=CKV_AWS_145: Encrypted with S3-managed keys (below). A customer-managed KMS key costs money monthly and adds a way to lock yourself out of your own state.
  # checkov:skip=CKV2_AWS_62: Nothing needs to react to state changes in a single-person lab.
  bucket = "tfstate-lab-${data.aws_caller_identity.this.account_id}-${var.region}" # bucket names are global

  # false: destroy refuses while the bucket holds state. Losing state means losing
  # the mapping from configuration to real resources.
  force_destroy = var.force_destroy
}

# Versioning is the recovery path for a corrupted or overwritten state file.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest on every object by default. AES256 means S3-managed keys: no key to lose and
# no monthly key charge. The trivy note below is the same decision seen by a second scanner.
# trivy: same decision as the CKV_AWS_145 skip on the bucket (S3-managed keys, not a customer-managed
# KMS key). trivy attributes the finding to this resource, so the ignore lives here.
#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State can contain secrets in plain text. Nobody outside the account, ever.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACLs off entirely: access is decided by IAM and the bucket policy alone.
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Refuse any request that is not over TLS.
# A bucket policy is evaluated for every request, the owner's included. A Deny conditioned on
# aws:SecureTransport = false refuses anything over plain HTTP. depends_on: the public access
# block must exist first, or S3 can reject the policy as public-looking while the two race.
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
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# Old state versions are kept 90 days, then deleted.
# Noncurrent versions are the old states versioning kept; 90 days of undo is plenty for a lab.
# Aborting multipart uploads after 7 days stops a killed upload from billing forever. filter {}
# means every object. depends_on: a rule on noncurrent versions is only valid once versioning is
# enabled, and the two resources race without it.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

# Consumed by the README, and by a second machine rebuilding ../backend.hcl by hand.
output "bucket" {
  description = "Name of the state bucket"
  value       = aws_s3_bucket.state.bucket
}

# Consumed once: `terraform output -raw backend_config > ../backend.hcl`.
output "backend_config" {
  description = "Contents for ../backend.hcl"
  value       = "bucket = \"${aws_s3_bucket.state.bucket}\"\nregion = \"${var.region}\"\n"
}
