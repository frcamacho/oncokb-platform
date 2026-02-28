# ECS Services for OncoKB Platform
# 8 services: oncokb, oncokb-transcript, gn-grch37, gn-grch38, vep-grch37, vep-grch38, mongo-grch37, mongo-grch38

# MongoDB GRCh37 Task Definition
resource "aws_ecs_task_definition" "mongo_grch37" {
  family                   = "${var.environment}-oncokb-mongo-grch37"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      cpu       = 512
      essential = true
      image     = var.gn_mongo_grch37_image
      memory    = 1024
      name      = "mongo-grch37"

      healthCheck = {
        command     = ["CMD-SHELL", "mongosh --eval \"db.adminCommand('ping')\" || exit 1"]
        interval    = 30
        retries     = 3
        startPeriod = 30
        timeout     = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "mongo-grch37"
        }
      }

      portMappings = [
        {
          containerPort = 27017
          name          = "mongo-grch37"
          protocol      = "tcp"
        }
      ]
    }
  ])

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-oncokb-mongo-grch37"
  }
}

# MongoDB GRCh38 Task Definition
resource "aws_ecs_task_definition" "mongo_grch38" {
  family                   = "${var.environment}-oncokb-mongo-grch38"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      cpu       = 512
      essential = true
      image     = var.gn_mongo_grch38_image
      memory    = 1024
      name      = "mongo-grch38"

      healthCheck = {
        command     = ["CMD-SHELL", "mongosh --eval \"db.adminCommand('ping')\" || exit 1"]
        interval    = 30
        retries     = 3
        startPeriod = 30
        timeout     = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "mongo-grch38"
        }
      }

      portMappings = [
        {
          containerPort = 27017
          name          = "mongo-grch38"
          protocol      = "tcp"
        }
      ]
    }
  ])

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-oncokb-mongo-grch38"
  }
}

# VEP GRCh37 Task Definition
resource "aws_ecs_task_definition" "vep_grch37" {
  family                   = "${var.environment}-oncokb-vep-grch37"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "4096"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      cpu       = 1024
      essential = true
      image     = var.genome_nexus_vep_image
      memory    = 4096
      name      = "vep-grch37"

      environment = [
        {
          name  = "SERVER_PORT"
          value = "6060"
        },
        {
          name  = "VEP_ASSEMBLY"
          value = "GRCh37"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:6060/vep/human/region/7:140453136-140453136:1/T || exit 1"]
        interval    = 30
        retries     = 3
        startPeriod = 60
        timeout     = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "vep-grch37"
        }
      }

      mountPoints = [
        {
          containerPath = "/opt/vep/.vep"
          readOnly      = true
          sourceVolume  = "vep-cache-grch37"
        }
      ]

      portMappings = [
        {
          containerPort = 6060
          name          = "vep-grch37"
          protocol      = "tcp"
        }
      ]
    }
  ])

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  volume {
    name = "vep-cache-grch37"

    efs_volume_configuration {
      file_system_id = var.efs_id
      authorization_config {
        access_point_id = var.efs_access_point_grch37_id
        iam             = "DISABLED"
      }
      transit_encryption = "ENABLED"
    }
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-oncokb-vep-grch37"
  }
}

# VEP GRCh38 Task Definition
resource "aws_ecs_task_definition" "vep_grch38" {
  family                   = "${var.environment}-oncokb-vep-grch38"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "4096"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      cpu       = 1024
      essential = true
      image     = var.genome_nexus_vep_image
      memory    = 4096
      name      = "vep-grch38"

      environment = [
        {
          name  = "SERVER_PORT"
          value = "6061"
        },
        {
          name  = "VEP_ASSEMBLY"
          value = "GRCh38"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:6061/vep/human/region/7:140753336-140753336:1/T || exit 1"]
        interval    = 30
        retries     = 3
        startPeriod = 60
        timeout     = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "vep-grch38"
        }
      }

      mountPoints = [
        {
          containerPath = "/opt/vep/.vep"
          readOnly      = true
          sourceVolume  = "vep-cache-grch38"
        }
      ]

      portMappings = [
        {
          containerPort = 6061
          name          = "vep-grch38"
          protocol      = "tcp"
        }
      ]
    }
  ])

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  volume {
    name = "vep-cache-grch38"

    efs_volume_configuration {
      file_system_id = var.efs_id
      authorization_config {
        access_point_id = var.efs_access_point_grch38_id
        iam             = "DISABLED"
      }
      transit_encryption = "ENABLED"
    }
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-oncokb-vep-grch38"
  }
}

# Genome Nexus GRCh37 Task Definition
resource "aws_ecs_task_definition" "gn_grch37" {
  depends_on = [
    aws_ecs_service.mongo_grch37,
    aws_ecs_service.vep_grch37
  ]

  family                   = "${var.environment}-oncokb-gn-grch37"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "2048"
  memory                   = "8192"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      cpu       = 2048
      essential = true
      image     = var.gn_spring_boot_image
      memory    = 8192
      name      = "gn-grch37"

      environment = [
        {
          name  = "GENOME_VERSION"
          value = "grch37"
        },
        {
          name  = "MONGODB_URI"
          value = "mongodb://mongo-grch37:27017/annotator"
        },
        {
          name  = "SERVER_PORT"
          value = "8888"
        },
        {
          name  = "VEP_URL"
          value = "http://vep-grch37:6060/vep/human/hgvs"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8888/health || exit 1"]
        interval    = 30
        retries     = 3
        startPeriod = 90
        timeout     = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "gn-grch37"
        }
      }

      portMappings = [
        {
          containerPort = 8888
          name          = "gn-grch37"
          protocol      = "tcp"
        }
      ]
    }
  ])

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-oncokb-gn-grch37"
  }
}

# Genome Nexus GRCh38 Task Definition
resource "aws_ecs_task_definition" "gn_grch38" {
  depends_on = [
    aws_ecs_service.mongo_grch38,
    aws_ecs_service.vep_grch38
  ]

  family                   = "${var.environment}-oncokb-gn-grch38"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "2048"
  memory                   = "8192"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      cpu       = 2048
      essential = true
      image     = var.gn_spring_boot_image
      memory    = 8192
      name      = "gn-grch38"

      environment = [
        {
          name  = "GENOME_VERSION"
          value = "grch38"
        },
        {
          name  = "MONGODB_URI"
          value = "mongodb://mongo-grch38:27017/annotator"
        },
        {
          name  = "SERVER_PORT"
          value = "8889"
        },
        {
          name  = "VEP_URL"
          value = "http://vep-grch38:6061/vep/human/hgvs"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8889/health || exit 1"]
        interval    = 30
        retries     = 3
        startPeriod = 90
        timeout     = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "gn-grch38"
        }
      }

      portMappings = [
        {
          containerPort = 8889
          name          = "gn-grch38"
          protocol      = "tcp"
        }
      ]
    }
  ])

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-oncokb-gn-grch38"
  }
}

# OncoKB Transcript Task Definition
resource "aws_ecs_task_definition" "oncokb_transcript" {
  family                   = "${var.environment}-oncokb-transcript"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "4096"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      cpu       = 1024
      essential = true
      image     = var.oncokb_transcript_image
      memory    = 4096
      name      = "oncokb-transcript"

      secrets = [
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = "${var.rds_secret_arn}:password::"
        },
        {
          name      = "SPRING_DATASOURCE_URL"
          valueFrom = "${var.rds_secret_arn}:jdbc_url_transcript::"
        },
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = "${var.rds_secret_arn}:username::"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:9090/actuator/health || exit 1"]
        interval    = 30
        retries     = 3
        startPeriod = 60
        timeout     = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "oncokb-transcript"
        }
      }

      portMappings = [
        {
          containerPort = 9090
          name          = "oncokb-transcript"
          protocol      = "tcp"
        }
      ]
    }
  ])

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-oncokb-transcript"
  }
}

# OncoKB API Task Definition
resource "aws_ecs_task_definition" "oncokb" {
  depends_on = [
    aws_ecs_service.oncokb_transcript,
    aws_ecs_service.gn_grch37,
    aws_ecs_service.gn_grch38
  ]

  family                   = "${var.environment}-oncokb"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "2048"
  memory                   = "8192"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      cpu       = 2048
      essential = true
      image     = var.oncokb_image
      memory    = 8192
      name      = "oncokb"

      environment = [
        {
          name  = "GENOME_NEXUS_GRCH37_URL"
          value = "http://gn-grch37:8888"
        },
        {
          name  = "GENOME_NEXUS_GRCH38_URL"
          value = "http://gn-grch38:8889"
        }
      ]

      secrets = [
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = "${var.rds_secret_arn}:password::"
        },
        {
          name      = "SPRING_DATASOURCE_URL"
          valueFrom = "${var.rds_secret_arn}:jdbc_url::"
        },
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = "${var.rds_secret_arn}:username::"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/api/v1/info || exit 1"]
        interval    = 30
        retries     = 3
        startPeriod = 120
        timeout     = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "oncokb"
        }
      }

      portMappings = [
        {
          containerPort = 8080
          name          = "oncokb"
          protocol      = "tcp"
        }
      ]
    }
  ])

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-oncokb"
  }
}
