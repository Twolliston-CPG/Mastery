# The module contract. The environments re-export alb_dns_name as `url`; the three metric
# dimensions below feed the observability module; the security group feeds the database module.
output "alb_dns_name" {
  description = "Public DNS name of the load balancer"
  value       = aws_lb.this.dns_name
}

# Not used by the environments today: the value a Route 53 alias record needs, for when a domain
# arrives (the certificate_arn path).
output "alb_zone_id" {
  description = "Hosted zone ID, for a Route 53 alias record"
  value       = aws_lb.this.zone_id
}

# Consumed by observability: the LoadBalancer dimension on the 5xx and latency alarms.
output "alb_arn_suffix" {
  description = "For CloudWatch metric dimensions"
  value       = aws_lb.this.arn_suffix
}

# Consumed by observability: the TargetGroup dimension on the healthy-host alarm.
output "target_group_arn_suffix" {
  value = aws_lb_target_group.this.arn_suffix
}

# Consumed by database: the source on its ingress rule, so only these instances reach the port.
output "app_security_group_id" {
  description = "Attach this as the source on the database security group"
  value       = aws_security_group.app.id
}

# Consumed by observability: the AutoScalingGroupName dimension on the CPU alarm.
output "asg_name" {
  value = aws_autoscaling_group.this.name
}
