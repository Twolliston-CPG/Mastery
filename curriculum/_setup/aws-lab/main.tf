# Lab VM for weeks 1-4 on AWS. See README.md and ../DISTRO.md.
#
# The same design as ../gcp-lab: a dedicated network, no SSH port open to the internet,
# no cloud identity on the VM, and a schedule that stops it every night.
#
# In here, in order: the lookups (who am I, which zone, which AMI), the network, the firewall,
# flow logs, the VM, and the nightly stop. versions.tf pins the provider, variables.tf holds the
# knobs, outputs.tf prints how to connect, backend.tf says where state lives.

# Values derived from the variables, computed once and referenced below.
locals {
  # Login user baked into each image by cloud-init.
  ssh_user = { ubuntu = "ubuntu", arch = "arch" }[var.distro]

  # Ubuntu: Canonical publishes the current AMI ID as a public SSM parameter.
  # Arch: no official AMI exists; you supply a community one (var.arch_ami_id).
  ami_id = var.distro == "ubuntu" ? data.aws_ssm_parameter.ubuntu.insecure_value : var.arch_ami_id

  # One ingress rule per (port, source range) pair, keyed "80-1.2.3.4/32" so for_each has stable
  # names: removing one range removes only its rules, nothing shifts. An empty map when open_web
  # is false means the rules do not exist, not that a rule exists and allows nothing.
  web_rules = var.open_web ? {
    for pair in setproduct([80, 443], var.web_source_ranges) : "${pair[0]}-${pair[1]}" => { port = pair[0], cidr = pair[1] }
  } : {}
}

# The account ID. It pins the two IAM trust policies below to this account (aws:SourceAccount),
# so the same AWS service acting on behalf of another account cannot assume them.
data "aws_caller_identity" "this" {}

# The zones this region offers right now; the subnet takes the first. One VM needs one zone, and
# reading the list keeps the configuration valid in any region var.region names.
data "aws_availability_zones" "available" {
  # checkov:skip=CKV_AWS_394: One lab VM in the first available zone. Allowlisting zone names would hard-code a region into a configuration that takes var.region.
  state = "available"
}

# Canonical publishes the current Ubuntu 24.04 AMI ID for every region as a public SSM parameter,
# so no AMI is hard-coded to go stale. It is read on every plan; the instance ignores changes to
# it (lifecycle, below), so a newer image is reported by the `image` output, never applied.
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

# A dedicated VPC rather than the account's default one: the default VPC hands every instance a
# public IP and its default security group lets members talk to each other. 10.20.0.0/16 is
# private space chosen not to overlap the GCP lab (10.10.0.0/24), so the two could be joined
# later. DNS support and hostnames give the VM a resolver and an internal name.
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

# The VPC's only path to the internet. Without it the 0.0.0.0/0 route below has nowhere to point,
# and the symptom is package installs that time out rather than fail.
resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = { Name = "lab" }
}

# One /24 of the /16, in one zone: a subnet is zonal, a VPC is regional. 251 usable addresses,
# because AWS reserves five per subnet, which the week-2 subnetting drill asks you to explain.
resource "aws_subnet" "lab" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.20.0.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  # The VM asks for its public IP explicitly; nothing else launched here gets one.
  map_public_ip_on_launch = false

  tags = { Name = "lab" }
}

# The route table is what makes a subnet "public": a default route pointing at the internet
# gateway. Traffic inside the VPC is routed implicitly; only 0.0.0.0/0 needs a line.
resource "aws_route_table" "lab" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = { Name = "lab" }
}

# Until a subnet is associated with a route table it uses the VPC's main table, which has no
# internet route. This is the step people forget; the symptom is a VM that boots fine and cannot
# reach apt.
resource "aws_route_table_association" "lab" {
  subnet_id      = aws_subnet.lab.id
  route_table_id = aws_route_table.lab.id
}

# --- Firewall ------------------------------------------------------------------

# Security groups are stateful and default-deny inbound. Every rule below is an
# explicit hole. SSH reaches the VM only from the EC2 Instance Connect Endpoint --
# the AWS counterpart of GCP's IAP -- never from the internet.

# Two groups that reference each other by ID rather than by CIDR. The endpoint's group may send
# SSH only to members of the lab group; the lab group accepts SSH only from members of the
# endpoint group. A CIDR says where packets come from; a group reference says who, and it keeps
# working when addresses change.
resource "aws_security_group" "endpoint" {
  name        = "lab-endpoint"
  description = "EC2 Instance Connect Endpoint for the lab"
  vpc_id      = aws_vpc.lab.id

  tags = { Name = "lab-endpoint" }
}

# The VM's group. Deliberately empty here: every rule is its own aws_vpc_security_group_*_rule
# resource below, so adding or removing one rule never makes the provider rewrite the whole group.
resource "aws_security_group" "lab" {
  name        = "lab"
  description = "Lab VM"
  vpc_id      = aws_vpc.lab.id

  tags = { Name = "lab" }
}

# The endpoint's one permission: open port 22 on members of the lab group. Security groups are
# stateful, so the replies on that connection need no ingress rule of their own.
resource "aws_vpc_security_group_egress_rule" "endpoint_to_lab_ssh" {
  security_group_id            = aws_security_group.endpoint.id
  description                  = "The endpoint may open SSH to the lab VM and nothing else"
  referenced_security_group_id = aws_security_group.lab.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

# The matching half on the VM: SSH in, but only when the source is the endpoint's group. There is
# no port-22 rule from any CIDR, which is how the VM has a public IP and still no SSH port on the
# internet.
resource "aws_vpc_security_group_ingress_rule" "lab_ssh_from_endpoint" {
  # checkov:skip=CKV_AWS_24: False positive. The source is the endpoint's security group, not 0.0.0.0/0.
  security_group_id            = aws_security_group.lab.id
  description                  = "SSH from the Instance Connect Endpoint only"
  referenced_security_group_id = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

# Week 3 only. for_each over local.web_rules: no rules until open_web = true, then one per port
# per source range. The map key becomes the address, lab_web["80-0.0.0.0/0"], so the plan says
# exactly which hole is being opened.
resource "aws_vpc_security_group_ingress_rule" "lab_web" {
  for_each = local.web_rules

  security_group_id = aws_security_group.lab.id
  description       = "Week 3 web traffic"
  cidr_ipv4         = each.value.cidr
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
}

# Outbound: anything, anywhere; ip_protocol -1 is every protocol. This is the rule that lets apt,
# pip and docker pull work. The trivy note below records why it is not narrowed.
# trivy: unrestricted egress is the point of this rule. The VM installs packages and pulls
# images from the internet; there is no NAT or proxy to pin it to, and inbound stays default-deny.
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "lab_out" {
  security_group_id = aws_security_group.lab.id
  description       = "Outbound for package installs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# The EC2 Instance Connect Endpoint: an AWS-managed network interface in the subnet that ends SSH
# tunnels opened through the AWS API. You authenticate to AWS with IAM to open the tunnel, then to
# the VM with your key through it, and port 22 is never on the internet. preserve_client_ip is
# false because the VM's SSH rule names the endpoint's security group as the source; preserving
# the client IP would make packets arrive from your laptop's address and the rule would not match.
resource "aws_ec2_instance_connect_endpoint" "lab" {
  subnet_id          = aws_subnet.lab.id
  security_group_ids = [aws_security_group.endpoint.id]
  preserve_client_ip = false

  tags = { Name = "lab" }
}

# --- Flow logs -----------------------------------------------------------------

# Where flow logs land. One record per accepted or rejected 5-tuple with byte and packet counts:
# the evidence the week-3 packet-path work reads. 14 days covers a week of labs with room to look
# back. Every flow-log resource is behind count so flow_logs = false removes all four together.
resource "aws_cloudwatch_log_group" "flow" {
  # checkov:skip=CKV_AWS_158: Encrypted at rest with the CloudWatch Logs service key. A customer-managed KMS key costs money monthly and protects nothing extra in a lab.
  # checkov:skip=CKV_AWS_338: 14 days is enough to review a week's lab. A year of retention is a compliance requirement, not a lab one.
  count = var.flow_logs ? 1 : 0

  name              = "/lab/vpc-flow"
  retention_in_days = 14
}

# The identity the VPC Flow Logs service assumes to write into that group. The trust policy names
# the service principal and pins it to this account, so the same service acting for another
# account is refused.
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

# What that identity may do: create streams and put events in this one log group, nothing else.
# The ":*" suffix covers the streams inside the group; the group's ARN alone would not.
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

# Turns logging on for the whole VPC, accepted and rejected traffic both ("ALL"). The rejected
# half is the useful one: a packet a security group dropped appears as REJECT, which is how you
# tell "never arrived" from "refused" in week 3.
resource "aws_flow_log" "lab" {
  count = var.flow_logs ? 1 : 0

  vpc_id          = aws_vpc.lab.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow[0].arn
  iam_role_arn    = aws_iam_role.flow[0].arn
}

# --- VM ------------------------------------------------------------------------

# Registers the public half of your SSH key with EC2; cloud-init installs it for the login user at
# first boot. Terraform reads only the .pub file. The private half never leaves your machine.
resource "aws_key_pair" "lab" {
  key_name   = "lab"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# The VM: the image distro chose, in the one subnet, with the lab security group, a public IP for
# outbound traffic, and no IAM role. Each checkov skip inside is a deliberate decision, explained
# where it sits.
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

  # http_tokens = "required": every metadata GET must carry a session token obtained with a PUT,
  # which closes the classic SSRF path to instance credentials (week 5, Lab 5). hop_limit = 1:
  # the token reply will not cross a second network hop, so a process inside a Docker container on
  # this VM, one hop further away on its bridge, cannot reach the metadata service at all.
  # IMDSv2 only, and not reachable from inside a container on the VM (hop limit 1).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # gp3: 3,000 IOPS baseline at any size (week 5). Encrypted with the account's default EBS key.
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

# Exactly one action on exactly one resource. StopInstances on any other instance, or
# StartInstances on this one, is refused: the schedule can only ever turn this VM off.
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

# The schedule. EventBridge Scheduler is managed cron: an expression in a named time zone, a
# target that is an AWS API call rather than a function, and the role above to make the call.
# flexible_time_window OFF means at that minute, not somewhere inside a window. The target ARN is
# the universal-target form for EC2 StopInstances, and `input` is that API's request body.
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
