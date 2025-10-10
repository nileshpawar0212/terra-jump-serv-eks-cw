# SNS Topic for EKS Alerts
resource "aws_sns_topic" "eks_alerts" {
  name = "${var.cluster_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.eks_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_policy" "eks_alerts_policy" {
  arn = aws_sns_topic.eks_alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "cloudwatch.amazonaws.com" }
      Action = "sns:Publish"
      Resource = aws_sns_topic.eks_alerts.arn
    }]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cluster_failed_requests" {
  alarm_name          = "${var.cluster_name}-api-server-failed-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "cluster_failed_request_count"
  namespace           = "ContainerInsights"
  period              = 60
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "EKS API server failed requests"
  alarm_actions       = [aws_sns_topic.eks_alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }
}

resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${var.cluster_name}-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "EKS node CPU utilization high"
  alarm_actions       = [aws_sns_topic.eks_alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }
}

resource "aws_cloudwatch_metric_alarm" "node_memory_high" {
  alarm_name          = "${var.cluster_name}-node-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "EKS node memory utilization high"
  alarm_actions       = [aws_sns_topic.eks_alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }
}

resource "aws_cloudwatch_metric_alarm" "pod_restart_high" {
  alarm_name          = "${var.cluster_name}-pod-restarts-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "pod_number_of_container_restarts"
  namespace           = "ContainerInsights"
  period              = 60
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "High number of pod restarts"
  alarm_actions       = [aws_sns_topic.eks_alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }
}

resource "aws_cloudwatch_metric_alarm" "node_failure" {
  alarm_name          = "${var.cluster_name}-node-failure"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "cluster_node_count"
  namespace           = "ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = "2"
  alarm_description   = "EKS node failure detected"
  alarm_actions       = [aws_sns_topic.eks_alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }
}