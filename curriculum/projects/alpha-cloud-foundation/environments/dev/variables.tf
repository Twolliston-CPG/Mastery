variable "project" {
  type    = string
  default = "alpha"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

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

locals {
  common_tags = {
    Project     = var.project
    Environment = "dev"
    ManagedBy   = "terraform"
    Repo        = "alpha-cloud-foundation"
  }
}
