# ECS Services for OncoKB Platform
# 8 services: oncokb, oncokb-transcript, gn-grch37, gn-grch38, vep-grch37, vep-grch38, mongo-grch37, mongo-grch38

# MongoDB GRCh37 Task Definition (with EFS persistence)
resource "aws_ecs_task_definition" "mongo_grch37" {
  family                   = "${var.environment}-oncokb-mongo-grch37"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  volume {
    name = "mongo-data"
    efs_volume_configuration {
      file_system_id     = var.efs_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_access_point_mongo_grch37_id
        iam             = "DISABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      cpu       = 512
      essential = true
      image     = var.gn_mongo_grch37_image
      memory    = 1024
      name      = "mongo-grch37"

      healthCheck = {
        command     = ["CMD-SHELL", "mongosh --eval \"db.adminCommand('ping')\" || mongo --eval \"db.adminCommand('ping')\" || exit 1"]
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
          "awslogs-stream-prefix" = "mongo-grch37"
        }
      }

      mountPoints = [
        {
          sourceVolume  = "mongo-data"
          containerPath = "/data/db"
          readOnly      = false
        }
      ]

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

# MongoDB GRCh38 Task Definition (with EFS persistence)
resource "aws_ecs_task_definition" "mongo_grch38" {
  family                   = "${var.environment}-oncokb-mongo-grch38"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  volume {
    name = "mongo-data-grch38"
    efs_volume_configuration {
      file_system_id     = var.efs_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_access_point_mongo_grch38_id
        iam             = "DISABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      cpu       = 512
      essential = true
      image     = var.gn_mongo_grch38_image
      memory    = 1024
      name      = "mongo-grch38"

      healthCheck = {
        command     = ["CMD-SHELL", "mongosh --eval \"db.adminCommand('ping')\" || mongo --eval \"db.adminCommand('ping')\" || exit 1"]
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
          "awslogs-stream-prefix" = "mongo-grch38"
        }
      }

      mountPoints = [
        {
          sourceVolume  = "mongo-data-grch38"
          containerPath = "/data/db"
          readOnly      = false
        }
      ]

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
        startPeriod = 300
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
        startPeriod = 300
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

      command = [
        "java",
        "-Dgn_vep.url=http://vep-grch37:6060/vep/human/hgvs/VARIANT",
        "-Dspring.data.mongodb.uri=mongodb://mongo-grch37:27017/annotator",
        "-Dcache.enabled=true",
        "-Dvep.static=true",
        "-Dserver.port=8888",
        "-jar", "/app.war"
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

      command = [
        "java",
        "-Dgn_vep.url=http://vep-grch38:6061/vep/human/hgvs/VARIANT",
        "-Dspring.data.mongodb.uri=mongodb://mongo-grch38:27017/annotator",
        "-Dcache.enabled=true",
        "-Dvep.static=true",
        "-Dserver.port=8889",
        "-jar", "/app.war"
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

      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod,api-docs,no-liquibase"
        },
        {
          name  = "APPLICATION_REDIS_ENABLED"
          value = "false"
        },
        {
          name  = "SERVER_PORT"
          value = "9090"
        }
      ]

      secrets = concat(
        [
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
        ],
        var.transcript_jwt_base64_secret_arn != "" ? [
          {
            name      = "JHIPSTER_SECURITY_AUTHENTICATION_JWT_BASE64_SECRET"
            valueFrom = var.transcript_jwt_base64_secret_arn
          }
        ] : []
      )

      healthCheck = {
        command     = ["CMD-SHELL", "curl -sf http://localhost:9090/actuator/health || exit 1"]
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
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-oncokb-transcript"
  }
}

# OncoKB API Task Definition
# Image entrypoint: /bin/sh -c "exec java ${JAVA_OPTS} -jar /webapp-runner.jar ${WEBAPPRUNNER_OPTS} /app.war"
# This is webapp-runner (Tomcat), NOT Spring Boot. Configuration must use -Djdbc.* system properties.
# We override entryPoint+command so the shell directly expands secret env vars ($JDBC_PASSWORD, etc.)
resource "aws_ecs_task_definition" "oncokb" {
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

      entryPoint = ["/bin/sh", "-c"]
      command = [join(" ", [
        "exec java",
        "-Djdbc.driverClassName=com.mysql.jdbc.Driver",
        "\"-Djdbc.url=$JDBC_URL\"",
        "\"-Djdbc.username=$JDBC_USERNAME\"",
        "\"-Djdbc.password=$JDBC_PASSWORD\"",
        "-Doncokb_transcript.url=http://oncokb-transcript:9090",
        "\"-Doncokb_transcript.token=$TRANSCRIPT_TOKEN\"",
        "-Dgenome_nexus.grch37.url=http://gn-grch37:8888",
        "-Dgenome_nexus.grch38.url=http://gn-grch38:8889",
        "-Dlog4j.configuration=classpath:properties/log4j.properties",
        "-jar /webapp-runner.jar /app.war",
      ])]

      secrets = concat(
        [
          {
            name      = "JDBC_PASSWORD"
            valueFrom = "${var.rds_secret_arn}:password::"
          },
          {
            name      = "JDBC_URL"
            valueFrom = "${var.rds_secret_arn}:jdbc_url::"
          },
          {
            name      = "JDBC_USERNAME"
            valueFrom = "${var.rds_secret_arn}:username::"
          }
        ],
        var.transcript_jwt_token_arn != "" ? [
          {
            name      = "TRANSCRIPT_TOKEN"
            valueFrom = var.transcript_jwt_token_arn
          }
        ] : []
      )

      healthCheck = {
        command     = ["CMD-SHELL", "curl -sf http://localhost:8080/api/v1/info || exit 1"]
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
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-oncokb"
  }
}
