output "ecs_log_group_name" {
  description = "CloudWatch log group name for ECS services"
  value       = aws_cloudwatch_log_group.ecs_services.name
}

output "ecs_log_group_arn" {
  description = "CloudWatch log group ARN for ECS services"
  value       = aws_cloudwatch_log_group.ecs_services.arn
}

output "docker_compose_log_group_name" {
  description = "CloudWatch log group name for Docker Compose (legacy)"
  value       = aws_cloudwatch_log_group.docker_compose.name
}

output "docker_compose_log_group_arn" {
  description = "CloudWatch log group ARN for Docker Compose (legacy)"
  value       = aws_cloudwatch_log_group.docker_compose.arn
}
