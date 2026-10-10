output "alb_dns_name" {
  description = "Public DNS name of the load balancer"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID, for a Route 53 alias record"
  value       = aws_lb.this.zone_id
}

output "alb_arn_suffix" {
  description = "For CloudWatch metric dimensions"
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.this.arn_suffix
}

output "app_security_group_id" {
  description = "Attach this as the source on the database security group"
  value       = aws_security_group.app.id
}

output "asg_name" {
  value = aws_autoscaling_group.this.name
}
