variable "project_name" {
  description = "The name of the project, used for naming resources."
  type        = string
}

variable "environment" {
  description = "The environment for which to create resources."
  type        = string
}

variable "instance_type" {
  type        = string
  description = "The instance type for the server."
}

variable "subnet_id" {
  description = "The VPC public subnet id"
  type        = string
}

variable "backend_sg_id" {
  description = "Backend security group id"
  type        = string
  default     = null
}

variable "app_sg_id" {
  description = "Compatibility input for application security group id"
  type        = string
  default     = null
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "log_retention_days" {
  description = "CloudWatch log retention for EC2 host and app logs"
  type        = number
  default     = 30
}
