# The dev root module: its own state, its own provider configuration, and calls to the four
# shared modules with dev's inputs. prod is the same file with different values; a diff of the
# two directories is the complete list of what differs between the environments.
#
# required_providers lives here with the backend because this file is everything about how
# Terraform itself runs: the version, the provider line (the same ~> 6.68 the modules declare, so
# init cannot resolve to a major the modules reject), and where state goes. main.tf is only what
# gets built.
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }

  # A backend block cannot use variables or locals: it is read before anything is evaluated, so
  # the bucket name is a literal. key is this environment's object in the bucket; use_lockfile is
  # the S3-native lock the bootstrap README describes; encrypt asks for SSE on every write.
  # Replace the bucket name with the output of `cd bootstrap && terraform apply`.
  backend "s3" {
    bucket       = "tfstate-REPLACE-ACCOUNT-ID-us-east-1"
    key          = "alpha/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# One provider, inherited by every module below. default_tags is why no module has to tag
# anything but Name: Project, Environment, ManagedBy and Repo land on every resource, and Cost
# Explorer can split the bill by environment.
provider "aws" {
  region = var.region
  default_tags {
    tags = local.common_tags
  }
}
