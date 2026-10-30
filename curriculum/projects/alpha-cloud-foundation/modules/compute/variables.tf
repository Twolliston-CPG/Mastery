# Two groups of inputs. The first five are the contract with the network module and the
# environment: identifiers the caller already holds. The rest are sizing and behaviour knobs
# with defaults a dev environment can live with and a prod environment overrides.
variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "app_subnet_ids" { type = list(string) }

# One number used in four places that must agree: the two security-group rules, the target
# group, and the user data that starts the app. Change it here, never in one of them.
variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "ALB health check path. Must be a path the app actually serves."
  type        = string
  default     = "/health"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# min <= desired <= max is enforced by AWS, not by validation here. desired is only the starting
# point: the ASG lifecycle block ignores later changes so the scaling policy owns the count.
variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 4
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "cpu_target" {
  description = "Target average CPU for the scaling policy"
  type        = number
  default     = 50
}

# Also used as instance_warmup for the instance refresh. Set it from a measured boot time plus
# two health-check intervals (30 s), never from a guess; 300 s is a safe default for AL2023 plus
# a package install, and too long only delays the detection of a genuinely broken instance.
variable "health_check_grace_period" {
  description = "Seconds before ELB health checks count. Too short = launch/terminate loop."
  type        = number
  default     = 300
}

# Flips four things at once: the :443 security-group rule, the HTTPS listener, and which of the
# two default actions the :80 listener renders. Null is the lab path with no domain.
variable "certificate_arn" {
  description = "ACM certificate ARN. If null, the ALB serves plain HTTP (lab only)."
  type        = string
  default     = null
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN the instances may read. Null to skip."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
