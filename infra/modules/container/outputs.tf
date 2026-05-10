output "repository_name" {
  description = "The ECR repository name."
  value       = aws_ecr_repository.backend.name
}

output "repository_url" {
  description = "The ECR repository URL."
  value       = aws_ecr_repository.backend.repository_url
}

output "repository_arn" {
  description = "The ECR repository ARN."
  value       = aws_ecr_repository.backend.arn
}
