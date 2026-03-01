# CloudWatch Module

Creates CloudWatch log groups for ECS services under `/ecs/oncokb/{environment}`.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `environment` | Environment name (dev, staging, prod) | `string` | — | yes |
| `log_retention_days` | Number of days to retain CloudWatch logs | `number` | `14` | no |

## Outputs

| Name | Description |
|------|-------------|
| `ecs_log_group_name` | CloudWatch log group name for ECS services |
| `ecs_log_group_arn` | CloudWatch log group ARN for ECS services |
