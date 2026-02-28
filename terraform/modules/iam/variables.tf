variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "deployment_bucket" {
  description = "S3 bucket for deployment artifacts"
  type        = string
}
