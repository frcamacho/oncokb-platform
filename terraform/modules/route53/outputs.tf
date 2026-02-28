output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.private.zone_id
}

output "zone_name" {
  description = "Route53 hosted zone name"
  value       = data.aws_route53_zone.private.name
}

output "zone_name_servers" {
  description = "Route53 hosted zone name servers"
  value       = data.aws_route53_zone.private.name_servers
}
