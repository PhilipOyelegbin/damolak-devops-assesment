variable "project_tag" {
  description = "The project tag, used for naming resources."
  type        = string
}

variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "project_environment" {
  description = "The environment for the project, used for naming resources."
  type        = string
}

variable "region" {
  description = "The region where resources will be created."
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "instance_type" {
  type        = string
  description = "The instance type for the server."
}

variable "alert_email" {
  description = "Optional email address for SNS alert subscription"
  type        = string
  default     = null
}

variable "enable_dashboard" {
  description = "Whether to create an operational CloudWatch dashboard"
  type        = bool
  default     = true
}

variable "dashboard_name" {
  description = "Optional custom dashboard name"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention for monitoring logs"
  type        = number
  default     = 30
}
