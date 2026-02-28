output "gn_mongo_grch37_repository_url" {
  description = "ECR repository URL for Genome Nexus MongoDB GRCh37"
  value       = aws_ecr_repository.gn_mongo_grch37.repository_url
}

output "gn_mongo_grch38_repository_url" {
  description = "ECR repository URL for Genome Nexus MongoDB GRCh38"
  value       = aws_ecr_repository.gn_mongo_grch38.repository_url
}

output "genome_nexus_vep_repository_url" {
  description = "ECR repository URL for Genome Nexus VEP"
  value       = aws_ecr_repository.genome_nexus_vep.repository_url
}

output "gn_spring_boot_repository_url" {
  description = "ECR repository URL for Genome Nexus Spring Boot"
  value       = aws_ecr_repository.gn_spring_boot.repository_url
}

output "oncokb_transcript_repository_url" {
  description = "ECR repository URL for OncoKB Transcript"
  value       = aws_ecr_repository.oncokb_transcript.repository_url
}

output "oncokb_repository_url" {
  description = "ECR repository URL for OncoKB main application"
  value       = aws_ecr_repository.oncokb.repository_url
}
