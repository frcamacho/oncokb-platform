# Secrets Manager module for OncoKB
# Stores database credentials and other sensitive values in AWS Secrets Manager

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.secret_name_prefix}/db-credentials"
  description             = "RDS MySQL credentials for OncoKB"
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.secret_name_prefix}-db-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    engine              = "mysql"
    host                = var.db_host
    jdbc_url            = "jdbc:mysql://${var.db_host}:${var.db_port}/oncokb?useUnicode=yes&characterEncoding=UTF-8&useSSL=false"
    jdbc_url_transcript = "jdbc:mysql://${var.db_host}:${var.db_port}/oncokb_transcript?useUnicode=yes&characterEncoding=UTF-8&useSSL=false"
    password            = var.db_password
    port                = var.db_port
    username            = var.db_username
  })
}