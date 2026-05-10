output "output_details" {
  description = "Details of monitoring resources created."
  value = {
    sns_topic_arn                     = aws_sns_topic.alerts.arn
    backend_monitoring_log_group_name = aws_cloudwatch_log_group.monitoring.name
    dashboard_name                    = var.enable_dashboard ? aws_cloudwatch_dashboard.operations[0].dashboard_name : null
    backend_ec2_cpu_alarm_names       = values(aws_cloudwatch_metric_alarm.ec2_cpu_high)[*].alarm_name
    backend_ec2_status_alarm_names    = values(aws_cloudwatch_metric_alarm.ec2_status_check_failed)[*].alarm_name
  }
}
