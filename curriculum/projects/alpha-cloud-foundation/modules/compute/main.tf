# Compute module: ALB in public subnets -> ASG in app subnets.
#
# Design decisions:
#  - The instance security group allows the ALB's SECURITY GROUP, not a CIDR.
#    The rule then follows instances as they are replaced and works across AZs.
#    A CIDR rule is the standard cause of an ALB returning 503 (Target.Timeout).
#  - health_check_grace_period is generous. Too short is the classic ASG
#    launch/terminate loop: ELB health checks start before the app has booted.
#  - IMDSv2 is enforced. IMDSv1 turns any SSRF into credential theft.
#
# Contract: VPC and subnet IDs in (from the network module), sizing and an optional certificate
# and secret ARN; the ALB's DNS name and metric dimensions, the ASG name and the app security
# group out. The module does not know how the subnets were made and does not create the
# database it reads the secret for; it composes through outputs, never by reaching across.

# One name prefix used on every resource, so a `Name` tag or a console search finds the set.
locals {
  name = "${var.project}-${var.environment}"
}

# The newest Amazon Linux 2023 image on the 6.1 kernel, owned by Amazon, resolved at plan time.
# most_recent means a new AL2023 release changes image_id, the launch template gets a new
# version, and the ASG's instance refresh rolls every instance on the next apply. Pin an AMI ID
# or add ignore_changes on image_id if that surprise is unwanted; the aws-lab does the latter.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
}

# ------------------------------------------------------- security groups ----
# The ALB's group, with no inline rules: every rule is its own resource below, so one can
# change without touching the others. name_prefix plus create_before_destroy is the pattern for
# anything referenced by ID: a replacement gets a new name, is created first, references move,
# then the old one goes. A fixed name would deadlock on "already exists".
resource "aws_security_group" "alb" {
  name_prefix = "${local.name}-alb-"
  description = "ALB ingress"
  vpc_id      = var.vpc_id

  lifecycle { create_before_destroy = true }
  tags = { Name = "${local.name}-alb" }
}

# Port 80 from anywhere. Security groups are stateful: the reply to an admitted connection
# needs no egress rule, which is why the egress below can be as narrow as it is.
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  # checkov:skip=CKV_AWS_260: A public load balancer accepts port 80 from the internet by definition. With a certificate the listener answers 301 to HTTPS; without one (lab, no domain) it forwards.
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet (redirects to HTTPS)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Port 443 only exists when there is a certificate to terminate it with. The same condition
# gates the HTTPS listener and the HTTP listener's redirect, so one variable flips all three.
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count = var.certificate_arn == null ? 0 : 1

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# The ALB only ever talks to the instances, so its egress is the app security group on the
# app port -- the mirror image of app_from_alb below. Nothing else can be reached from the ALB.
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward and health-check traffic to the app instances only"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

# The rule used to be an allow-all named alb_all. `moved` keeps an existing deployment from
# destroying and recreating it under the new address.
moved {
  from = aws_vpc_security_group_egress_rule.alb_all
  to   = aws_vpc_security_group_egress_rule.alb_to_app
}

# The instances' group. Same lifecycle pattern as the ALB's; its one ingress rule is the
# reference to the ALB group below, and its ID is exported for the database module to use the
# same way. Nothing ever lists an instance's address anywhere.
resource "aws_security_group" "app" {
  name_prefix = "${local.name}-app-"
  description = "Application instances"
  vpc_id      = var.vpc_id

  lifecycle { create_before_destroy = true }
  tags = { Name = "${local.name}-app" }
}

# Source is the ALB's SECURITY GROUP ID, not a CIDR. This is the important line.
# The ALB's nodes change address whenever it scales; a group reference follows them, a CIDR
# does not. Health checks come from those same nodes, so a wrong source here shows up as every
# target unhealthy with Reason Target.Timeout (BF-28), not as a refused request.
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from the ALB only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

# All outbound from the instances, via the NAT gateway. The compensating controls are the
# inbound rule above and the data tier's missing default route, not this rule.
# trivy: the instances need the internet, through the NAT gateway, for package installs, the SSM
# agent, and CloudWatch. There is no proxy or private endpoint set to pin them to, and inbound stays
# "from the ALB only" above.
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound via NAT: packages, SSM agent, CloudWatch agent"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ------------------------------------------------------------------ IAM -----
# The role the instances run as. The trust policy says only the EC2 service may assume it; what
# it may DO is the attachments and the inline policy below. Credentials for it are served to
# the instance by IMDS, which is why metadata_options on the launch template matter.
resource "aws_iam_role" "instance" {
  name_prefix = "${local.name}-ec2-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# SSM Session Manager instead of a bastion: no open port 22, no SSH keys to
# distribute, and every session is in CloudTrail.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Lets the CloudWatch agent on the instance ship metrics and logs; the observability module's
# alarms read what this permits writing.
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Least privilege: read exactly one secret, not secretsmanager:* on *.
resource "aws_iam_role_policy" "db_secret" {
  count = var.db_secret_arn == null ? 0 : 1

  name_prefix = "db-secret-"
  role        = aws_iam_role.instance.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.db_secret_arn
    }]
  })
}

# EC2 cannot attach a role directly; the profile is the wrapper the launch template references.
# One role, one profile, always; the indirection is historical and you will type it forever.
resource "aws_iam_instance_profile" "instance" {
  name_prefix = "${local.name}-"
  role        = aws_iam_role.instance.name
}

# ------------------------------------------------------------------ ALB -----
# The load balancer: layer 7, in the public subnets, two AZs minimum (which is why az_count has
# a floor of 2). name_prefix is capped at six characters by AWS, hence the substr. Deletion
# protection follows the environment so `terraform destroy` works in dev and is refused in prod.
# drop_invalid_header_fields stops header-smuggling requests before they reach the app.
# trivy: internet-facing is the point of this load balancer (AVD-AWS-0053).
#trivy:ignore:AVD-AWS-0053
resource "aws_lb" "this" {
  # checkov:skip=CKV2_AWS_20: Same decision as CKV_AWS_2 on the listener below: with certificate_arn the :80 listener is a 301 to HTTPS; without one (lab) it forwards. checkov does not evaluate the dynamic blocks.
  # checkov:skip=CKV2_AWS_28: A WAF web ACL is a separate project (rules, logging, tuning, ~$5+/month). The foundation project stops at the load balancer; the app security group admits only the ALB.
  # checkov:skip=CKV_AWS_150: False positive. enable_deletion_protection is `var.environment == "prod"` below; checkov does not evaluate the comparison. Dev stays unprotected so `make destroy` works.
  # checkov:skip=CKV_AWS_91: Access logs need a log bucket with the regional ELB service-principal policy and a lifecycle rule. Deliberately outside the foundation project; the 5xx and p99 alarms are the request-level signal here.
  name_prefix        = substr(var.project, 0, 6)
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  enable_deletion_protection = var.environment == "prod"
  drop_invalid_header_fields = true

  tags = { Name = local.name }
}

# Where the ALB sends traffic, and the health check that decides which instances get it. The
# ASG registers its instances here; the ALB never knows about the ASG. Health check numbers:
# interval 15 s, two consecutive results to change state, so a dead instance is out of rotation
# in 30 s and a new one is in after 30 s; timeout 5 s must stay below the interval. The matcher
# is the status range that counts as healthy; a redirect on /health would fail it.
resource "aws_lb_target_group" "this" {
  # checkov:skip=CKV_AWS_378: TLS terminates at the load balancer. ALB-to-instance traffic is plain HTTP on the app port, inside the VPC, admitted only from the ALB security group. End-to-end TLS would need a certificate on every instance for no exposure gain here.
  name_prefix = substr(var.project, 0, 6)
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = var.health_check_path
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }

  # Let in-flight requests finish before an instance is removed. The default is
  # 300s, which makes every deploy slow; 30s is usually plenty for HTTP.
  deregistration_delay = 30

  lifecycle { create_before_destroy = true }
}

# The :80 listener. The two dynamic blocks are mutually exclusive on certificate_arn, so exactly
# one default_action is rendered: a redirect when TLS exists, a forward when it does not.
# trivy: plain HTTP on :80 is either a 301 to HTTPS (certificate set) or the lab's only listener
# (no domain, so no certificate). Same decision as the CKV_AWS_2 skip inside.
#trivy:ignore:AVD-AWS-0054
resource "aws_lb_listener" "http" {
  # checkov:skip=CKV_AWS_103: Not applicable. This is the HTTP listener; there is no TLS policy to set. The HTTPS listener below uses ELBSecurityPolicy-TLS13-1-2-2021-06.
  # checkov:skip=CKV_AWS_2: With certificate_arn set this listener only redirects to the HTTPS listener below. Without one (lab, no domain) HTTP is the only option. checkov does not evaluate the dynamic blocks.
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  # With a cert, redirect to HTTPS. Without one (lab), forward directly.
  dynamic "default_action" {
    for_each = var.certificate_arn == null ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }
  }

  dynamic "default_action" {
    for_each = var.certificate_arn == null ? [] : [1]
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

# The :443 listener, only with a certificate. TLS terminates here; the target group speaks plain
# HTTP to the instances inside the VPC. The policy name pins TLS 1.2 and 1.3 ciphers.
resource "aws_lb_listener" "https" {
  count = var.certificate_arn == null ? 0 : 1

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# ------------------------------------------------- launch template + ASG ----
# What every instance is made from: AMI, size, profile, security group, metadata settings, disk,
# and the user data that installs and starts the app. Templates are versioned; any change here
# is a new version, and the ASG below tracks $Latest, so the change rolls out by refresh.
resource "aws_launch_template" "this" {
  name_prefix   = "${local.name}-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile { arn = aws_iam_instance_profile.instance.arn }
  vpc_security_group_ids = [aws_security_group.app.id]

  # IMDSv2 required; hop limit 1 so the response cannot cross a container bridge.
  # "required" means a plain GET to 169.254.169.254 gets a 401; a token from a PUT is needed
  # first, which an SSRF cannot do. The hop limit is the TTL on the reply: 1 reaches the host's
  # own stack and dies at a bridge, so a container on the instance cannot read its role.
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  # Detailed (1-minute) CloudWatch metrics cost per instance; prod pays, dev takes 5-minute.
  monitoring { enabled = var.environment == "prod" }

  # The root volume: gp3 (fixed baseline, no size-coupled IOPS), encrypted with the account's
  # default EBS key, gone with the instance because nothing on it is state.
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # cloud-init runs this once on first boot. The template receives the four values the app
  # needs; the empty-string coalesce keeps the template valid when there is no secret.
  user_data = base64encode(templatefile("${path.module}/user-data.sh.tftpl", {
    app_port      = var.app_port
    health_path   = var.health_check_path
    environment   = var.environment
    db_secret_arn = coalesce(var.db_secret_arn, "")
  }))

  # Tags on the instance itself (the ASG's tag block below also propagates; this covers an
  # instance launched from the template by hand).
  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-app" }
  }

  lifecycle { create_before_destroy = true }
}

# The group that keeps N instances running across the app subnets and registered in the target
# group. min/max are the bounds the scaling policy may move within; desired is where it starts.
resource "aws_autoscaling_group" "this" {
  name_prefix         = "${local.name}-"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.app_subnet_ids
  target_group_arns   = [aws_lb_target_group.this.arn]

  # ELB health checks (not EC2) -- EC2 only checks that the instance is running,
  # so a crashed application still counts as healthy.
  health_check_type = "ELB"
  # Generous grace period: too short is the classic launch/terminate loop.
  # During the grace period an unhealthy ELB result is ignored. If the app takes 90 s to boot and
  # the grace is 30 s, the ASG terminates every instance at 30 s and launches another, forever
  # (BF-29). The number must exceed boot time plus two health-check intervals.
  health_check_grace_period = var.health_check_grace_period

  # $Latest: a new template version is picked up without editing the ASG. The alternative,
  # $Default or a number, needs a second step to promote a version.
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  # How a template change reaches running instances: replace them in batches, never dropping
  # below half healthy, and count a new instance as ready only after the same warmup as the
  # grace period, so a refresh cannot outrun the app's boot.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = var.health_check_grace_period
    }
  }

  # ASG tags are a repeated block, not a map, hence the dynamic block. propagate_at_launch copies
  # each one onto the instances the group creates.
  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${local.name}-app" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # ignore_changes on desired_capacity: once the scaling policy has moved the count, a plan must
  # not drag it back to the variable's value. The variable sets the starting point only.
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity] # let scaling policies own this
  }
}

# Target tracking: pick a metric and a target and let AWS manage the alarms.
# AWS creates and owns two CloudWatch alarms for this policy (they are not in state). Scale-out
# is fast; scale-in waits a cooldown, which is why the week-7 lab measured ~15 minutes to come
# back down. target_value is a percentage of average CPU across the group.
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${local.name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target
  }
}
