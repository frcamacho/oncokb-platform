output "ecs_log_group_name" {
  description = "CloudWatch log group name for ECS services"
  value       = aws_cloudwatch_log_group.ecs_services.name
}

output "ecs_log_group_arn" {
  description = "CloudWatch log group ARN for ECS services"
  value       = aws_cloudwatch_log_group.ecs_services.arn
}
