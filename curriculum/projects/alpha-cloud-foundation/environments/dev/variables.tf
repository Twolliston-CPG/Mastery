# The root's inputs are few on purpose: everything that differs between environments is written
# literally in main.tf, where a diff shows it. These four are the things that differ per person.
variable "project" {
  type    = string
  default = "alpha"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# null is the lab default and serves plain HTTP. With an ACM certificate ARN the listener on 443
# is created and 80 redirects to it (see the compute module).
variable "certificate_arn" {
  description = "ACM certificate ARN. Null serves plain HTTP (lab only)."
  type        = string
  default     = null
}

variable "alert_email" {
  description = "Email for CloudWatch alarms. You must confirm the SNS subscription."
  type        = string
  default     = null
}

# The tags every resource carries, applied through the provider's default_tags in backend.tf.
# Environment is a literal, not var.environment, because this root IS dev; there is no input
# that could make it something else.
locals {
  common_tags = {
    Project     = var.project
    Environment = "dev"
    ManagedBy   = "terraform"
    Repo        = "alpha-cloud-foundation"
  }
}
