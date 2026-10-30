# Inputs. The four one-liners are identity and placement and have no sensible default; the rest
# default to the smallest, cheapest shape and are raised by the environment that needs more.
variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "data_subnet_ids" { type = list(string) }

variable "app_security_group_id" {
  description = "Security group allowed to reach the database"
  type        = string
}

# engine_version and parameter_group_family move together: a 17.x engine needs the postgres17
# family. Pinning the minor here means a plan, not a maintenance window, decides when it moves.
variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "parameter_group_family" {
  type    = string
  default = "postgres16"
}

# db.t4g.micro is Graviton and burstable: fine for the lab, wrong for a sustained load.
# prod raises it in the environment, not here; a module default is a floor, not a policy.
variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

# 20 GB is the RDS minimum for gp3. The autoscaling ceiling below is what prevents a full disk;
# the free-storage alarm in the observability module is what tells you it is growing.
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

# Off by default so dev stays cheap; prod sets it true. Doubling the instance is the cost.
variable "multi_az" {
  description = "Synchronous standby in another AZ. Availability, not read scaling."
  type        = bool
  default     = false
}

# 7 is a compromise default; dev uses 1, prod 14. 0 would disable automated backups entirely.
variable "backup_retention_days" {
  type    = number
  default = 7
}
