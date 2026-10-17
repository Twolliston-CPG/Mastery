# Database module: RDS PostgreSQL in the data tier.
#
# Design decisions:
#  - manage_master_user_password = true. RDS generates the password and puts it
#    straight into Secrets Manager with rotation. Terraform NEVER sees the value,
#    so it never lands in plaintext state. This is the correct answer to
#    "how do you handle database passwords in IaC".
#  - prevent_destroy in prod. A plan that says "1 to destroy" on a production
#    database should fail at plan time, not depend on someone reading carefully.
#  - The security group source is the APP security group, not a CIDR.

locals {
  name = "${var.project}-${var.environment}"
}

resource "aws_db_subnet_group" "this" {
  name_prefix = "${local.name}-"
  subnet_ids  = var.data_subnet_ids
  tags        = { Name = local.name }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "db" {
  name_prefix = "${local.name}-db-"
  description = "Database access from the application tier only"
  vpc_id      = var.vpc_id

  lifecycle { create_before_destroy = true }
  tags = { Name = "${local.name}-db" }
}

resource "aws_vpc_security_group_ingress_rule" "from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "Postgres from the application security group"
  referenced_security_group_id = var.app_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# Deliberately no egress rule: the database has no reason to initiate outbound
# connections, and the data subnets have no default route anyway.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "aws_kms_key" "db" {
  description             = "${local.name} RDS encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = { Name = local.name }

  # An explicit key policy, even though it reproduces the default. The default is implicit and
  # invisible in review; writing it down is what lets a later "and this service may use it" be a
  # diff rather than a console change. RDS and Secrets Manager use the key through grants created
  # by the caller's IAM permissions, so no service principal needs listing here.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AccountAdministration"
      Effect    = "Allow"
      Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_kms_alias" "db" {
  name          = "alias/${local.name}-rds"
  target_key_id = aws_kms_key.db.key_id
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${local.name}-"
  family      = var.parameter_group_family

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # log anything slower than 1s
  }

  # Encryption at rest is storage_encrypted below; this is encryption in transit. Without it a
  # client that forgets sslmode=require talks to the database in clear text inside the VPC.
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_db_instance" "this" {
  # checkov:skip=CKV_AWS_293: False positive. deletion_protection is `var.environment == "prod"` below; checkov does not evaluate the comparison. Dev stays unprotected so `make destroy` works.
  # checkov:skip=CKV_AWS_353: False positive. performance_insights_enabled is `var.environment == "prod"` below; same reason.
  # checkov:skip=CKV_AWS_118: Enhanced monitoring needs a monitoring IAM role and bills per instance for OS-level metrics the dashboard does not use. The free CloudWatch RDS metrics drive the alarms.
  identifier_prefix = "${local.name}-"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.db.arn

  db_name  = var.db_name
  username = var.master_username

  # Terraform never sees this value. It goes straight to Secrets Manager.
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.db.key_id

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  # IAM auth lets the instance role mint 15-minute tokens instead of using the master password
  # at all. Free, and the password in Secrets Manager then exists only for break-glass.
  iam_database_authentication_enabled = true

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot   = true

  auto_minor_version_upgrade = true
  deletion_protection        = var.environment == "prod"
  skip_final_snapshot        = var.environment != "prod"
  final_snapshot_identifier  = var.environment == "prod" ? "${local.name}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}" : null

  performance_insights_enabled          = var.environment == "prod"
  performance_insights_retention_period = var.environment == "prod" ? 7 : null
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  tags = { Name = local.name }

  lifecycle {
    # Uncomment in prod. Left commented so the reference repo can be destroyed
    # cleanly during the lab; documented in docs/adr/0004-prevent-destroy.md.
    # prevent_destroy = true
    ignore_changes = [final_snapshot_identifier]
  }
}
