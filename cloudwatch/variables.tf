variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "notification_email" {
  description = "Email address for SNS notifications"
  type        = string
}