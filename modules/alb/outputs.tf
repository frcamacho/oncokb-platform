output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.oncokb.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.oncokb.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID"
  value       = aws_lb.oncokb.zone_id
}

output "target_group_arn" {
  description = "OncoKB target group ARN"
  value       = aws_lb_target_group.oncokb.arn
}

output "listener_arn" {
  description = "HTTP listener ARN"
  value       = aws_lb_listener.http.arn
}
