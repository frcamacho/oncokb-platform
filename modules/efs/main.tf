# EFS File System module for VEP caches
# Creates EFS with mount targets and access points

resource "aws_efs_file_system" "this" {
  creation_token = "${var.environment}-${var.filesystem_name}"
  encrypted      = var.encrypted

  lifecycle_policy {
    transition_to_ia = var.transition_to_ia
  }

  tags = {
    Name        = "${var.environment}-${var.filesystem_name}"
    Environment = var.environment
  }
}

# EFS Mount Targets in all private subnets
resource "aws_efs_mount_target" "this" {
  for_each = toset(var.subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = var.security_group_ids
}

# EFS Access Point for GRCh37 VEP cache
resource "aws_efs_access_point" "grch37" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = var.posix_gid
    uid = var.posix_uid
  }

  root_directory {
    path = "/grch37"
    creation_info {
      owner_gid   = var.posix_gid
      owner_uid   = var.posix_uid
      permissions = var.root_directory_permissions
    }
  }

  tags = {
    Name        = "${var.environment}-${var.filesystem_name}-grch37"
    Environment = var.environment
  }
}

# EFS Access Point for GRCh38 VEP cache
resource "aws_efs_access_point" "grch38" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = var.posix_gid
    uid = var.posix_uid
  }

  root_directory {
    path = "/grch38"
    creation_info {
      owner_gid   = var.posix_gid
      owner_uid   = var.posix_uid
      permissions = var.root_directory_permissions
    }
  }

  tags = {
    Name        = "${var.environment}-${var.filesystem_name}-grch38"
    Environment = var.environment
  }
}
