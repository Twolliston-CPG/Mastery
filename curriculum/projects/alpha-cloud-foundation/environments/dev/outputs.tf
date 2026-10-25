# What the root exposes to the person running it. Each one is a module output passed through;
# the root adds nothing of its own.

# The week 13 acceptance test curls this.
output "url" {
  description = "Load balancer URL"
  value       = "http://${module.compute.alb_dns_name}"
}

output "subnet_plan" {
  description = "CIDR allocation -- paste into the README"
  value       = module.network.subnet_plan
}

# For the application's configuration and for watching a failover: the name stays the same.
output "db_endpoint" {
  value = module.database.endpoint
}

output "db_secret_arn" {
  description = "Master credentials live here. Terraform never saw the value."
  value       = module.database.secret_arn
}

# The five-second question, opened from the README's measurements table.
output "dashboard_url" {
  value = module.observability.dashboard_url
}

# For set-alarm-state: prove the notification path before you need it.
output "alarm_names" {
  value = module.observability.alarm_names
}
