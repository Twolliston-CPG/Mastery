# The provider line this module is written against. A module declares the constraint and never
# a provider block: the root module configures the provider, and the module inherits it, which
# is what lets one module serve two environments and, with aliases, two regions (week 11).
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }
}
