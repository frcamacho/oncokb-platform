# Reference existing Private Hosted Zone
data "aws_route53_zone" "private" {
  name         = var.parent_domain_name
  private_zone = true
  vpc_id       = var.vpc_id
}

# ALB Alias Record (for ECS deployment)
resource "aws_route53_record" "alb" {
  count = var.create_alb_record ? 1 : 0

  zone_id = data.aws_route53_zone.private.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# EC2 A Record (legacy Docker Compose deployment)
resource "aws_route53_record" "ec2" {
  count = var.create_ec2_record ? 1 : 0

  zone_id = data.aws_route53_zone.private.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [var.ec2_private_ip]
}
