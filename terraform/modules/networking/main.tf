# Security groups for ECS on EC2 deployment

# ALB Security Group (internal)
resource "aws_security_group" "alb" {
  name        = "${var.environment}-oncokb-alb-sg"
  description = "Internal ALB - allows HTTP/HTTPS from within VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-oncokb-alb-sg"
    Environment = var.environment
  }
}

# ECS Container Instances & Tasks Security Group
resource "aws_security_group" "ecs" {
  name        = "${var.environment}-oncokb-ecs-sg"
  description = "ECS tasks - allows traffic from ALB and inter-task communication"
  vpc_id      = var.vpc_id

  # Allow traffic from ALB
  ingress {
    description     = "From ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow inter-task communication (service discovery)
  ingress {
    description = "Inter-task communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-oncokb-ecs-sg"
    Environment = var.environment
  }
}

# RDS MySQL Security Group
resource "aws_security_group" "rds" {
  name        = "${var.environment}-oncokb-rds-sg"
  description = "RDS MySQL - accepts connections from ECS tasks only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from ECS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-oncokb-rds-sg"
    Environment = var.environment
  }
}

# EFS Security Group (for VEP cache)
resource "aws_security_group" "efs" {
  name        = "${var.environment}-oncokb-efs-sg"
  description = "EFS - NFS access from ECS tasks only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from ECS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-oncokb-efs-sg"
    Environment = var.environment
  }
}
