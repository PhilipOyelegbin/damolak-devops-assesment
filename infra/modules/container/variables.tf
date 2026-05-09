variable "project_name" {
  description = "The name of the project, used for naming resources."
  type        = string
}

variable "environment" {
  description = "The deployment environment name."
  type        = string
}

variable "repository_name" {
  description = "Optional custom ECR repository name."
  type        = string
  default     = null
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten after push."
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable basic vulnerability scanning when images are pushed."
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Allow deleting the repository even if it contains images."
  type        = bool
  default     = false
}
