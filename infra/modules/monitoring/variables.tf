variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr_blocks" {
  description = "VPC CIDR blocks for internal communication"
  type        = list(string)
}

variable "application_sg_ids" {
  description = "Deprecated compatibility variable for backend security group IDs"
  type        = list(string)
  default     = []
}

variable "backend_sg_ids" {
  description = "Backend security group IDs"
  type        = list(string)
  default     = []
}

variable "alert_email" {
  description = "Optional email address for SNS alert subscription"
  type        = string
  default     = null
}

variable "instance_ids" {
  description = "Optional EC2 instance IDs for instance-level alarms"
  type        = list(string)
  default     = []
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

variable "alarm_evaluation_periods" {
  description = "Number of periods over which data is compared to threshold"
  type        = number
  default     = 2
}

variable "ec2_cpu_threshold" {
  description = "CPU utilization threshold percentage for EC2 alarms"
  type        = number
  default     = 80
}

variable "additional_alarm_actions" {
  description = "Additional SNS topic ARNs or automation action ARNs for alarms"
  type        = list(string)
  default     = []
}
