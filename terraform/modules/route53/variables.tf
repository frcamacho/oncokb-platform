variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for private hosted zone"
  type        = string
}

variable "parent_domain_name" {
  description = "Parent domain name for the existing Route53 zone (e.g., cggt-dev.vrtx.com)"
  type        = string
}

variable "domain_name" {
  description = "Domain name for private hosted zone"
  type        = string
}

variable "create_alb_record" {
  description = "Whether to create ALB A record"
  type        = bool
  default     = true
}

variable "alb_dns_name" {
  description = "ALB DNS name for alias record"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "ALB hosted zone ID for alias record"
  type        = string
  default     = ""
}

variable "create_ec2_record" {
  description = "Whether to create EC2 A record (legacy)"
  type        = bool
  default     = false
}

variable "ec2_private_ip" {
  description = "EC2 private IP for A record (legacy)"
  type        = string
  default     = ""
}
