variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "filesystem_name" {
  description = "Name for the EFS file system"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for EFS mount targets"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs to attach to EFS mount targets"
  type        = list(string)
}

variable "encrypted" {
  description = "Whether to encrypt the EFS file system at rest"
  type        = bool
  default     = true
}

variable "transition_to_ia" {
  description = "Transition to Infrequent Access storage class after N days"
  type        = string
  default     = "AFTER_30_DAYS"

  validation {
    condition     = contains(["AFTER_7_DAYS", "AFTER_14_DAYS", "AFTER_30_DAYS", "AFTER_60_DAYS", "AFTER_90_DAYS"], var.transition_to_ia)
    error_message = "Must be one of: AFTER_7_DAYS, AFTER_14_DAYS, AFTER_30_DAYS, AFTER_60_DAYS, AFTER_90_DAYS"
  }
}

variable "posix_uid" {
  description = "POSIX user ID for access point"
  type        = number
  default     = 1000
}

variable "posix_gid" {
  description = "POSIX group ID for access point"
  type        = number
  default     = 1000
}

variable "root_directory_path" {
  description = "Root directory path for access point"
  type        = string
  default     = "/"
}

variable "root_directory_permissions" {
  description = "Permissions for root directory"
  type        = string
  default     = "755"
}
