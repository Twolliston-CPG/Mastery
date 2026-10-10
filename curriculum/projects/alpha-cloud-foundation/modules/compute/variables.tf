variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "app_subnet_ids" { type = list(string) }

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

variable "health_check_grace_period" {
  description = "Seconds before ELB health checks count. Too short = launch/terminate loop."
  type        = number
  default     = 300
}

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
