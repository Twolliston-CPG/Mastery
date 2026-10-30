# Version pins for the module. A module declares which providers it needs and how recent; it
# never contains a provider block (credentials, region), because then it could not be used twice
# in one root or in a second region. The root module configures the provider; this inherits it.
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }
}
