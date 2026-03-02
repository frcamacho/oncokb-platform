# ── ECS Cluster ───────────────────────────────────────────────────────────────
output "ecs_cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.oncokb.id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.oncokb.name
}

# ── Load Balancer ─────────────────────────────────────────────────────────────
output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "OncoKB API URL via ALB"
  value       = "http://${module.alb.alb_dns_name}/api/v1/info"
}

# ── RDS Database ──────────────────────────────────────────────────────────────
output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = module.rds.endpoint
}

output "rds_address" {
  description = "RDS MySQL address (without port)"
  value       = module.rds.address
}

output "rds_db_name" {
  description = "RDS database name"
  value       = module.rds.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = module.rds.username
}

# ── EFS File System ───────────────────────────────────────────────────────────
output "efs_id" {
  description = "EFS file system ID"
  value       = module.efs.filesystem_id
}

output "efs_dns_name" {
  description = "EFS DNS name for mounting"
  value       = module.efs.dns_name
}

output "efs_access_point_grch37_id" {
  description = "EFS access point ID for GRCh37"
  value       = module.efs.access_point_grch37_id
}

output "efs_access_point_grch38_id" {
  description = "EFS access point ID for GRCh38"
  value       = module.efs.access_point_grch38_id
}

# ── Secrets Manager ───────────────────────────────────────────────────────────
output "db_secret_arn" {
  description = "Database credentials secret ARN"
  value       = module.secrets.secret_arn
  sensitive   = true
}

output "db_secret_name" {
  description = "Database credentials secret name"
  value       = module.secrets.secret_name
}

# ── Network ───────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "VPC ID"
  value       = var.vpc_id
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = module.networking.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "ECS security group ID"
  value       = module.networking.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = module.networking.rds_security_group_id
}

output "efs_security_group_id" {
  description = "EFS security group ID"
  value       = module.networking.efs_security_group_id
}

# ── Service Discovery ─────────────────────────────────────────────────────────
output "service_discovery_namespace" {
  description = "Cloud Map namespace for service discovery"
  value       = module.service_discovery.namespace_name
}

# ── CloudWatch ────────────────────────────────────────────────────────────────
output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = module.cloudwatch.ecs_log_group_name
}

# ── ECR Repositories ──────────────────────────────────────────────────────────
output "ecr_repositories" {
  description = "ECR repository URLs"
  value = {
    gn_mongo_grch37   = module.ecr.gn_mongo_grch37_repository_url
    gn_mongo_grch38   = module.ecr.gn_mongo_grch38_repository_url
    genome_nexus_vep  = module.ecr.genome_nexus_vep_repository_url
    gn_spring_boot    = module.ecr.gn_spring_boot_repository_url
    oncokb_transcript = module.ecr.oncokb_transcript_repository_url
    oncokb            = module.ecr.oncokb_repository_url
  }
}
