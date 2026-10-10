output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs, ordered by AZ"
  value       = [for az in sort(keys(aws_subnet.public)) : aws_subnet.public[az].id]
}

output "app_subnet_ids" {
  description = "Application subnet IDs, ordered by AZ"
  value       = [for az in sort(keys(aws_subnet.app)) : aws_subnet.app[az].id]
}

output "data_subnet_ids" {
  description = "Data subnet IDs, ordered by AZ"
  value       = [for az in sort(keys(aws_subnet.data)) : aws_subnet.data[az].id]
}

output "availability_zones" {
  description = "AZs in use"
  value       = local.azs
}

output "subnet_plan" {
  description = "Human-readable CIDR allocation, for the README and the architecture diagram"
  value = {
    vpc    = var.vpc_cidr
    public = local.public_subnets
    app    = local.app_subnets
    data   = local.data_subnets
  }
}
