# Observability module: alarms that are worth waking someone for, plus a
# dashboard that answers "are users having a bad time?" in five seconds.
#
# Design decision: these alarms are SYMPTOM-based, not cause-based. High CPU is
# not an incident. 5xx responses and p99 latency are. See _shared/breakfix BF-57.
#
# Contract: the load balancer, target group and auto scaling group identifiers in, plus the
# database identifier and an email; the topic ARN, the dashboard URL and the alarm names out. It
# creates nothing that serves traffic and it owns the only path from an alarm to a human.

# The same <project>-<environment> prefix as the other modules, so an alarm name says which
# environment is paging before you open it.
locals {
  name = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------- encryption ------
# Why a customer-managed key and not alias/aws/sns: CloudWatch Alarms publish to the topic, and
# the AWS-managed SNS key's policy does not let cloudwatch.amazonaws.com use it. Encrypt the topic
# with alias/aws/sns and every alarm fires into silence -- "KMS access denied" shows up only in
# the alarm history. The key policy below is the whole point of the resource.
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "aws_kms_key" "alerts" {
  description             = "${local.name} alert topic encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = { Name = "${local.name}-alerts" }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CloudWatchAlarmsPublish"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey*"]
        Resource  = "*"
      },
    ]
  })
}

# A stable name for the key, for the same reason as the database module's alias.
resource "aws_kms_alias" "alerts" {
  name          = "alias/${local.name}-alerts"
  target_key_id = aws_kms_key.alerts.key_id
}

# The fan-out point. Every alarm publishes here and every human or system that should hear about
# it subscribes here, so adding a pager later is a subscription, not four alarm edits.
resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-alerts"
  kms_master_key_id = aws_kms_key.alerts.id
}

# count as a switch: no email, no subscription, and the alarms publish to a topic nobody reads.
# Terraform can create the subscription but cannot confirm it; the confirmation is a link in an
# email, and until it is clicked the topic delivers nothing. Test the path after apply with the
# alarm_names output's set-alarm-state command, not by waiting for an outage.
resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
  # NOTE: this subscription is PendingConfirmation until you click the link in
  # the email. An unconfirmed subscription means the alarm fires and nobody
  # hears it -- the most annoying cause of BF-32.
}

# SYMPTOM: users are getting errors.
# The maths: Sum of 5xx over 60-second periods, 2 consecutive periods above the threshold
# (default 5 per minute) before it fires, so a single bad minute does not page. ok_actions sends
# the recovery too, which is how you know an incident ended without logging in.
resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  alarm_name          = "${local.name}-target-5xx"
  alarm_description   = "Application is returning 5xx responses. Runbook: docs/runbooks/5xx.md"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = var.error_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching" # no requests = no errors; correct here
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# SYMPTOM: the load balancer has nowhere to send traffic. This is a total outage.
# Minimum healthy count over 60 seconds, 2 periods, LessThan 1: zero healthy targets for two
# minutes. No ok_actions here on purpose; the recovery is visible on the 5xx alarm.
resource "aws_cloudwatch_metric_alarm" "no_healthy_hosts" {
  alarm_name        = "${local.name}-no-healthy-hosts"
  alarm_description = "Zero healthy targets. The ALB is returning 503 to everyone."
  namespace         = "AWS/ApplicationELB"
  metric_name       = "HealthyHostCount"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  # breaching, NOT notBreaching: if the metric stops publishing, something is
  # very wrong. Treating missing data as healthy here would hide the outage.
  treat_missing_data = "breaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
}

# SYMPTOM: the site is slow.
# extended_statistic because a percentile is not one of the five basic statistics. 300-second
# periods, 2 of them: ten minutes with the slowest one percent of requests above the threshold
# (default 1.0 s). Longer periods than the error alarm because latency is noisy minute to minute.
resource "aws_cloudwatch_metric_alarm" "latency_p99" {
  alarm_name          = "${local.name}-latency-p99"
  alarm_description   = "p99 latency above target. Users notice this."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  extended_statistic  = "p99"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.latency_p99_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# CAUSE-based, but genuinely actionable: running out of disk is a hard failure.
# count as a switch: no database identifier, no alarm. One 300-second period is enough because
# free storage does not flap; breaching on missing data because a database that stops reporting
# is a database you want to look at. The threshold is bytes (default 2 GiB).
resource "aws_cloudwatch_metric_alarm" "db_storage" {
  count = var.db_instance_id == null ? 0 : 1

  alarm_name          = "${local.name}-db-free-storage"
  alarm_description   = "RDS free storage below threshold."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = var.db_instance_id }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.db_free_storage_bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# The dashboard is one JSON document; jsonencode builds it from HCL so the metric names and
# dimensions are the same expressions the alarms use. Four widgets on a 24-column grid, symptoms
# on the top row and the one cause on the bottom right, which is the reading order on call. The
# "." and "..." entries repeat the previous row's namespace and dimensions, the console's own
# shorthand. region is per widget because the console renders a dashboard from any region.
resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = local.name
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Request rate and errors (SYMPTOM -- read this first)"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", color = "#d62728" }],
            [".", "HTTPCode_ELB_5XX_Count", ".", ".", { stat = "Sum", color = "#ff7f0e" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Latency p50 / p99 (SYMPTOM)"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p50" }],
            ["...", { stat = "p99", color = "#d62728" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "Healthy hosts (capacity)"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix,
            "TargetGroup", var.target_group_arn_suffix, { stat = "Minimum" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Maximum", color = "#d62728" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "Saturation (CAUSE -- for diagnosis, not paging)"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name, { stat = "Average" }],
          ]
        }
      },
    ]
  })
}
