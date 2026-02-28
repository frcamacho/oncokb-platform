# Internal Application Load Balancer for OncoKB API

resource "aws_lb" "oncokb" {
  name               = "${var.environment}-oncokb-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.private_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "${var.environment}-oncokb-alb"
    Environment = var.environment
  }
}

# Target Group for OncoKB API (port 8080)
resource "aws_lb_target_group" "oncokb" {
  name        = "${var.environment}-oncokb-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for awsvpc network mode

  health_check {
    enabled             = true
    path                = "/api/v1/info"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.environment}-oncokb-tg"
    Environment = var.environment
  }
}

# HTTP Listener (port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.oncokb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.oncokb.arn
  }
}
