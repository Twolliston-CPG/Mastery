# Inputs. The identifiers come from the compute and database modules' outputs; the thresholds
# are the only judgement calls, and each default is explained where it is used.
variable "project" { type = string }
variable "environment" { type = string }
variable "region" { type = string }

variable "alb_arn_suffix" { type = string }
variable "target_group_arn_suffix" { type = string }
variable "asg_name" { type = string }

# null means "no database here": the storage alarm is not created. The environment passes the
# database module's identifier output.
variable "db_instance_id" {
  type    = string
  default = null
}

# null means no subscription at all. The alarms still fire and still show in the console; they
# just reach nobody, which is BF-32 by configuration.
variable "alert_email" {
  description = "Email for alarm notifications. You MUST confirm the subscription."
  type        = string
  default     = null
}

# 5 per minute is low on purpose for a lab with little traffic. On a real service this is a rate,
# not a count: week 20 replaces it with an error ratio and a burn rate.
variable "error_threshold" {
  description = "5xx count per minute that triggers an alert"
  type        = number
  default     = 5
}

# One second at p99 is the user-visible line for a web request; the lab's app is well under it.
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
