# CloudWatch Log Groups for OncoKB Platform

resource "aws_cloudwatch_log_group" "ecs_services" {
  name              = "/ecs/oncokb/${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "oncokb-${var.environment}-ecs-logs"
    Environment = var.environment
  }
}
