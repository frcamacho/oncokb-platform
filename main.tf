terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "oncokb"
      CostCenter  = "GDI-OncoKB"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# IAM Roles for ECS
module "iam" {
  source = "./modules/iam"

  environment        = var.environment
  aws_region         = var.aws_region
  efs_filesystem_arn = module.efs.filesystem_arn
}

# Security Groups
module "networking" {
  source = "./modules/networking"

  environment = var.environment
  vpc_id      = var.vpc_id
  vpc_cidr    = var.vpc_cidr
}

# Service Discovery (ECS Service Connect with existing Cloud Map namespace)
module "service_discovery" {
  source = "./modules/service_discovery"

  service_connect_namespace_arn  = var.service_connect_namespace_arn
  service_connect_namespace_name = var.service_connect_namespace_name
}

# ECS Cluster for Fargate
resource "aws_ecs_cluster" "oncokb" {
  name = "${var.environment}-oncokb-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.environment}-oncokb-cluster"
    Environment = var.environment
  }
}

# Application Load Balancer
module "alb" {
  source = "./modules/alb"

  environment                = var.environment
  vpc_id                     = var.vpc_id
  private_subnet_ids         = var.private_subnet_ids
  alb_security_group_id      = module.networking.alb_security_group_id
  certificate_arn            = var.certificate_arn
  enable_deletion_protection = var.environment == "prod"
}

# RDS MySQL Database
module "rds" {
  source = "./modules/rds"

  environment           = var.environment
  db_identifier         = "oncokb"
  subnet_ids            = var.private_subnet_ids
  security_group_ids    = [module.networking.rds_security_group_id]
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  db_name               = "oncokb"
  master_username       = "oncokb_admin"

  backup_retention_period = 0
  skip_final_snapshot     = true
  multi_az                = false
}

# EFS for VEP Cache
module "efs" {
  source = "./modules/efs"

  environment                = var.environment
  filesystem_name            = "oncokb-vep-cache"
  subnet_ids                 = var.private_subnet_ids
  security_group_ids         = [module.networking.efs_security_group_id]
  encrypted                  = true
  transition_to_ia           = "AFTER_30_DAYS"
  posix_uid                  = 1000
  posix_gid                  = 1000
  root_directory_path        = "/"
  root_directory_permissions = "755"
}

# Secrets Manager for Database Credentials
module "secrets" {
  source = "./modules/secrets"

  environment        = var.environment
  secret_name_prefix = "oncokb/${var.environment}"
  db_username        = module.rds.username
  db_password        = module.rds.master_password
  db_host            = module.rds.address
  db_port            = module.rds.port
}

# CloudWatch Log Groups
module "cloudwatch" {
  source = "./modules/cloudwatch"

  environment        = var.environment
  log_retention_days = 14
}

# ECR Repositories (to avoid Docker Hub rate limiting)
module "ecr" {
  source = "./modules/ecr"

  environment = var.environment
  aws_region  = var.aws_region
}

# ECS Services (8 services: oncokb, oncokb-transcript, gn-grch37, gn-grch38, vep-grch37, vep-grch38, mongo-grch37, mongo-grch38)
module "ecs_services" {
  source = "./modules/ecs_services"

  environment                   = var.environment
  aws_region                    = var.aws_region
  cluster_id                    = aws_ecs_cluster.oncokb.id
  cluster_name                  = aws_ecs_cluster.oncokb.name
  task_execution_role_arn       = module.iam.task_execution_role_arn
  task_role_arn                 = module.iam.task_role_arn
  log_group_name                = module.cloudwatch.ecs_log_group_name
  efs_id                          = module.efs.filesystem_id
  efs_access_point_grch37_id      = module.efs.access_point_grch37_id
  efs_access_point_grch38_id     = module.efs.access_point_grch38_id
  efs_access_point_mongo_grch37_id  = module.efs.access_point_mongo_grch37_id
  efs_access_point_mongo_grch38_id  = module.efs.access_point_mongo_grch38_id
  rds_secret_arn                = module.secrets.secret_arn
  service_connect_namespace_arn = module.service_discovery.namespace_arn
  target_group_arn              = module.alb.target_group_arn
  subnet_ids                    = var.private_subnet_ids
  ecs_security_group_id         = module.networking.ecs_security_group_id

  # ECR images with version tags from variables (override per-env in .tfvars)
  gn_mongo_grch37_image   = "${module.ecr.gn_mongo_grch37_repository_url}:${var.gn_mongo_grch37_version}"
  gn_mongo_grch38_image   = "${module.ecr.gn_mongo_grch38_repository_url}:${var.gn_mongo_grch38_version}"
  genome_nexus_vep_image  = "${module.ecr.genome_nexus_vep_repository_url}:${var.genome_nexus_vep_version}"
  gn_spring_boot_image    = "${module.ecr.gn_spring_boot_repository_url}:${var.gn_spring_boot_version}"
  oncokb_transcript_image = "${module.ecr.oncokb_transcript_repository_url}:${var.oncokb_transcript_version}"
  oncokb_image            = "${module.ecr.oncokb_repository_url}:${var.oncokb_version}"

  transcript_jwt_base64_secret_arn = var.transcript_jwt_base64_secret_arn
  transcript_jwt_token_arn         = var.transcript_jwt_token_arn
}
