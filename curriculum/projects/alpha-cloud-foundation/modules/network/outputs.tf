# The module contract: these are the only things a caller may know about the network.
# Consumed by the compute module (security groups, target group) and the database module.
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

# Not used by the environments today. Kept for a peering connection or a CIDR-based rule in a
# module that cannot reference a security group.
output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.this.cidr_block
}

# Consumed by compute: the ALB's subnets. Sorted by AZ name so the list order is stable across
# applies; a map's iteration order is not something a caller should depend on.
output "public_subnet_ids" {
  description = "Public subnet IDs, ordered by AZ"
  value       = [for az in sort(keys(aws_subnet.public)) : aws_subnet.public[az].id]
}

# Consumed by compute: the ASG's vpc_zone_identifier.
output "app_subnet_ids" {
  description = "Application subnet IDs, ordered by AZ"
  value       = [for az in sort(keys(aws_subnet.app)) : aws_subnet.app[az].id]
}

# Consumed by database: the DB subnet group.
output "data_subnet_ids" {
  description = "Data subnet IDs, ordered by AZ"
  value       = [for az in sort(keys(aws_subnet.data)) : aws_subnet.data[az].id]
}

# Not used by the environments today; available to anything that needs the same AZ set.
output "availability_zones" {
  description = "AZs in use"
  value       = local.azs
}

# Re-exported by the environments as their own `subnet_plan` output, for docs/architecture.md.
output "subnet_plan" {
  description = "Human-readable CIDR allocation, for the README and the architecture diagram"
  value = {
    vpc    = var.vpc_cidr
    public = local.public_subnets
    app    = local.app_subnets
    data   = local.data_subnets
  }
}
