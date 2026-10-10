# Same bucket as the lab, separate state object: gs://<bucket>/image/default.tfstate.
#   terraform init -backend-config=../backend.hcl
terraform {
  backend "gcs" {
    prefix = "image"
  }
}
