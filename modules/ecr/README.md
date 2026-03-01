# ECR Module

Creates 6 ECR repositories for OncoKB platform images, eliminating Docker Hub rate limits. Each repository has scan-on-push enabled, AES256 encryption, and a lifecycle policy retaining the last 5 images.

## Repositories

| Repository | Source Image |
|------------|-------------|
| `gn-mongo-grch37` | `genomenexus/gn-mongo:0.32` |
| `gn-mongo-grch38` | `genomenexus/gn-mongo:0.32_grch38_ensembl95` |
| `genome-nexus-vep` | `genomenexus/genome-nexus-vep:v0.0.1` |
| `gn-spring-boot` | `genomenexus/gn-spring-boot:2.0.2` |
| `oncokb-transcript` | `mskcc/oncokb-transcript:0.9.4` |
| `oncokb` | `mskcc/oncokb:4.3.0` |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `environment` | Environment name (dev, staging, prod) | `string` | — | yes |
| `aws_region` | AWS region for ECR repositories | `string` | — | yes |

## Outputs

| Name | Description |
|------|-------------|
| `gn_mongo_grch37_repository_url` | ECR repository URL for Genome Nexus MongoDB GRCh37 |
| `gn_mongo_grch38_repository_url` | ECR repository URL for Genome Nexus MongoDB GRCh38 |
| `genome_nexus_vep_repository_url` | ECR repository URL for Genome Nexus VEP |
| `gn_spring_boot_repository_url` | ECR repository URL for Genome Nexus Spring Boot |
| `oncokb_transcript_repository_url` | ECR repository URL for OncoKB Transcript |
| `oncokb_repository_url` | ECR repository URL for OncoKB main application |
