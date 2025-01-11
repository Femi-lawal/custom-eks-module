output "cluster_autoscaler_role_arn" {
  description = "The ARN of the cluster autoscaler IAM role"
  value       = aws_iam_role.cluster_autoscaler_role.arn
}

output "aws_region" {
  description = "The AWS region where the EKS cluster is deployed"
  value       = var.region
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = var.cluster_name
}
