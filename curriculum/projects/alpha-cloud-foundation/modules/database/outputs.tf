# Outputs are the module's contract with the environment. Nothing reaches into this module;
# everything it exposes is listed here.

# Consumed by the application (through the environment's output and the README): host:port.
output "endpoint" {
  description = "Connection endpoint. A CNAME -- it does NOT change on failover."
  value       = aws_db_instance.this.endpoint
}

# Consumed by the compute module: the instance role is allowed to read exactly this secret.
output "secret_arn" {
  description = "Secrets Manager ARN holding the master credentials"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

# Consumed by nothing in Alpha today; exported so a later consumer (a bastion, a migration job)
# can be granted access by reference instead of by CIDR.
output "security_group_id" {
  value = aws_security_group.db.id
}

# Consumed by the observability module: the dimension on the free-storage alarm.
output "identifier" {
  value = aws_db_instance.this.identifier
}
