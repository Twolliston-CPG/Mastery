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
#  - Contract: vpc_id, data_subnet_ids and the app security group in; endpoint, secret ARN,
#    security group id and identifier out. Everything lands in the data tier; the module never
#    reads the password it provisions and never touches the network it is given.

# One prefix, <project>-<environment>, on every name below, so a console search for the
# environment finds the subnet group, the security group, the key alias and the instance together.
locals {
  name = "${var.project}-${var.environment}"
}

# Where RDS may place the instance: the data-tier subnets, one per AZ, which the network module
# built with no default route. The primary lands in one, the Multi-AZ standby in another. The
# plan for a new environment shows this before the instance, because the instance names it.
resource "aws_db_subnet_group" "this" {
  name_prefix = "${local.name}-"
  subnet_ids  = var.data_subnet_ids
  tags        = { Name = local.name }

  # name_prefix plus create_before_destroy: a change that needs a new group creates it first and
  # repoints the instance, instead of trying to delete a group an instance still uses.
  lifecycle { create_before_destroy = true }
}

# The database's own security group. Empty on purpose until the rule below adds one hole; a
# security group with no ingress rules admits nothing, which is the right starting point for a
# database.
resource "aws_security_group" "db" {
  name_prefix = "${local.name}-db-"
  description = "Database access from the application tier only"
  vpc_id      = var.vpc_id

  # Same reason as the subnet group: renaming must not try to delete a group that is in use.
  lifecycle { create_before_destroy = true }
  tags = { Name = "${local.name}-db" }
}

# The only way in: TCP 5432 from members of the APP security group, by reference, not by CIDR.
# Instances in the auto scaling group come and go with new addresses; the reference follows
# membership, so nothing here changes when they do. A CIDR rule would also admit anything else
# that ever lands in those subnets.
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

# Read, not created: the account id and the partition (aws, aws-us-gov, aws-cn) build the
# account-root ARN in the key policy below, so the same module works in GovCloud unchanged.
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# A customer-managed key for the volume and the master-password secret. RDS can encrypt with the
# AWS-managed key for free, but then no policy of yours governs who may use it. Yearly rotation
# keeps the key id; the 30-day deletion window is the time to notice a mistaken destroy before the
# encrypted volume and every snapshot made from it become unreadable for good.
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

# A stable name for the key, so operators and other configurations refer to alias/<name>-rds and
# the key itself can be rotated or replaced behind it.
resource "aws_kms_alias" "db" {
  name          = "alias/${local.name}-rds"
  target_key_id = aws_kms_key.db.key_id
}

# PostgreSQL settings the instance boots with. The family must match the engine's major version
# (postgres16 for 16.x); a mismatch fails at apply, not at plan. Two parameters are set, both
# about seeing and securing what the application does.
resource "aws_db_parameter_group" "this" {
  name_prefix = "${local.name}-"
  family      = var.parameter_group_family

  # Slow-query log: anything over 1000 ms is written to the postgresql log, which the instance
  # exports to CloudWatch below. The first thing to read when p99 latency alarms.
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

  # A family change (a major upgrade) needs a new group: create it, repoint, then drop the old one.
  lifecycle { create_before_destroy = true }
}

# The database. What the arguments decide, group by group:
#   engine and class     PostgreSQL at the pinned minor; a Graviton burstable class in the lab.
#   storage              gp3, encrypted with the key above, autoscaling up to the ceiling.
#   credentials          RDS generates the master password into Secrets Manager; see the header.
#   placement            the subnet group, the security group, the parameter group, never public.
#   availability         multi_az: a synchronous standby in a second AZ. On failover RDS promotes
#                        it and repoints the endpoint's CNAME; the name does not change, so clients
#                        only have to reconnect. Measured in week 7: typically 60 to 120 seconds.
#   protection           deletion_protection and a final snapshot in prod only, so dev can be
#                        destroyed cleanly and prod cannot be destroyed by accident.
#   observability        Performance Insights in prod; postgresql and upgrade logs to CloudWatch.
# A plan that shows "forces replacement" on this resource is the week 10 BF-35 lesson: read it.
resource "aws_db_instance" "this" {
  # checkov:skip=CKV_AWS_293: False positive. deletion_protection is `var.environment == "prod"` below; checkov does not evaluate the comparison. Dev stays unprotected so `make destroy` works.
  # checkov:skip=CKV_AWS_353: False positive. performance_insights_enabled is `var.environment == "prod"` below; same reason.
  # checkov:skip=CKV_AWS_118: Enhanced monitoring needs a monitoring IAM role and bills per instance for OS-level metrics the dashboard does not use. The free CloudWatch RDS metrics drive the alarms.
  identifier_prefix = "${local.name}-"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # gp3 gives 3,000 IOPS at any size, so 20 GB is not a performance choice here. Autoscaling
  # grows the volume toward max_allocated_storage when free space runs low; it never shrinks.
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

  # Placement: the data-tier subnets, the group with one rule, the parameters above, and no public
  # address. publicly_accessible = false is also what keeps the instance off the plan's blast radius
  # when the security group is loosened by mistake.
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  # IAM auth lets the instance role mint 15-minute tokens instead of using the master password
  # at all. Free, and the password in Secrets Manager then exists only for break-glass.
  iam_database_authentication_enabled = true

  # Availability and recovery. Backups run in a one-hour window at 03:00 UTC, maintenance in the
  # hour after, on Monday; copy_tags_to_snapshot keeps the tags, and the cost attribution, on
  # every snapshot.
  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot   = true

  # Protection, per environment. Minor engine upgrades are applied in the maintenance window.
  # In prod a destroy is refused and a final snapshot is taken; in dev neither, so the lab's
  # destroy is one command. The timestamp in the snapshot name is why ignore_changes exists below.
  auto_minor_version_upgrade = true
  deletion_protection        = var.environment == "prod"
  skip_final_snapshot        = var.environment != "prod"
  final_snapshot_identifier  = var.environment == "prod" ? "${local.name}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}" : null

  # Performance Insights bills per vCPU beyond the free 7-day tier, so prod only. The two log
  # exports feed CloudWatch Logs: the slow-query log from the parameter group, and upgrade logs.
  performance_insights_enabled          = var.environment == "prod"
  performance_insights_retention_period = var.environment == "prod" ? 7 : null
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  # Name only; the common tags arrive through the provider's default_tags in the environment.
  tags = { Name = local.name }

  lifecycle {
    # Uncomment in prod. Left commented so the reference repo can be destroyed
    # cleanly during the lab; documented in docs/adr/0004-prevent-destroy.md.
    # prevent_destroy = true
    ignore_changes = [final_snapshot_identifier]
  }
}
