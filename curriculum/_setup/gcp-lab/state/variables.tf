# Settings for the state bucket root. project_id has no default by design; the rest are judgement
# calls explained in each description.

variable "project_id" {
  description = "The lab's GCP project. No default on purpose: pass -var project_id=... or put it in terraform.tfvars (gitignored)"
  type        = string
}

variable "location" {
  description = "Bucket location. The US multi-region works with a lab in any US region; set a single region (for example EUROPE-WEST1) if you need the state kept elsewhere"
  type        = string
  default     = "US"
}

variable "state_writers" {
  description = "Extra principals that may read and write state: a CI service account, or you on a second machine. IAM member strings, e.g. [\"serviceAccount:ci@PROJECT.iam.gserviceaccount.com\"]. The project owner already has access and does not need listing"
  type        = list(string)
  default     = []
}

variable "data_access_logs" {
  description = "Record every object read and write in this project's Cloud Storage to Cloud Audit Logs. Off by default in GCP; on here so there is a record of who read or changed state. One person's lab stays well inside the free logging tier"
  type        = bool
  default     = true
}