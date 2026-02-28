variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "task_execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "efs_id" {
  description = "EFS file system ID for VEP cache"
  type        = string
}

variable "efs_access_point_grch37_id" {
  description = "EFS access point ID for GRCh37 VEP cache"
  type        = string
}

variable "efs_access_point_grch38_id" {
  description = "EFS access point ID for GRCh38 VEP cache"
  type        = string
}

variable "rds_secret_arn" {
  description = "Secrets Manager ARN for RDS credentials"
  type        = string
}

variable "service_connect_namespace_arn" {
  description = "Service Connect namespace ARN"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ALB target group ARN for OncoKB API"
  type        = string
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

# Docker image URIs (defaults to Docker Hub, can be overridden with ECR)
variable "gn_mongo_grch37_image" {
  description = "Docker image URI for Genome Nexus MongoDB GRCh37"
  type        = string
  default     = "genomenexus/gn-mongo:0.32"
}

variable "gn_mongo_grch38_image" {
  description = "Docker image URI for Genome Nexus MongoDB GRCh38"
  type        = string
  default     = "genomenexus/gn-mongo:0.32_grch38_ensembl95"
}

variable "genome_nexus_vep_image" {
  description = "Docker image URI for Genome Nexus VEP"
  type        = string
  default     = "genomenexus/genome-nexus-vep:v0.0.1"
}

variable "gn_spring_boot_image" {
  description = "Docker image URI for Genome Nexus Spring Boot"
  type        = string
  default     = "genomenexus/gn-spring-boot:2.0.2"
}

variable "oncokb_transcript_image" {
  description = "Docker image URI for OncoKB Transcript"
  type        = string
  default     = "mskcc/oncokb-transcript:0.9.4"
}

variable "oncokb_image" {
  description = "Docker image URI for OncoKB main application"
  type        = string
  default     = "mskcc/oncokb:4.3.0"
}
