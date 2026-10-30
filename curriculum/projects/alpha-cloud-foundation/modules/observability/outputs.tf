# Consumed by anything that should also hear the alarms later: a pager, a chat webhook, a Lambda.
output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

# Consumed by the learner and the README: the five-second answer to "are users having a bad time".
output "dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.this.dashboard_name}"
}

# Consumed by the week 13 acceptance test: force each alarm into ALARM and prove the email arrives.
# compact() drops the empty string the try() returns when the database alarm does not exist.
output "alarm_names" {
  description = "Force one of these with: aws cloudwatch set-alarm-state --alarm-name X --state-value ALARM --state-reason test"
  value = compact([
    aws_cloudwatch_metric_alarm.target_5xx.alarm_name,
    aws_cloudwatch_metric_alarm.no_healthy_hosts.alarm_name,
    aws_cloudwatch_metric_alarm.latency_p99.alarm_name,
    try(aws_cloudwatch_metric_alarm.db_storage[0].alarm_name, ""),
  ])
}
