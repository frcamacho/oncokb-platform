variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "db_identifier" {
  description = "Database identifier (e.g., oncokb, vep)"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs to attach to the RDS instance"
  type        = list(string)
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 50
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Initial database name to create"
  type        = string
}

variable "master_username" {
  description = "Master database username"
  type        = string
  default     = "oncokb_admin"
}

variable "backup_retention_period" {
  description = "Number of days to retain backups (0 = disabled)"
  type        = number
  default     = 0
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot on deletion"
  type        = bool
  default     = true
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ deployment"
  type        = bool
  default     = false
}
