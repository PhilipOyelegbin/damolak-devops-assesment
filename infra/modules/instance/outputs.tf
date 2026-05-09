output "server_ip" {
  description = "Server public IP"
  value       = aws_instance.app_server.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app_server.id
}