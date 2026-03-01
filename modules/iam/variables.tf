variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "efs_filesystem_arn" {
  description = "ARN of the EFS filesystem to grant task access to"
  type        = string
}
