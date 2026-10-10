# State lives in the Cloud Storage bucket created by ./state, not on your laptop:
# versioned, encrypted at rest, private, and locked while an apply is running.
#
# Where it lands:   gs://<bucket>/lab/default.tfstate
# How it locks:     Terraform creates gs://<bucket>/lab/default.tflock with an
#                   "only if it does not already exist" precondition and deletes it
#                   when done. Two applies cannot both win that race, so there is no
#                   separate lock table to manage. A lock left behind by a killed run
#                   is cleared with `terraform force-unlock <ID>` -- the ID is in the
#                   error -- and only after confirming nothing else is applying.
# Encryption:       Google-managed keys. The backend also accepts
#                   `kms_encryption_key = "projects/.../cryptoKeys/..."` if a bucket
#                   ever needs a customer-managed key; a lab does not.
#
# A backend block cannot use variables or locals -- it is read before anything is
# evaluated -- so the bucket name comes from backend.hcl (not committed; see .gitignore):
#   terraform init -backend-config=backend.hcl
#
# From CI or a shared machine, add to backend.hcl:
#   impersonate_service_account = "ci@PROJECT.iam.gserviceaccount.com"
# and list that account in state/ as a state_writer, so the human credential never
# touches state directly and the service account holds nothing but object rights.
terraform {
  backend "gcs" {
    prefix = "lab"
  }
}
