terraform {
  required_version = ">= 1.10, < 2.0"

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
  #   key          = "github/TheWayOfTheSurge/terraform.tfstate"
  #   region       = "us-east-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}
