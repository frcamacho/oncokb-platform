variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EC2, RDS, EFS"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets required for high availability"
  }
}

variable "deployment_bucket" {
  description = "S3 bucket for deployment artifacts"
  type        = string
  default     = "oncokb-deployment-data-270327054051"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "270327054051"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 50
}

variable "rds_max_allocated_storage" {
  description = "RDS max allocated storage for autoscaling"
  type        = number
  default     = 100
}

variable "oncokb_version" {
  description = "OncoKB Docker image version"
  type        = string
  default     = "4.3.0"
}

variable "oncokb_transcript_version" {
  description = "OncoKB Transcript Docker image version"
  type        = string
  default     = "0.9.4"
}

# ── ECS Service Connect ───────────────────────────────────────────────────────

variable "service_connect_namespace_arn" {
  description = "ARN of existing AWS Cloud Map namespace for ECS Service Connect"
  type        = string
}

variable "service_connect_namespace_name" {
  description = "Name of existing AWS Cloud Map namespace for ECS Service Connect (e.g., cggt-dev.vrtx.com)"
  type        = string
}
