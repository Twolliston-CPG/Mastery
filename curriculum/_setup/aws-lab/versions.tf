# Terraform and provider pins, and the provider itself, for the lab root. The state backend
# is in backend.tf; the bucket it points at is built first, by ./state, which has its own pins.
#
# Order: ./state (the bucket) -> `terraform init -backend-config=backend.hcl` here -> apply.

# >= 1.10 because backend.tf uses use_lockfile, the S3-native state lock that arrived in 1.10.
# The provider pin is pessimistic: any 6.67 or later release of the 6.x line, never 7.0. The exact
# build is recorded in .terraform.lock.hcl, so two machines plan with the same provider.
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
  }
}

# One provider, one region. default_tags lands on every taggable resource below without each one
# repeating them; it is what lets 03-teardown.sh and Cost Explorer find lab resources by tag.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      purpose    = "lab"
      managed-by = "terraform"
    }
  }
}
