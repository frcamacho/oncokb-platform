# Service Discovery Module

Pass-through module that accepts an existing AWS Cloud Map namespace ARN and name for ECS Service Connect configuration. The namespace is created externally (e.g., by a shared infrastructure team).

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `service_connect_namespace_arn` | ARN of existing Cloud Map namespace | `string` | — | yes |
| `service_connect_namespace_name` | Name of existing Cloud Map namespace | `string` | — | yes |

## Outputs

| Name | Description |
|------|-------------|
| `namespace_arn` | Cloud Map namespace ARN |
| `namespace_name` | Cloud Map namespace name |
