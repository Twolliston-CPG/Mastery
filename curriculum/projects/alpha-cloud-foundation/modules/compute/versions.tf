# Version pins for the module. No provider block here, on purpose: a module that configures its
# own provider cannot be instantiated twice in one root or pointed at a second region. The root
# (environments/dev, environments/prod) configures the provider; this module inherits it.
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }
}
