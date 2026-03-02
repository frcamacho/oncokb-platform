output "namespace_arn" {
  description = "Cloud Map namespace ARN for ECS Service Connect"
  value       = var.service_connect_namespace_arn
}

output "namespace_name" {
  description = "Cloud Map namespace name for ECS Service Connect"
  value       = var.service_connect_namespace_name
}
