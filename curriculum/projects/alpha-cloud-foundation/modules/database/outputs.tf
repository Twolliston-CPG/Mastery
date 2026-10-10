output "endpoint" {
  description = "Connection endpoint. A CNAME -- it does NOT change on failover."
  value       = aws_db_instance.this.endpoint
}

output "secret_arn" {
  description = "Secrets Manager ARN holding the master credentials"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  value = aws_security_group.db.id
}

output "identifier" {
  value = aws_db_instance.this.identifier
}
