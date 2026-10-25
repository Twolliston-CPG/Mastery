# The provider line this module is written against; no provider block, for the reason given in
# the database module's versions.tf.
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }
}
