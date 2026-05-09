terraform {
  required_version = ">=1.14.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.27.0"
    }
  }

  backend "s3" {
    bucket  = "damolak-assessment-remote-state"
    key     = "staging/terraform.tfstate"
    region  = "eu-west-2"
    encrypt = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_tag
      Environment = var.project_environment
    }
  }
}