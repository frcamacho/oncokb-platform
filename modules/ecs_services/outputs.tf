output "oncokb_service_id" {
  description = "OncoKB ECS service ID"
  value       = aws_ecs_service.oncokb.id
}

output "oncokb_service_name" {
  description = "OncoKB ECS service name"
  value       = aws_ecs_service.oncokb.name
}

output "oncokb_transcript_service_id" {
  description = "OncoKB Transcript ECS service ID"
  value       = aws_ecs_service.oncokb_transcript.id
}

output "gn_grch37_service_id" {
  description = "Genome Nexus GRCh37 ECS service ID"
  value       = aws_ecs_service.gn_grch37.id
}

output "gn_grch38_service_id" {
  description = "Genome Nexus GRCh38 ECS service ID"
  value       = aws_ecs_service.gn_grch38.id
}

output "vep_grch37_service_id" {
  description = "VEP GRCh37 ECS service ID"
  value       = aws_ecs_service.vep_grch37.id
}

output "vep_grch38_service_id" {
  description = "VEP GRCh38 ECS service ID"
  value       = aws_ecs_service.vep_grch38.id
}

output "mongo_grch37_service_id" {
  description = "MongoDB GRCh37 ECS service ID"
  value       = aws_ecs_service.mongo_grch37.id
}

output "mongo_grch38_service_id" {
  description = "MongoDB GRCh38 ECS service ID"
  value       = aws_ecs_service.mongo_grch38.id
}
