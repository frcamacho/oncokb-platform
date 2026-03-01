# OncoKB Platform on AWS Fargate

On-demand genomic annotation platform deployed as 8 Fargate services with a single RDS MySQL instance.
Services start at `desired_count = 0` and are scaled up/down via scripts for cost optimization.

## Architecture

```
                  Internal ALB (:80)
                        |
          ECS Fargate Cluster (Service Connect)
          ┌─────────────────────────────────┐
          │  oncokb (:8080) ← ALB           │
          │    ├─ oncokb-transcript (:9090)  │
          │    ├─ gn-grch37 (:8888)          │
          │    │    ├─ mongo-grch37 (:27017)  │  ← EFS
          │    │    └─ vep-grch37 (:6060)     │  ← EFS (VEP 98 cache)
          │    └─ gn-grch38 (:8889)          │
          │         ├─ mongo-grch38 (:27017)  │  ← EFS
          │         └─ vep-grch38 (:6061)     │  ← EFS (VEP 98 cache)
          └─────────────────────────────────┘
                        |
              RDS MySQL 8.0 (oncokb + oncokb_transcript)
```

| Component | Purpose |
|-----------|---------|
| **ECS Fargate** | 8 services, `desired_count=0` by default |
| **RDS MySQL 8.0** | `oncokb` and `oncokb_transcript` databases |
| **EFS** | VEP 98 cache (GRCh37/38) + MongoDB data persistence |
| **ECR** | 6 repositories (avoids Docker Hub rate limits) |
| **ALB** | Internal, HTTP :80 → OncoKB :8080 |
| **Secrets Manager** | DB credentials + JWT tokens |
| **Service Connect** | Inter-service discovery via Cloud Map |

### Cost Profile

| Scenario | Monthly Cost |
|----------|-------------|
| **Stopped (ECS=0, RDS running)** | ~$75 |
| **Stopped (ECS=0, RDS stopped)** | ~$35 |
| **Light usage (30 hrs/month)** | ~$96 |
| **Medium usage (100 hrs/month)** | ~$146 |

---

## Prerequisites

- [Pixi](https://pixi.sh/) (`pixi install` brings Terraform + AWS CLI)
- AWS SSO configured (`aws sso login --profile cggt-dev`)
- IAM permissions for ECS, VPC, RDS, EFS, ALB, CloudWatch, Secrets Manager, ECR

### Required Data

| File | Purpose | S3 Location |
|------|---------|-------------|
| `oncokb_v4_27.sql.gz` | OncoKB database dump | `s3://BUCKET/sql/` |
| `oncokb_transcript_v4_27.sql.gz` | Transcript database dump | `s3://BUCKET/sql/` |
| `98_GRCh37.tar` | VEP 98 GRCh37 cache (~14 GB) | `s3://BUCKET/gn-vep-data/` |
| `98_GRCh38.tar` | VEP 98 GRCh38 cache (~15 GB) | `s3://BUCKET/gn-vep-data/` |

Download VEP caches if not present:
```bash
aria2c -x 16 -s 16 https://public-oncokb-data.s3.us-east-1.amazonaws.com/gn-vep-data/98_GRCh37/98_GRCh37.tar -d databases/gn-vep-data/
aria2c -x 16 -s 16 https://public-oncokb-data.s3.us-east-1.amazonaws.com/gn-vep-data/98_GRCh38/98_GRCh38.tar -d databases/gn-vep-data/
```

---

## Quick Start

### 1. Backend setup (one-time)

```bash
# S3 state bucket
aws s3 mb s3://oncokb-tfstate-473e7965 --region us-east-1
aws s3api put-bucket-versioning --bucket oncokb-tfstate-473e7965 \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket oncokb-tfstate-473e7965 \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# DynamoDB lock table
aws dynamodb create-table --table-name oncokb-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region us-east-1

# Deployment data bucket
aws s3 mb s3://oncokb-deployment-data-270327054051 --region us-east-1
```

### 2. Upload data to S3

```bash
aws s3 cp databases/oncokb_v4_27.sql.gz         s3://oncokb-deployment-data-270327054051/sql/
aws s3 cp databases/oncokb_transcript_v4_27.sql.gz s3://oncokb-deployment-data-270327054051/sql/
aws s3 cp databases/gn-vep-data/98_GRCh37.tar   s3://oncokb-deployment-data-270327054051/gn-vep-data/
aws s3 cp databases/gn-vep-data/98_GRCh38.tar   s3://oncokb-deployment-data-270327054051/gn-vep-data/
```

### 3. Deploy infrastructure

```bash
pixi install
pixi run tf-init
pixi run tf-workspace-dev
pixi run dev-plan    # review ~50-60 resources
pixi run dev-apply   # ~15-20 min (RDS takes longest)
```

### 4. Push images to ECR

```bash
pixi run push-ecr
# or: ./scripts/push-ecr.sh --env dev
```

### 5. Create JWT secrets for transcript

```bash
# Generate a new secret + JWT token in one step
pixi run generate-transcript-token --generate-secret
# → prints the base64 secret (stderr) and the JWT token (stdout)

# Or with an existing secret
export ONCOKB_TRANSCRIPT_JWT_BASE64_SECRET="<your-base64-secret>"
pixi run generate-transcript-token

# Save token to a file
pixi run generate-transcript-token --generate-secret --out token.txt

# Without pixi: pip install -r scripts/requirements.txt
# python scripts/generate_transcript_token.py --generate-secret
```

Store both values in Secrets Manager:
```bash
aws secretsmanager create-secret \
  --name "oncokb/dev/oncokb-transcript/jwt-base64-secret" \
  --secret-string "<base64-secret-from-above>" --region us-east-1

aws secretsmanager create-secret \
  --name "oncokb/dev/oncokb-transcript/jwt-token" \
  --secret-string "<jwt-token-from-above>" --region us-east-1
```

Add the ARNs to `environments/dev.tfvars`:
```hcl
transcript_jwt_base64_secret_arn = "arn:aws:secretsmanager:us-east-1:270327054051:secret:oncokb/dev/oncokb-transcript/jwt-base64-secret-XXXXXX"
transcript_jwt_token_arn         = "arn:aws:secretsmanager:us-east-1:270327054051:secret:oncokb/dev/oncokb-transcript/jwt-token-XXXXXX"
```

Then `pixi run dev-plan && pixi run dev-apply` to update task definitions.

### 6. Initialize data

```bash
# Load SQL dumps into RDS (run from host with VPC access + mysql client)
export DB_SECRET_ARN=$(terraform output -raw db_secret_arn)
./scripts/init-rds-databases.sh

# Load VEP cache into EFS (run from ECS Exec or mounted EC2)
./scripts/init-efs-vep-cache.sh
```

### 7. Start services

```bash
pixi run start
# or: ./scripts/start-services.sh --env dev
```

### 8. Test

```bash
./scripts/test-endpoints.sh $(terraform output -raw alb_dns_name)
```

---

## Scripts

| Script | Purpose |
|--------|---------|
| `start-services.sh` | Start RDS (if stopped) + ECS services in dependency order |
| `stop-services.sh` | Scale ECS to 0; `--stop-rds` also stops the RDS instance |
| `check-services.sh` | Show status of all services and RDS |
| `push-ecr.sh` | Pull from Docker Hub, push to ECR |
| `init-rds-databases.sh` | Load SQL dumps from S3 into RDS |
| `init-efs-vep-cache.sh` | Extract VEP 98 cache tarballs to EFS |
| `test-endpoints.sh` | Curl ALB health + BRAF annotation test |
| `diagnose-failures.sh` | Stopped task reasons, recent logs, events |
| `generate_transcript_token.py` | Generate JWT secret + token for oncokb-transcript |

All scripts accept `--env ENV`, `--region REGION`, and `--cluster NAME`.

---

## Cost Management

### Stop services when idle (saves ~$700/month vs 24/7)

```bash
# Stop ECS only (RDS stays for quick restarts, ~$75/month baseline)
./scripts/stop-services.sh --env dev

# Stop ECS + RDS (for extended idle periods, ~$35/month baseline)
./scripts/stop-services.sh --env dev --stop-rds
```

### RDS auto-restart after 7 days

AWS automatically restarts stopped RDS instances after 7 days. To handle extended
shutdown, tag the instance so a Lambda/EventBridge rule can re-stop it:

```bash
aws rds add-tags-to-resource \
  --resource-name arn:aws:rds:us-east-1:270327054051:db:dev-oncokb \
  --tags Key=keep-stopped,Value=true --region us-east-1
```

### Restart everything

```bash
./scripts/start-services.sh --env dev
# Handles: RDS start (if stopped) → Tier 1 → Tier 2 → Tier 3
```

---

## Data Compatibility

| Component | Version | Data Required |
|-----------|---------|---------------|
| OncoKB API | 4.3.0 | `oncokb_v4_27.sql.gz` (v4.27 schema) |
| OncoKB Transcript | 0.9.4 | `oncokb_transcript_v4_27.sql.gz` |
| VEP | release-98 (image `v0.0.1`) | `98_GRCh37.tar` + `98_GRCh38.tar` (VEP 98 cache) |
| Genome Nexus | 2.0.2 | MongoDB seeded by `gn-mongo:0.32` images |

The VEP containers mount cache from EFS at `/opt/vep/.vep` (read-only). The cache
must match the VEP release version (98). GRCh37 and GRCh38 assemblies each have
their own EFS access point and VEP service.

---

## Nextflow Integration

```groovy
process startOncoKB {
    executor 'local'
    script:
    """
    ./scripts/start-services.sh --env dev
    sleep 90
    curl -f http://\$(terraform output -raw alb_dns_name)/api/v1/info
    """
}

process stopOncoKB {
    executor 'local'
    script:
    """
    ./scripts/stop-services.sh --env dev
    """
}
```

---

## Troubleshooting

```bash
# Service status
./scripts/check-services.sh --env dev

# Diagnose specific failures
./scripts/diagnose-failures.sh oncokb-transcript gn-grch37

# Tail logs
aws logs tail /ecs/oncokb/dev --follow --region us-east-1

# ECS exec into a container
TASK=$(aws ecs list-tasks --cluster dev-oncokb-cluster \
  --service-name dev-oncokb --query 'taskArns[0]' --output text --region us-east-1)
aws ecs execute-command --cluster dev-oncokb-cluster \
  --task $TASK --container oncokb --command /bin/sh --interactive --region us-east-1
```

---

## Cleanup

```bash
./scripts/stop-services.sh --env dev --stop-rds
pixi run dev-destroy

# Manual cleanup (buckets + lock table)
aws s3 rb s3://oncokb-deployment-data-270327054051 --force
aws s3 rb s3://oncokb-tfstate-473e7965 --force
aws dynamodb delete-table --table-name oncokb-terraform-locks
```
