variable "project" {
  description = "Project name, used in resource names and tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
}

# The validation enforces the sizing argument at the top of main.tf: a /20 app subnet needs a
# /16 (or larger) to leave three of them plus six /24s and still have room. A /17 fails the
# check even though the arithmetic would technically fit; that is deliberate.
variable "vpc_cidr" {
  description = "VPC CIDR. Must be /16 to leave room for /20 app subnets."
  type        = string
  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) <= 16
    error_message = "vpc_cidr must be /16 or larger to fit /20 app subnets."
  }
}

# The subnet maps in main.tf allocate /24s 0-2 to public and 3-5 to data, so 3 is the ceiling
# without re-planning the address space. 2 is the floor because an ALB needs two AZs.
variable "az_count" {
  description = "Number of availability zones to span"
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 (subnet math allocates for up to 3)."
  }
}

# enable_nat and single_nat_gateway work together: off -> no gateways, no default route in the
# app tier (instances reach only the VPC and S3); on + single -> one gateway in the first AZ;
# on + not single -> one per AZ. dev sets single; prod leaves it false.
variable "enable_nat" {
  description = "Create NAT gateways. Disable in a lab to save ~$32/month per AZ."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Share one NAT gateway across all AZs. Cheaper; not HA. Use in dev only."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs (REJECT traffic only)"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention"
  type        = number
  default     = 14
}
