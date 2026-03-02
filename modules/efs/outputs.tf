output "filesystem_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.this.id
}

output "filesystem_arn" {
  description = "EFS file system ARN"
  value       = aws_efs_file_system.this.arn
}

output "access_point_grch37_id" {
  description = "EFS access point ID for GRCh37"
  value       = aws_efs_access_point.grch37.id
}

output "access_point_grch37_arn" {
  description = "EFS access point ARN for GRCh37"
  value       = aws_efs_access_point.grch37.arn
}

output "access_point_grch38_id" {
  description = "EFS access point ID for GRCh38"
  value       = aws_efs_access_point.grch38.id
}

output "access_point_grch38_arn" {
  description = "EFS access point ARN for GRCh38"
  value       = aws_efs_access_point.grch38.arn
}

output "dns_name" {
  description = "EFS DNS name for mounting"
  value       = aws_efs_file_system.this.dns_name
}

output "access_point_mongo_grch37_id" {
  description = "EFS access point ID for MongoDB GRCh37"
  value       = aws_efs_access_point.mongo_grch37.id
}

output "access_point_mongo_grch38_id" {
  description = "EFS access point ID for MongoDB GRCh38"
  value       = aws_efs_access_point.mongo_grch38.id
}
