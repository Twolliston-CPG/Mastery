variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "data_subnet_ids" { type = list(string) }

variable "app_security_group_id" {
  description = "Security group allowed to reach the database"
  type        = string
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "parameter_group_family" {
  type    = string
  default = "postgres16"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling. 0 disables autoscaling."
  type        = number
  default     = 100
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "master_username" {
  type    = string
  default = "appadmin"
}

variable "multi_az" {
  description = "Synchronous standby in another AZ. Availability, not read scaling."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  type    = number
  default = 7
}
