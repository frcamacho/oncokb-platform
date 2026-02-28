variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "secret_name_prefix" {
  description = "Prefix for secret names (e.g., oncokb/dev)"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "Database host/endpoint"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 3306
}
