# Creates the S3 bucket that holds the lab's Terraform state.
#
# Chicken-and-egg: this configuration cannot store its own state in a bucket it has
# not created yet, so THIS directory keeps local state. It manages one bucket, is
# applied once, and is changed rarely.
#
#   terraform init && terraform apply
#   terraform output -raw backend_config > ../backend.hcl

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
  }
}

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

data "aws_caller_identity" "this" {}

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

output "bucket" {
  description = "Name of the state bucket"
  value       = aws_s3_bucket.state.bucket
}

output "backend_config" {
  description = "Contents for ../backend.hcl"
  value       = "bucket = \"${aws_s3_bucket.state.bucket}\"\nregion = \"${var.region}\"\n"
}
