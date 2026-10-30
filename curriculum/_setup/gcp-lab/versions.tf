# Terraform and provider pins for the lab root, plus the provider's default scope.
# state/ and image/ each carry their own copy of both blocks: a root module cannot share a
# terraform {} block with another, and each of the three is initialised and applied on its own.

# Terraform 1.9 or newer, because variables.tf validates one variable against another (zone must
# sit inside region), which older versions refuse. The google provider is held to the 8.x line;
# the exact build is recorded in .terraform.lock.hcl, which is committed, so every machine and the
# CI runner install the same provider and verify it against the same checksums.
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
  }
}

# Every resource below inherits project, region and zone from here unless it sets its own. The
# credential is Application Default Credentials (`gcloud auth application-default login`), a
# separate login from the gcloud CLI's own; both are needed, one for Terraform, one for gcloud.
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
