# Internal Application Load Balancer for OncoKB API

locals {
  enable_https = var.certificate_arn != ""
}

resource "aws_lb" "oncokb" {
  name               = "${var.environment}-oncokb-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.private_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

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
  target_type = "ip"

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

# HTTP Listener -- forwards to target group when no cert, redirects to HTTPS when cert is present
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.oncokb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = local.enable_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = local.enable_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = local.enable_https ? null : aws_lb_target_group.oncokb.arn
  }
}

# HTTPS Listener (only created when certificate_arn is provided)
resource "aws_lb_listener" "https" {
  count = local.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.oncokb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.oncokb.arn
  }
}
