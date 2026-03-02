# ECR Repositories for OncoKB Platform
# Eliminates Docker Hub rate limiting by hosting images in AWS ECR

# Genome Nexus MongoDB GRCh37
resource "aws_ecr_repository" "gn_mongo_grch37" {
  name                 = "${var.environment}/gn-mongo-grch37"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment   = var.environment
    Name          = "${var.environment}/gn-mongo-grch37"
    SourceImage   = "genomenexus/gn-mongo:0.32"
    Documentation = "MongoDB with Genome Nexus annotations for GRCh37"
  }
}

# Genome Nexus MongoDB GRCh38
resource "aws_ecr_repository" "gn_mongo_grch38" {
  name                 = "${var.environment}/gn-mongo-grch38"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment   = var.environment
    Name          = "${var.environment}/gn-mongo-grch38"
    SourceImage   = "genomenexus/gn-mongo:0.32_grch38_ensembl95"
    Documentation = "MongoDB with Genome Nexus annotations for GRCh38"
  }
}

# Genome Nexus VEP
resource "aws_ecr_repository" "genome_nexus_vep" {
  name                 = "${var.environment}/genome-nexus-vep"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment   = var.environment
    Name          = "${var.environment}/genome-nexus-vep"
    SourceImage   = "genomenexus/genome-nexus-vep:v0.0.1"
    Documentation = "Variant Effect Predictor service"
  }
}

# Genome Nexus Spring Boot
resource "aws_ecr_repository" "gn_spring_boot" {
  name                 = "${var.environment}/gn-spring-boot"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment   = var.environment
    Name          = "${var.environment}/gn-spring-boot"
    SourceImage   = "genomenexus/gn-spring-boot:2.0.2"
    Documentation = "Genome Nexus API service"
  }
}

# OncoKB Transcript
resource "aws_ecr_repository" "oncokb_transcript" {
  name                 = "${var.environment}/oncokb-transcript"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment   = var.environment
    Name          = "${var.environment}/oncokb-transcript"
    SourceImage   = "mskcc/oncokb-transcript:0.9.4"
    Documentation = "OncoKB Transcript service"
  }
}

# OncoKB Main Application
resource "aws_ecr_repository" "oncokb" {
  name                 = "${var.environment}/oncokb"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment   = var.environment
    Name          = "${var.environment}/oncokb"
    SourceImage   = "mskcc/oncokb:4.3.0"
    Documentation = "OncoKB main application"
  }
}

# Lifecycle policy to clean up old images
resource "aws_ecr_lifecycle_policy" "cleanup_old_images" {
  for_each = {
    gn_mongo_grch37   = aws_ecr_repository.gn_mongo_grch37.name
    gn_mongo_grch38   = aws_ecr_repository.gn_mongo_grch38.name
    genome_nexus_vep  = aws_ecr_repository.genome_nexus_vep.name
    gn_spring_boot    = aws_ecr_repository.gn_spring_boot.name
    oncokb_transcript = aws_ecr_repository.oncokb_transcript.name
    oncokb            = aws_ecr_repository.oncokb.name
  }

  repository = each.value

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
