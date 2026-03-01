# ECS Services
# All services default to desired_count=0 for on-demand use (Nextflow pipeline).
# Use start-services.sh / stop-services.sh to scale up/down.
# lifecycle ignore_changes prevents terraform apply from overriding the running count.

# MongoDB GRCh37 Service
resource "aws_ecs_service" "mongo_grch37" {
  cluster                = var.cluster_id
  desired_count          = 0
  enable_execute_command = true
  launch_type            = "FARGATE"
  name                   = "${var.environment}-mongo-grch37"
  task_definition        = aws_ecs_task_definition.mongo_grch37.arn
  propagate_tags         = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.ecs_security_group_id]
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace_arn

    service {
      discovery_name = "mongo-grch37"
      port_name      = "mongo-grch37"

      client_alias {
        dns_name = "mongo-grch37"
        port     = 27017
      }
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-mongo-grch37"
  }
}

# MongoDB GRCh38 Service
resource "aws_ecs_service" "mongo_grch38" {
  cluster                = var.cluster_id
  desired_count          = 0
  enable_execute_command = true
  launch_type            = "FARGATE"
  name                   = "${var.environment}-mongo-grch38"
  task_definition        = aws_ecs_task_definition.mongo_grch38.arn
  propagate_tags         = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.ecs_security_group_id]
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace_arn

    service {
      discovery_name = "mongo-grch38"
      port_name      = "mongo-grch38"

      client_alias {
        dns_name = "mongo-grch38"
        port     = 27017
      }
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-mongo-grch38"
  }
}

# VEP GRCh37 Service
resource "aws_ecs_service" "vep_grch37" {
  cluster                = var.cluster_id
  desired_count          = 0
  enable_execute_command = true
  launch_type            = "FARGATE"
  name                   = "${var.environment}-vep-grch37"
  task_definition        = aws_ecs_task_definition.vep_grch37.arn
  propagate_tags         = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.ecs_security_group_id]
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace_arn

    service {
      discovery_name = "vep-grch37"
      port_name      = "vep-grch37"

      client_alias {
        dns_name = "vep-grch37"
        port     = 6060
      }
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-vep-grch37"
  }
}

# VEP GRCh38 Service
resource "aws_ecs_service" "vep_grch38" {
  cluster                = var.cluster_id
  desired_count          = 0
  enable_execute_command = true
  launch_type            = "FARGATE"
  name                   = "${var.environment}-vep-grch38"
  task_definition        = aws_ecs_task_definition.vep_grch38.arn
  propagate_tags         = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.ecs_security_group_id]
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace_arn

    service {
      discovery_name = "vep-grch38"
      port_name      = "vep-grch38"

      client_alias {
        dns_name = "vep-grch38"
        port     = 6061
      }
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-vep-grch38"
  }
}

# Genome Nexus GRCh37 Service
resource "aws_ecs_service" "gn_grch37" {
  depends_on = [
    aws_ecs_service.mongo_grch37,
    aws_ecs_service.vep_grch37
  ]

  cluster                = var.cluster_id
  desired_count          = 0
  enable_execute_command = true
  launch_type            = "FARGATE"
  name                   = "${var.environment}-gn-grch37"
  task_definition        = aws_ecs_task_definition.gn_grch37.arn
  propagate_tags         = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.ecs_security_group_id]
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace_arn

    service {
      discovery_name = "gn-grch37"
      port_name      = "gn-grch37"

      client_alias {
        dns_name = "gn-grch37"
        port     = 8888
      }
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-gn-grch37"
  }
}

# Genome Nexus GRCh38 Service
resource "aws_ecs_service" "gn_grch38" {
  depends_on = [
    aws_ecs_service.mongo_grch38,
    aws_ecs_service.vep_grch38
  ]

  cluster                = var.cluster_id
  desired_count          = 0
  enable_execute_command = true
  launch_type            = "FARGATE"
  name                   = "${var.environment}-gn-grch38"
  task_definition        = aws_ecs_task_definition.gn_grch38.arn
  propagate_tags         = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.ecs_security_group_id]
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace_arn

    service {
      discovery_name = "gn-grch38"
      port_name      = "gn-grch38"

      client_alias {
        dns_name = "gn-grch38"
        port     = 8889
      }
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-gn-grch38"
  }
}

# OncoKB Transcript Service
resource "aws_ecs_service" "oncokb_transcript" {
  cluster                = var.cluster_id
  desired_count          = 0
  enable_execute_command = true
  launch_type            = "FARGATE"
  name                   = "${var.environment}-oncokb-transcript"
  task_definition        = aws_ecs_task_definition.oncokb_transcript.arn
  propagate_tags         = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.ecs_security_group_id]
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace_arn

    service {
      discovery_name = "oncokb-transcript"
      port_name      = "oncokb-transcript"

      client_alias {
        dns_name = "oncokb-transcript"
        port     = 9090
      }
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-oncokb-transcript"
  }
}

# OncoKB API Service
resource "aws_ecs_service" "oncokb" {
  depends_on = [
    aws_ecs_service.oncokb_transcript,
    aws_ecs_service.gn_grch37,
    aws_ecs_service.gn_grch38
  ]

  cluster                = var.cluster_id
  desired_count          = 0
  enable_execute_command = true
  launch_type            = "FARGATE"
  name                   = "${var.environment}-oncokb"
  task_definition        = aws_ecs_task_definition.oncokb.arn
  propagate_tags         = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  load_balancer {
    container_name   = "oncokb"
    container_port   = 8080
    target_group_arn = var.target_group_arn
  }

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.ecs_security_group_id]
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace_arn

    service {
      discovery_name = "oncokb"
      port_name      = "oncokb"

      client_alias {
        dns_name = "oncokb"
        port     = 8080
      }
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-oncokb"
  }
}
