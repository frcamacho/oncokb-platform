variable "service_connect_namespace_arn" {
  description = "ARN of existing AWS Cloud Map namespace for ECS Service Connect"
  type        = string
}

variable "service_connect_namespace_name" {
  description = "Name of existing AWS Cloud Map namespace for ECS Service Connect (e.g., cggt-dev.vrtx.com)"
  type        = string
}
