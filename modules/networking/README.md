# Networking Module

Creates security groups for all OncoKB platform components. Follows least-privilege principles: RDS and EFS only accept traffic from ECS tasks and restrict egress to the ECS security group.

## Security Groups

| Security Group | Inbound | Outbound |
|---------------|---------|----------|
| ALB | HTTP/HTTPS from VPC CIDR | All |
| ECS | From ALB + inter-task (self) | All (image pulls, AWS APIs) |
| RDS | MySQL 3306 from ECS | ECS only |
| EFS | NFS 2049 from ECS | ECS only |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `environment` | Environment name (dev, staging, prod) | `string` | — | yes |
| `vpc_id` | VPC ID | `string` | — | yes |
| `vpc_cidr` | VPC CIDR block | `string` | — | yes |

## Outputs

| Name | Description |
|------|-------------|
| `alb_security_group_id` | Security group ID for ALB |
| `ecs_security_group_id` | Security group ID for ECS tasks |
| `rds_security_group_id` | Security group ID for RDS |
| `efs_security_group_id` | Security group ID for EFS |
