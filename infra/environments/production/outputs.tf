output "server_ip" {
  description = "Public IP of the app server instance"
  value       = module.instance.server_ip
}

output "instance_id" {
  description = "EC2 instance ID of the app server"
  value       = module.instance.instance_id
}

output "ecr_repository_name" {
  description = "ECR repository name for the backend API"
  value       = module.container.repository_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for the backend API"
  value       = module.container.repository_url
}

output "cloudwatch_name" {
  description = "Cloudwatch dsahboard name"
  value       = module.monitoring.output_details.dashboard_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring.output_details.sns_topic_arn
}
