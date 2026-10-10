output "url" {
  description = "Load balancer URL"
  value       = "http://${module.compute.alb_dns_name}"
}

output "subnet_plan" {
  description = "CIDR allocation -- paste into the README"
  value       = module.network.subnet_plan
}

output "db_endpoint" {
  value = module.database.endpoint
}

output "db_secret_arn" {
  description = "Master credentials live here. Terraform never saw the value."
  value       = module.database.secret_arn
}

output "dashboard_url" {
  value = module.observability.dashboard_url
}

output "alarm_names" {
  value = module.observability.alarm_names
}
