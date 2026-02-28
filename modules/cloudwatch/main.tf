# CloudWatch Log Groups for OncoKB Platform

# ECS Service Logs
resource "aws_cloudwatch_log_group" "ecs_services" {
  name              = "/ecs/oncokb/${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "oncokb-${var.environment}-ecs-logs"
    Environment = var.environment
  }
}

# Docker Compose Logs (legacy)
resource "aws_cloudwatch_log_group" "docker_compose" {
  name              = "/oncokb/${var.environment}/docker-compose"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "oncokb-${var.environment}-docker-logs"
    Environment = var.environment
  }
}
