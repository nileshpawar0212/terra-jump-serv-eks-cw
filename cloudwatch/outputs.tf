output "sns_topic_arn" {
  description = "ARN of the SNS topic for EKS alerts"
  value       = aws_sns_topic.eks_alerts.arn
}