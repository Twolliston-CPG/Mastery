# Version pins for this root. Terraform >= 1.10 is required by the `import` blocks in imports.tf
# (plannable imports) and by S3-native state locking should the backend ever move off the laptop;
# < 2.0 keeps a future major from changing plan semantics under a configuration that is applied
# by hand. The lock file (.terraform.lock.hcl) pins the exact provider build; this file pins the
# range `init -upgrade` may move within.
terraform {
  required_version = ">= 1.10, < 2.0"

  # The only provider. integrations/github is the one GitHub's own documentation points at; the
  # 6.x line is where the ruleset and Actions-permission resources used here stabilised. ~> 6.13
  # accepts any later 6.x minor and refuses 7.0, where argument names may change.
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }

  # State is local by default and gitignored (../../.gitignore). It holds repository metadata
  # only, never the token. To move it to S3 later (Terraform >= 1.10 native locking, no DynamoDB):
  #
  # backend "s3" {
  #   bucket       = "<your-tfstate-bucket>"
  #   key          = "github/twots/terraform.tfstate"
  #   region       = "us-east-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}
