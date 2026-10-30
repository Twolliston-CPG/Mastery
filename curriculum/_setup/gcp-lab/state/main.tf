# Creates the Cloud Storage bucket that holds the lab's Terraform state.
#
# Chicken-and-egg: this configuration cannot store its own state in a bucket it has
# not created yet, so THIS directory keeps local state. It manages one bucket, is
# applied once, and is changed rarely.
#
#   terraform init && terraform apply -var project_id=YOUR_PROJECT
#   terraform output -raw backend_config > ../backend.hcl
#
# If the local terraform.tfstate here is ever lost, nothing is broken -- the bucket
# still exists and the lab's state is still in it. Re-adopt the bucket:
#   terraform import -var project_id=YOUR_PROJECT google_storage_bucket.state YOUR_PROJECT-tfstate
#   terraform import -var project_id=YOUR_PROJECT google_project_service.storage YOUR_PROJECT/storage.googleapis.com
#   terraform import -var project_id=YOUR_PROJECT google_project_iam_audit_config.storage YOUR_PROJECT/storage.googleapis.com

# The same pins as the lab's versions.tf, duplicated because this is its own root module. No
# backend block on purpose: the state for this directory is the local terraform.tfstate.
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
  }
}

# Project only: a bucket is regional or multi-regional, chosen by `location` below, so the
# provider needs no zone.
provider "google" {
  project = var.project_id
}

# The Storage API switch for the project. disable_on_destroy = false because image/ uses the same
# API for its staging bucket; this root must never switch it off under another.
resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# The bucket. Everything below the name is a protection for a file that can contain secrets and
# that nothing else can reconstruct: IAM-only access, versions to roll back to, a soft-delete
# window, and two refusals to destroy. The inline skip is for a checkov rule about bucket access
# logs, which the audit config below replaces with something better.
resource "google_storage_bucket" "state" {
  # checkov:skip=CKV_GCP_62: Bucket access logging needs a second bucket to log into. Data Access audit logs (below) already record every read and write of the state object, with the caller's identity.
  name          = "${var.project_id}-tfstate" # bucket names are global; the project ID makes it unique
  location      = var.location
  storage_class = "STANDARD" # state is read on every plan; anything colder charges per retrieval

  labels = {
    purpose    = "terraform-state"
    managed-by = "terraform"
  }

  # State can contain secrets in plain text. Nobody outside the project, ever:
  uniform_bucket_level_access = true       # IAM only, no per-object ACLs
  public_access_prevention    = "enforced" # cannot be made public, even by mistake

  # Versioning is the recovery path for a corrupted or overwritten state file.
  # Every write makes the previous state a "noncurrent" version you can restore.
  versioning {
    enabled = true
  }

  # Keep the ten most recent noncurrent versions; older ones are deleted. Each
  # apply also creates and deletes a lock object, so this rule is what keeps the
  # bucket from accumulating lock debris.
  lifecycle_rule {
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # A second net under versioning: anything deleted -- including by the rule above
  # or by a `gsutil rm` -- stays recoverable for seven days.
  soft_delete_policy {
    retention_duration_seconds = 604800
  }

  # Losing state means losing the mapping from configuration to real resources,
  # so destroy is refused twice over. `terraform destroy` here fails on
  # prevent_destroy; if you flip that, force_destroy = false still refuses while
  # the bucket holds objects. Tearing the lab down for good is
  # `gcloud projects delete`, which does not consult either.
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  # The API must be enabled before the first bucket call, and Terraform cannot infer that from the
  # arguments, so it is stated.
  depends_on = [google_project_service.storage]
}

# The least a state writer needs: read, list, create, and delete objects (the lock
# is an object). Not objectAdmin -- that also lets the principal change the bucket's
# IAM, and not a project-level role. Additive: the owner's access is untouched.
resource "google_storage_bucket_iam_member" "writers" {
  for_each = toset(var.state_writers)

  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectUser"
  member = each.value
}

# Admin Activity audit logs (bucket created, IAM changed) are always on. Data Access
# logs -- who read or wrote the state object, and when -- are not, unless asked for.
# Project-wide for the Storage service; this bucket is the only one in the project.
resource "google_project_iam_audit_config" "storage" {
  count = var.data_access_logs ? 1 : 0

  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# The learner, once, to confirm the name; state/README.md's second-machine recovery uses it too.
output "bucket" {
  description = "Name of the state bucket"
  value       = google_storage_bucket.state.name
}

# Written to ../backend.hcl by the README's step 6 (`terraform output -raw backend_config >
# ../backend.hcl`). A backend block cannot read variables, so the lab's and image/'s `init` take
# this file instead: one line, the bucket's name.
output "backend_config" {
  description = "Contents for ../backend.hcl"
  value       = "bucket = \"${google_storage_bucket.state.name}\"\n"
}
