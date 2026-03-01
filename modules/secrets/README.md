# Secrets Module

Stores RDS database credentials in AWS Secrets Manager with pre-built JDBC URLs for OncoKB and OncoKB Transcript services. JDBC connections use SSL encryption.

## Secret Structure

The secret contains these keys:

| Key | Description |
|-----|-------------|
| `engine` | `mysql` |
| `host` | RDS endpoint hostname |
| `port` | RDS port |
| `username` | Master database username |
| `password` | Master database password |
| `jdbc_url` | JDBC URL for `oncokb` database (SSL enabled) |
| `jdbc_url_transcript` | JDBC URL for `oncokb_transcript` database (SSL enabled) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `environment` | Environment name | `string` | — | yes |
| `secret_name_prefix` | Prefix for secret names (e.g., `oncokb/dev`) | `string` | — | yes |
| `db_username` | Database username | `string` | — | yes |
| `db_password` | Database password | `string` | — | yes |
| `db_host` | Database host/endpoint | `string` | — | yes |
| `db_port` | Database port | `number` | `3306` | no |

## Outputs

| Name | Description |
|------|-------------|
| `secret_arn` | ARN of the Secrets Manager secret |
| `secret_id` | ID of the Secrets Manager secret |
| `secret_name` | Name of the Secrets Manager secret |
