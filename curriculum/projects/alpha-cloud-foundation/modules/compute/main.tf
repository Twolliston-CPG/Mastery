# Compute module: ALB in public subnets -> ASG in app subnets.
#
# Design decisions:
#  - The instance security group allows the ALB's SECURITY GROUP, not a CIDR.
#    The rule then follows instances as they are replaced and works across AZs.
#    A CIDR rule is the standard cause of an ALB returning 503 (Target.Timeout).
#  - health_check_grace_period is generous. Too short is the classic ASG
#    launch/terminate loop: ELB health checks start before the app has booted.
#  - IMDSv2 is enforced. IMDSv1 turns any SSRF into credential theft.

locals {
  name = "${var.project}-${var.environment}"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
}

# ------------------------------------------------------- security groups ----
resource "aws_security_group" "alb" {
  name_prefix = "${local.name}-alb-"
  description = "ALB ingress"
  vpc_id      = var.vpc_id

  lifecycle { create_before_destroy = true }
  tags = { Name = "${local.name}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet (redirects to HTTPS)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count = var.certificate_arn == null ? 0 : 1

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "app" {
  name_prefix = "${local.name}-app-"
  description = "Application instances"
  vpc_id      = var.vpc_id

  lifecycle { create_before_destroy = true }
  tags = { Name = "${local.name}-app" }
}

# Source is the ALB's SECURITY GROUP ID, not a CIDR. This is the important line.
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from the ALB only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ------------------------------------------------------------------ IAM -----
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

resource "aws_iam_instance_profile" "instance" {
  name_prefix = "${local.name}-"
  role        = aws_iam_role.instance.name
}

# ------------------------------------------------------------------ ALB -----
resource "aws_lb" "this" {
  name_prefix        = substr(var.project, 0, 6)
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  enable_deletion_protection = var.environment == "prod"
  drop_invalid_header_fields = true

  tags = { Name = local.name }
}

resource "aws_lb_target_group" "this" {
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

resource "aws_lb_listener" "http" {
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
resource "aws_launch_template" "this" {
  name_prefix   = "${local.name}-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile { arn = aws_iam_instance_profile.instance.arn }
  vpc_security_group_ids = [aws_security_group.app.id]

  # IMDSv2 required; hop limit 1 so the response cannot cross a container bridge.
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  monitoring { enabled = var.environment == "prod" }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh.tftpl", {
    app_port      = var.app_port
    health_path   = var.health_check_path
    environment   = var.environment
    db_secret_arn = coalesce(var.db_secret_arn, "")
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-app" }
  }

  lifecycle { create_before_destroy = true }
}

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
  health_check_grace_period = var.health_check_grace_period

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = var.health_check_grace_period
    }
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${local.name}-app" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity] # let scaling policies own this
  }
}

# Target tracking: pick a metric and a target and let AWS manage the alarms.
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
