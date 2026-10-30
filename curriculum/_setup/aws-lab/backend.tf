# State lives in the S3 bucket created by ./state, not on your laptop: versioned,
# encrypted at rest, private, and locked while an apply is running.
#
# A backend block cannot use variables, so the bucket and region come from backend.hcl:
#   terraform init -backend-config=backend.hcl
#
# key:          the object path inside the bucket. ./state keeps its own state as a local file and
#               never uses this block, because a bucket cannot hold the state that creates it.
# encrypt:      ask S3 for server-side encryption on every write, on top of the bucket default.
# use_lockfile: Terraform creates lab/terraform.tfstate.tflock with an only-if-absent precondition
#               for the length of the operation; a second apply cannot create it and refuses to
#               run. A lock left by a killed run is cleared with `terraform force-unlock <ID>`,
#               and only after confirming nothing else is applying.
terraform {
  backend "s3" {
    key          = "lab/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # S3-native locking; no DynamoDB table needed
  }
}
