#============================================
# Monitoring Resources
#============================================

locals {
  resolved_dashboard_name = var.dashboard_name != null ? var.dashboard_name : "${var.project_name}-operations-dashboard"

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }

  instance_id_map = {
    for index, instance_id in var.instance_ids : tostring(index) => instance_id
  }

  alarm_actions = concat([aws_sns_topic.alerts.arn], var.additional_alarm_actions)
}

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-alerts"
  })
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != null ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_log_group" "monitoring" {
  name              = "/${var.project_name}-${var.environment}/monitoring"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-monitoring-logs"
  })
}

resource "aws_cloudwatch_dashboard" "operations" {
  count          = var.enable_dashboard ? 1 : 0
  dashboard_name = local.resolved_dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "## ${var.project_name} Backend Monitoring Dashboard\\nPrimary alerts are delivered via SNS topic: `${aws_sns_topic.alerts.arn}`"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title   = "Backend EC2 CPU Utilization"
          view    = "timeSeries"
          stacked = false
          region  = var.region
          stat    = "Average"
          period  = 300
          metrics = [
            [{
              expression = "SEARCH('{AWS/EC2,InstanceId} MetricName=\"CPUUtilization\"', 'Average', 300)"
              label      = "EC2 CPU"
              id         = "e1"
            }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title   = "Backend EC2 Network In"
          view    = "timeSeries"
          stacked = false
          region  = var.region
          stat    = "Average"
          period  = 300
          metrics = [
            [{
              expression = "SEARCH('{AWS/EC2,InstanceId} MetricName=\"NetworkIn\"', 'Average', 300)"
              label      = "EC2 Network In"
              id         = "e1"
            }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 24
        height = 6
        properties = {
          title   = "Backend EC2 Status Check Failures"
          view    = "timeSeries"
          stacked = false
          region  = var.region
          stat    = "Maximum"
          period  = 60
          metrics = [
            [{
              expression = "SEARCH('{AWS/EC2,InstanceId} MetricName=\"StatusCheckFailed\"', 'Maximum', 60)"
              label      = "EC2 StatusCheckFailed"
              id         = "e1"
            }]
          ]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  for_each = local.instance_id_map

  alarm_name          = "${var.project_name}-ec2-cpu-high-${each.value}"
  alarm_description   = "EC2 CPU utilization is above threshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = var.alarm_evaluation_periods
  threshold           = var.ec2_cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  dimensions = {
    InstanceId = each.value
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  for_each = local.instance_id_map

  alarm_name          = "${var.project_name}-ec2-status-check-${each.value}"
  alarm_description   = "EC2 instance status check has failed"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  dimensions = {
    InstanceId = each.value
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}
