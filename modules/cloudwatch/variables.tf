variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14
}
