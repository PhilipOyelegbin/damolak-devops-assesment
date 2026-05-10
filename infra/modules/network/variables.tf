variable "project_name" {
  description = "The name of the project, used for naming resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "staging"
}

variable "region" {
  type        = string
  description = "The region where resources will be created."
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC."
}

variable "enable_nat_high_availability" {
  description = "Enable NAT Gateway high availability, one per AZ"
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch"
  type        = bool
  default     = true
}

variable "vpc_flow_logs_retention_days" {
  description = "CloudWatch log retention period in days for VPC Flow Logs"
  type        = number
  default     = 30
}

variable "subnet_newbits" {
  description = "Number of additional prefix length bits to allocate for subnets (used by cidrsubnet)."
  type        = number
  default     = 4
}

