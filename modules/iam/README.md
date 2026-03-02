# IAM Module

Creates IAM roles for ECS Fargate tasks:

- **Task Execution Role**: Used by ECS agent to pull images, write logs, and read Secrets Manager secrets.
- **Task Role**: Used by application containers for CloudWatch log writing and EFS access.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `environment` | Environment name (dev, staging, prod) | `string` | — | yes |
| `aws_region` | AWS region | `string` | — | yes |
| `efs_filesystem_arn` | ARN of the EFS filesystem to grant task access to | `string` | — | yes |

## Outputs

| Name | Description |
|------|-------------|
| `task_execution_role_arn` | ARN of the ECS task execution role |
| `task_role_arn` | ARN of the ECS task role |
