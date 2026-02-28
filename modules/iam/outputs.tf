# EC2 instance profile outputs commented out (using Fargate)
# output "ecs_instance_profile_name" {
#   description = "Name of the IAM instance profile for EC2 ECS instances"
#   value       = aws_iam_instance_profile.ecs_instance.name
# }
#
# output "ecs_instance_role_arn" {
#   description = "ARN of the EC2 ECS instance IAM role"
#   value       = aws_iam_role.ecs_instance.arn
# }

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.task.arn
}
