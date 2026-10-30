# Same bucket as the lab, separate state object: gs://<bucket>/image/default.tfstate.
#   terraform init -backend-config=../backend.hcl
# The bucket name comes from ../backend.hcl rather than a variable because a backend block is read
# before any variable is evaluated. The separate prefix is what lets the image and the lab be
# applied and destroyed independently; the lock on one never blocks the other.
terraform {
  backend "gcs" {
    prefix = "image"
  }
}
