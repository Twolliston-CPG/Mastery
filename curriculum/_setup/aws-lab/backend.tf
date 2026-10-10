# State lives in the S3 bucket created by ./state, not on your laptop: versioned,
# encrypted at rest, private, and locked while an apply is running.
#
# A backend block cannot use variables, so the bucket and region come from backend.hcl:
#   terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {
    key          = "lab/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # S3-native locking; no DynamoDB table needed
  }
}
