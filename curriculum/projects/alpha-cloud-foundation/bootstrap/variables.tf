# The bucket's region, and therefore the region every environment's backend block must name.
# The environments can run in other regions; their state still lives here.
variable "region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "us-east-1"
}
