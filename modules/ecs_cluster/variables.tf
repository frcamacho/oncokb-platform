variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EC2 instances"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS instances"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  type        = string
}

variable "instance_type_x86" {
  description = "EC2 instance type for x86_64 instances"
  type        = string
  default     = "r6i.xlarge"
}

variable "instance_type_arm" {
  description = "EC2 instance type for ARM64 instances"
  type        = string
  default     = "r7g.xlarge"
}

variable "asg_x86_min_size" {
  description = "Minimum number of x86 instances"
  type        = number
  default     = 2
}

variable "asg_x86_max_size" {
  description = "Maximum number of x86 instances"
  type        = number
  default     = 4
}

variable "asg_x86_desired_capacity" {
  description = "Desired number of x86 instances"
  type        = number
  default     = 2
}

variable "asg_arm_min_size" {
  description = "Minimum number of ARM instances"
  type        = number
  default     = 1
}

variable "asg_arm_max_size" {
  description = "Maximum number of ARM instances"
  type        = number
  default     = 2
}

variable "asg_arm_desired_capacity" {
  description = "Desired number of ARM instances"
  type        = number
  default     = 1
}
