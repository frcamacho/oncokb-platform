# EFS Module

Creates an encrypted EFS file system with mount targets in all provided subnets and 4 access points for VEP caches and MongoDB data persistence.

## Access Points

| Access Point | Path | Purpose |
|-------------|------|---------|
| `grch37` | `/grch37` | VEP 98 GRCh37 cache |
| `grch38` | `/grch38` | VEP 98 GRCh38 cache |
| `mongo-grch37` | `/mongo-grch37` | MongoDB GRCh37 data |
| `mongo-grch38` | `/mongo-grch38` | MongoDB GRCh38 data |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `environment` | Environment name | `string` | — | yes |
| `filesystem_name` | Name for the EFS file system | `string` | — | yes |
| `subnet_ids` | Private subnet IDs for mount targets | `list(string)` | — | yes |
| `security_group_ids` | Security group IDs for mount targets | `list(string)` | — | yes |
| `encrypted` | Encrypt the file system at rest | `bool` | `true` | no |
| `transition_to_ia` | Transition to IA storage class after N days | `string` | `"AFTER_30_DAYS"` | no |
| `posix_uid` | POSIX user ID for access points | `number` | `1000` | no |
| `posix_gid` | POSIX group ID for access points | `number` | `1000` | no |
| `root_directory_path` | Root directory path for access points | `string` | `"/"` | no |
| `root_directory_permissions` | Permissions for root directory | `string` | `"755"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `filesystem_id` | EFS file system ID |
| `filesystem_arn` | EFS file system ARN |
| `dns_name` | EFS DNS name for mounting |
| `access_point_grch37_id` | EFS access point ID for GRCh37 |
| `access_point_grch37_arn` | EFS access point ARN for GRCh37 |
| `access_point_grch38_id` | EFS access point ID for GRCh38 |
| `access_point_grch38_arn` | EFS access point ARN for GRCh38 |
| `access_point_mongo_grch37_id` | EFS access point ID for MongoDB GRCh37 |
| `access_point_mongo_grch38_id` | EFS access point ID for MongoDB GRCh38 |
