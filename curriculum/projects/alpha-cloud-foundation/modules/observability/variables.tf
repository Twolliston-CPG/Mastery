variable "project" { type = string }
variable "environment" { type = string }
variable "region" { type = string }

variable "alb_arn_suffix" { type = string }
variable "target_group_arn_suffix" { type = string }
variable "asg_name" { type = string }

variable "db_instance_id" {
  type    = string
  default = null
}

variable "alert_email" {
  description = "Email for alarm notifications. You MUST confirm the subscription."
  type        = string
  default     = null
}

variable "error_threshold" {
  description = "5xx count per minute that triggers an alert"
  type        = number
  default     = 5
}

variable "latency_p99_threshold" {
  description = "p99 latency in seconds"
  type        = number
  default     = 1.0
}

variable "db_free_storage_bytes" {
  description = "Alert when RDS free storage drops below this (default 2 GiB)"
  type        = number
  default     = 2147483648
}
