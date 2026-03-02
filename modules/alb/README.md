# ALB Module

Internal Application Load Balancer that exposes the OncoKB API on port 8080. Supports optional HTTPS via ACM certificate.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `environment` | Environment name (dev, staging, prod) | `string` | — | yes |
| `vpc_id` | VPC ID | `string` | — | yes |
| `private_subnet_ids` | List of private subnet IDs for ALB | `list(string)` | — | yes |
| `alb_security_group_id` | Security group ID for ALB | `string` | — | yes |
| `certificate_arn` | ACM certificate ARN for HTTPS listener. Leave empty for HTTP only. | `string` | `""` | no |
| `enable_deletion_protection` | Enable ALB deletion protection (recommended for prod) | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| `alb_arn` | ALB ARN |
| `alb_dns_name` | ALB DNS name |
| `alb_zone_id` | ALB hosted zone ID |
| `target_group_arn` | OncoKB target group ARN |
| `listener_arn` | HTTP listener ARN |
