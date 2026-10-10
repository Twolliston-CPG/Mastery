# Imports the official Arch Linux cloud image into this project as a custom image.
#
# Why: the only Arch image Google's community project publishes is from 2022. Arch
# publishes a fresh cloud image every month; this takes that file and makes it a
# Compute Engine image in YOUR project, under the family "arch", so main.tf in the
# lab can reference the family exactly as it would a vendor image.
#
# Order: ../state (bucket) -> fetch.sh -> this -> the lab.
#
#   bash fetch.sh
#   terraform init -backend-config=../backend.hcl
#   terraform apply -var project_id=YOUR_PROJECT
#
# Re-running fetch.sh with a newer build changes `build`; the next apply creates the
# new image first, then removes the old one. The family now points at the new build.
# The running VM is untouched: its disk was copied from the old image at creation.

terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
  }
}

provider "google" {
  project = var.project_id
}

variable "project_id" {
  description = "The lab's GCP project"
  type        = string
}

variable "build" {
  description = "Date part of the Arch cloud image build, e.g. 20261001. Written to build.auto.tfvars by fetch.sh"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{8}$", var.build))
    error_message = "build must be eight digits (YYYYMMDD), as fetch.sh writes it."
  }
}

variable "tarball" {
  description = "Path to the disk.raw tarball fetch.sh produced"
  type        = string
}

variable "location" {
  description = "Location of the bucket holding the tarball. Match ../state so the copy stays regional"
  type        = string
  default     = "US"
}

variable "guest_os_features" {
  description = "Hardware the image is declared to support. UEFI_COMPATIBLE boots through the image's EFI partition; remove it to boot through the BIOS/GPT hybrid path if UEFI boot hangs. GVNIC and VIRTIO_SCSI_MULTIQUEUE are in the stock Arch kernel"
  type        = list(string)
  default     = ["UEFI_COMPATIBLE", "GVNIC", "VIRTIO_SCSI_MULTIQUEUE"]
}

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# A staging bucket, separate from the state bucket: no reason to give audit-logged
# state storage a 600 MB neighbour, and nothing here is the only copy of anything.
#
# The tarball is kept, not expired. Compute Engine copies it into the image, so it is
# dead weight afterwards -- but a lifecycle rule that deletes it would make Terraform
# want to re-upload it on every plan after day seven. 570 MB of Standard storage is
# about a cent a month; a new build replaces the object (new name), and the old one
# is destroyed with it.
resource "google_storage_bucket" "images" {
  # checkov:skip=CKV_GCP_62: Staging only. One object, copied into an image; nothing to audit.
  # checkov:skip=CKV_GCP_78: Versioning a 600 MB reproducible tarball doubles its cost and protects nothing.
  name     = "${var.project_id}-images"
  location = var.location

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true # staging: nothing here is the only copy of anything

  depends_on = [google_project_service.storage]
}

resource "google_storage_bucket_object" "tarball" {
  name         = "arch-${var.build}.tar.gz"
  bucket       = google_storage_bucket.images.name
  source       = var.tarball
  content_type = "application/gzip"
}

resource "google_compute_image" "arch" {
  # The name must contain the family name: the lab's VM references the family, and the
  # provider suppresses a rebuild only when the resolved image name contains it.
  name        = "arch-${var.build}"
  family      = "arch"
  description = "Arch Linux cloud image, build ${var.build}, from geo.mirror.pkgbuild.com. Imported by _setup/gcp-lab/image"

  raw_disk {
    source = "https://storage.googleapis.com/${google_storage_bucket.images.name}/${google_storage_bucket_object.tarball.output_name}"
  }

  dynamic "guest_os_features" {
    for_each = toset(var.guest_os_features)
    content {
      type = guest_os_features.value
    }
  }

  labels = {
    purpose    = "lab"
    managed-by = "terraform"
    build      = var.build
  }

  lifecycle {
    create_before_destroy = true
  }

  timeouts {
    create = "30m"
  }

  depends_on = [google_project_service.compute]
}

output "image" {
  description = "The image the lab's `arch` family now resolves to"
  value       = "${google_compute_image.arch.name} (${google_compute_image.arch.disk_size_gb} GB, family ${google_compute_image.arch.family})"
}
