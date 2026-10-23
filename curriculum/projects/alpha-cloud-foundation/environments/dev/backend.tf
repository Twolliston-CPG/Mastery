terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69"
    }
  }

  # Replace the bucket name with the output of `cd bootstrap && terraform apply`.
  backend "s3" {
    bucket       = "tfstate-REPLACE-ACCOUNT-ID-us-east-1"
    key          = "alpha/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.common_tags
  }
}
