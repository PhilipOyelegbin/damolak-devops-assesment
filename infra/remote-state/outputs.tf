output "remote_state" {
  value       = aws_s3_bucket.s3.id
  description = "The S3 bucket for Terraform remote state storage"
}