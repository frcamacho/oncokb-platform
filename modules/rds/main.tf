# RDS MySQL module for OncoKB
# Creates a MySQL 8.0 RDS instance with necessary subnet group and parameter group

resource "random_password" "master" {
  length  = 32
  special = false # Alphanumeric only to avoid shell escaping issues
}

# DB Subnet Group
resource "aws_db_subnet_group" "this" {
  name       = "${var.environment}-${var.db_identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.environment}-${var.db_identifier}-subnet-group"
    Environment = var.environment
  }
}

# Parameter Group
resource "aws_db_parameter_group" "this" {
  name   = "${var.environment}-${var.db_identifier}-mysql8"
  family = "mysql8.0"

  parameter {
    name  = "max_connections"
    value = "200"
  }

  parameter {
    name  = "innodb_buffer_pool_size"
    value = "{DBInstanceClassMemory*3/4}" # 75% of available memory
  }

  parameter {
    name         = "default_authentication_plugin"
    value        = "mysql_native_password"
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.environment}-${var.db_identifier}-mysql8-params"
    Environment = var.environment
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "this" {
  identifier     = "${var.environment}-${var.db_identifier}"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true # Required by organization SCP

  db_name  = var.db_name
  username = var.master_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false

  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  multi_az                = var.multi_az

  parameter_group_name = aws_db_parameter_group.this.name

  tags = {
    Name        = "${var.environment}-${var.db_identifier}-rds"
    Environment = var.environment
  }
}
