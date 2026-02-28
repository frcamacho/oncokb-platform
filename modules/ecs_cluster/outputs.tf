output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.this.arn
}

output "capacity_provider_x86_name" {
  description = "Name of the x86_64 capacity provider"
  value       = aws_ecs_capacity_provider.x86.name
}

output "capacity_provider_arm_name" {
  description = "Name of the ARM64 capacity provider"
  value       = aws_ecs_capacity_provider.arm.name
}

output "asg_x86_name" {
  description = "Auto Scaling Group name for x86 instances"
  value       = aws_autoscaling_group.ecs_x86.name
}

output "asg_arm_name" {
  description = "Auto Scaling Group name for ARM instances"
  value       = aws_autoscaling_group.ecs_arm.name
}
