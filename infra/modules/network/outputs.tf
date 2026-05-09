output "vpc_id" {
  description = "The VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Primary public subnet ID (compatibility output)"
  value       = aws_subnet.public[0].id
}

output "vpc_cidr" {
  description = "The VPC CIDR range"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "The public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_id" {
  description = "The private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "backend_sg_id" {
  description = "The backend security group ID"
  value       = aws_security_group.backend_sg.id
}

output "vpc_flow_logs_log_group" {
  description = "The VPC flow logs CloudWatch log group name"
  value       = var.enable_vpc_flow_logs ? aws_cloudwatch_log_group.vpc_flow_logs[0].name : null
}