# Observability module: alarms that are worth waking someone for, plus a
# dashboard that answers "are users having a bad time?" in five seconds.
#
# Design decision: these alarms are SYMPTOM-based, not cause-based. High CPU is
# not an incident. 5xx responses and p99 latency are. See _shared/breakfix BF-57.

locals {
  name = "${var.project}-${var.environment}"
}

resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
}

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
