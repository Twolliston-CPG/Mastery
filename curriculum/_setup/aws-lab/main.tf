# Lab VM for weeks 1-4 on AWS. See README.md and ../DISTRO.md.
#
# The same design as ../gcp-lab: a dedicated network, no SSH port open to the internet,
# no cloud identity on the VM, and a schedule that stops it every night.

locals {
  # Login user baked into each image by cloud-init.
  ssh_user = { ubuntu = "ubuntu", arch = "arch" }[var.distro]

  # Ubuntu: Canonical publishes the current AMI ID as a public SSM parameter.
  # Arch: no official AMI exists; you supply a community one (var.arch_ami_id).
  ami_id = var.distro == "ubuntu" ? data.aws_ssm_parameter.ubuntu.insecure_value : var.arch_ami_id

  web_rules = var.open_web ? {
    for pair in setproduct([80, 443], var.web_source_ranges) : "${pair[0]}-${pair[1]}" => { port = pair[0], cidr = pair[1] }
  } : {}
}

data "aws_caller_identity" "this" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# Looked up only to report what you are booting: name, owner account, build date.
# For Ubuntu it also enforces that the image really is published by Canonical.
data "aws_ami" "lab" {
  owners = var.distro == "ubuntu" ? ["099720109477"] : null

  filter {
    name   = "image-id"
    values = [local.ami_id]
  }
}

# --- Network -------------------------------------------------------------------

resource "aws_vpc" "lab" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "lab" }
}

# The VPC's default security group allows members to talk to each other. Nothing
# uses it; strip its rules so nothing can by accident.
resource "aws_default_security_group" "lab" {
  vpc_id = aws_vpc.lab.id
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = { Name = "lab" }
}

resource "aws_subnet" "lab" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.20.0.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  # The VM asks for its public IP explicitly; nothing else launched here gets one.
  map_public_ip_on_launch = false

  tags = { Name = "lab" }
}

resource "aws_route_table" "lab" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = { Name = "lab" }
}

resource "aws_route_table_association" "lab" {
  subnet_id      = aws_subnet.lab.id
  route_table_id = aws_route_table.lab.id
}

# --- Firewall ------------------------------------------------------------------

# Security groups are stateful and default-deny inbound. Every rule below is an
# explicit hole. SSH reaches the VM only from the EC2 Instance Connect Endpoint --
# the AWS counterpart of GCP's IAP -- never from the internet.

resource "aws_security_group" "endpoint" {
  name        = "lab-endpoint"
  description = "EC2 Instance Connect Endpoint for the lab"
  vpc_id      = aws_vpc.lab.id

  tags = { Name = "lab-endpoint" }
}

resource "aws_security_group" "lab" {
  name        = "lab"
  description = "Lab VM"
  vpc_id      = aws_vpc.lab.id

  tags = { Name = "lab" }
}

resource "aws_vpc_security_group_egress_rule" "endpoint_to_lab_ssh" {
  security_group_id            = aws_security_group.endpoint.id
  description                  = "The endpoint may open SSH to the lab VM and nothing else"
  referenced_security_group_id = aws_security_group.lab.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_ingress_rule" "lab_ssh_from_endpoint" {
  # checkov:skip=CKV_AWS_24: False positive. The source is the endpoint's security group, not 0.0.0.0/0.
  security_group_id            = aws_security_group.lab.id
  description                  = "SSH from the Instance Connect Endpoint only"
  referenced_security_group_id = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_ingress_rule" "lab_web" {
  for_each = local.web_rules

  security_group_id = aws_security_group.lab.id
  description       = "Week 3 web traffic"
  cidr_ipv4         = each.value.cidr
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "lab_out" {
  security_group_id = aws_security_group.lab.id
  description       = "Outbound for package installs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_ec2_instance_connect_endpoint" "lab" {
  subnet_id          = aws_subnet.lab.id
  security_group_ids = [aws_security_group.endpoint.id]
  preserve_client_ip = false

  tags = { Name = "lab" }
}

# --- Flow logs -----------------------------------------------------------------

resource "aws_cloudwatch_log_group" "flow" {
  # checkov:skip=CKV_AWS_158: Encrypted at rest with the CloudWatch Logs service key. A customer-managed KMS key costs money monthly and protects nothing extra in a lab.
  # checkov:skip=CKV_AWS_338: 14 days is enough to review a week's lab. A year of retention is a compliance requirement, not a lab one.
  count = var.flow_logs ? 1 : 0

  name              = "/lab/vpc-flow"
  retention_in_days = 14
}

resource "aws_iam_role" "flow" {
  count = var.flow_logs ? 1 : 0

  name = "lab-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.this.account_id } }
    }]
  })
}

resource "aws_iam_role_policy" "flow" {
  count = var.flow_logs ? 1 : 0

  name = "write-lab-flow-logs"
  role = aws_iam_role.flow[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.flow[0].arn}:*"
    }]
  })
}

resource "aws_flow_log" "lab" {
  count = var.flow_logs ? 1 : 0

  vpc_id          = aws_vpc.lab.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow[0].arn
  iam_role_arn    = aws_iam_role.flow[0].arn
}

# --- VM ------------------------------------------------------------------------

resource "aws_key_pair" "lab" {
  key_name   = "lab"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_instance" "lab" {
  # checkov:skip=CKV_AWS_88: The public IP is deliberate - outbound package installs without paying for a NAT gateway, and Week 3 serves 80/443. Inbound is default-deny; SSH is endpoint-only.
  # checkov:skip=CKV2_AWS_41: No IAM role on purpose. The VM gets no AWS identity, so nothing running on it can call AWS APIs.
  # checkov:skip=CKV_AWS_126: Detailed monitoring is a paid feature a single lab VM does not need.
  ami           = local.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.lab.id
  key_name      = aws_key_pair.lab.key_name

  vpc_security_group_ids      = [aws_security_group.lab.id]
  associate_public_ip_address = true
  ebs_optimized               = true

  # IMDSv2 only, and not reachable from inside a container on the VM (hop limit 1).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = var.disk_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  # "standard": when CPU credits run out the VM slows down instead of billing extra.
  credit_specification {
    cpu_credits = "standard"
  }

  tags = { Name = "lab" }

  lifecycle {
    # Canonical republishes the Ubuntu AMI often. A newer image must never rebuild your VM.
    ignore_changes = [ami]
  }
}

# --- Auto-stop -----------------------------------------------------------------

# EventBridge Scheduler calls ec2:StopInstances directly; there is no Lambda. The
# role it assumes can stop this one instance and do nothing else.
resource "aws_iam_role" "auto_stop" {
  count = var.auto_stop_cron == null ? 0 : 1

  name = "lab-auto-stop"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.this.account_id } }
    }]
  })
}

resource "aws_iam_role_policy" "auto_stop" {
  count = var.auto_stop_cron == null ? 0 : 1

  name = "stop-lab-instance"
  role = aws_iam_role.auto_stop[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ec2:StopInstances"
      Resource = aws_instance.lab.arn
    }]
  })
}

resource "aws_scheduler_schedule" "auto_stop" {
  # checkov:skip=CKV_AWS_297: The schedule holds an instance ID, not a secret. A customer-managed KMS key adds cost and nothing else.
  count = var.auto_stop_cron == null ? 0 : 1

  name                         = "lab-auto-stop"
  schedule_expression          = var.auto_stop_cron
  schedule_expression_timezone = var.time_zone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.auto_stop[0].arn
    input    = jsonencode({ InstanceIds = [aws_instance.lab.id] })
  }
}
