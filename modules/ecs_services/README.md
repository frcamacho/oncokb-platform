# ECS Services Module

Deploys 8 Fargate services for the OncoKB platform with Service Connect for inter-service discovery. All services default to `desired_count = 0` for on-demand usage. Use `start-services.sh` / `stop-services.sh` to scale up and down.

## Services

| Service | Port | Dependencies |
|---------|------|-------------|
| `mongo-grch37` | 27017 | — |
| `mongo-grch38` | 27017 | — |
| `vep-grch37` | 6060 | — |
| `vep-grch38` | 6061 | — |
| `gn-grch37` | 8888 | mongo-grch37, vep-grch37 |
| `gn-grch38` | 8889 | mongo-grch38, vep-grch38 |
| `oncokb-transcript` | 9090 | — |
| `oncokb` | 8080 | oncokb-transcript, gn-grch37, gn-grch38 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `environment` | Environment name | `string` | — | yes |
| `aws_region` | AWS region | `string` | — | yes |
| `cluster_id` | ECS cluster ID | `string` | — | yes |
| `cluster_name` | ECS cluster name | `string` | — | yes |
| `task_execution_role_arn` | ECS task execution role ARN | `string` | — | yes |
| `task_role_arn` | ECS task role ARN | `string` | — | yes |
| `log_group_name` | CloudWatch log group name | `string` | — | yes |
| `efs_id` | EFS file system ID for VEP cache | `string` | — | yes |
| `efs_access_point_grch37_id` | EFS access point ID for GRCh37 VEP cache | `string` | — | yes |
| `efs_access_point_grch38_id` | EFS access point ID for GRCh38 VEP cache | `string` | — | yes |
| `efs_access_point_mongo_grch37_id` | EFS access point ID for MongoDB GRCh37 | `string` | — | yes |
| `efs_access_point_mongo_grch38_id` | EFS access point ID for MongoDB GRCh38 | `string` | — | yes |
| `rds_secret_arn` | Secrets Manager ARN for RDS credentials | `string` | — | yes |
| `service_connect_namespace_arn` | Service Connect namespace ARN | `string` | — | yes |
| `subnet_ids` | List of subnet IDs for ECS tasks | `list(string)` | — | yes |
| `target_group_arn` | ALB target group ARN for OncoKB API | `string` | — | yes |
| `ecs_security_group_id` | Security group ID for ECS tasks | `string` | — | yes |
| `gn_mongo_grch37_image` | Docker image URI for GN MongoDB GRCh37 | `string` | `genomenexus/gn-mongo:0.32` | no |
| `gn_mongo_grch38_image` | Docker image URI for GN MongoDB GRCh38 | `string` | `genomenexus/gn-mongo:0.32_grch38_ensembl95` | no |
| `genome_nexus_vep_image` | Docker image URI for GN VEP | `string` | `genomenexus/genome-nexus-vep:v0.0.1` | no |
| `gn_spring_boot_image` | Docker image URI for GN Spring Boot | `string` | `genomenexus/gn-spring-boot:2.0.2` | no |
| `oncokb_transcript_image` | Docker image URI for OncoKB Transcript | `string` | `mskcc/oncokb-transcript:0.9.4` | no |
| `oncokb_image` | Docker image URI for OncoKB | `string` | `mskcc/oncokb:4.3.0` | no |
| `transcript_jwt_base64_secret_arn` | Secrets Manager ARN for JWT base64 secret | `string` | `""` | no |
| `transcript_jwt_token_arn` | Secrets Manager ARN for JWT token | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| `oncokb_service_id` | OncoKB ECS service ID |
| `oncokb_service_name` | OncoKB ECS service name |
| `oncokb_transcript_service_id` | OncoKB Transcript ECS service ID |
| `gn_grch37_service_id` | Genome Nexus GRCh37 ECS service ID |
| `gn_grch38_service_id` | Genome Nexus GRCh38 ECS service ID |
| `vep_grch37_service_id` | VEP GRCh37 ECS service ID |
| `vep_grch38_service_id` | VEP GRCh38 ECS service ID |
| `mongo_grch37_service_id` | MongoDB GRCh37 ECS service ID |
| `mongo_grch38_service_id` | MongoDB GRCh38 ECS service ID |
