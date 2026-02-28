# OncoKB Platform Deployment Guide

**Terraform-managed OncoKB microservices platform on AWS ECS Fargate**

## Architecture Overview

This deployment creates a cost-optimized, on-demand genomic annotation platform with:

- **8 Fargate Services**: OncoKB API, OncoKB Transcript, GenomeNexus (GRCh37/38), VEP (GRCh37/38), MongoDB (GRCh37/38)
- **RDS MySQL 8.0**: Primary databases with auto-scaling storage (50-100GB)
- **EFS**: Shared VEP cache storage (multi-AZ, NFS)
- **Internal ALB**: HTTP routing with health checks
- **Private VPC**: Security groups, Service Connect mesh, CloudWatch logging
- **Secrets Manager**: Database credentials and auth tokens

### Cost Profile

| Scenario | Monthly Cost | Hours/Month | Savings vs EC2 |
|----------|--------------|-------------|----------------|
| **Baseline (stopped)** | $75-80 | 0 | - |
| **Light usage** | $96 | 30 | 96% ✅ |
| **Medium usage** | $146 | 100 | 71% ✅ |
| **Heavy usage** | $238 | 160 | 53% ✅ |
| **24/7 (EC2 equivalent)** | ~$800 | 730 | 0% |

**Break-even**: ~130 hours/month. Below this, Fargate is cheaper and simpler.

---

## Prerequisites

### Required Tools
- [Pixi](https://pixi.sh/) package manager (includes Terraform + AWS CLI)
- AWS account with SSO configured
- IAM permissions for:
  - S3 (state backend)
  - DynamoDB (state locking)
  - ECS, VPC, RDS, EFS, ALB, CloudWatch, Secrets Manager, Route53

### Required Data Files
Located in `databases/` directory:
- `oncokb_v4_27.sql.gz` (OncoKB database dump)
- `oncokb_transcript_v4_27.sql.gz` (Transcript database dump)
- `gn-vep-data/98_GRCh37.tar` (VEP cache for GRCh37)
- `gn-vep-data/98_GRCh38.tar` (VEP cache for GRCh38)

**Download VEP caches** (if not present):
```bash
brew install aria2  # or: sudo apt install aria2

aria2c -x 16 -s 16 https://public-oncokb-data.s3.us-east-1.amazonaws.com/gn-vep-data/98_GRCh37/98_GRCh37.tar -d databases/gn-vep-data/
aria2c -x 16 -s 16 https://public-oncokb-data.s3.us-east-1.amazonaws.com/gn-vep-data/98_GRCh38/98_GRCh38.tar -d databases/gn-vep-data/
```

---

## Phase 1: Environment Setup

### 1.1 Install Dependencies
```bash
cd oncokb-platform
pixi install
```

### 1.2 Configure AWS Credentials
```bash
# Login to AWS SSO
aws sso login --profile cggt-dev
export AWS_PROFILE=cggt-dev

# Verify credentials
aws sts get-caller-identity
```

Expected output:
```json
{
  "UserId": "AIDA...",
  "Account": "270327054051",
  "Arn": "arn:aws:sts::270327054051:assumed-role/..."
}
```

### 1.3 Verify Terraform Installation
```bash
pixi run terraform --version
```

Expected: `Terraform v1.7+`

---

## Phase 2: Backend Infrastructure

### 2.1 Create DynamoDB Lock Table
```bash
aws dynamodb create-table \
  --table-name oncokb-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**Verify table creation:**
```bash
aws dynamodb describe-table --table-name oncokb-terraform-locks --query 'Table.[TableName,TableStatus]'
```

Expected: `["oncokb-terraform-locks", "ACTIVE"]`

### 2.2 Create S3 State Bucket
```bash
# Create bucket (if not already created)
aws s3 mb s3://oncokb-tfstate-473e7965 --region us-east-1

# Enable versioning (required for state recovery)
aws s3api put-bucket-versioning \
  --bucket oncokb-tfstate-473e7965 \
  --versioning-configuration Status=Enabled

# Block public access
aws s3api put-public-access-block \
  --bucket oncokb-tfstate-473e7965 \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

**Verify bucket:**
```bash
aws s3 ls s3://oncokb-tfstate-473e7965
```

---

## Phase 3: Data Preparation

### 3.1 Create Deployment Bucket
```bash
# Create bucket
aws s3 mb s3://oncokb-deployment-data-270327054051 --region us-east-1

# Block public access
aws s3api put-public-access-block \
  --bucket oncokb-deployment-data-270327054051 \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

**Verify bucket:**
```bash
aws s3 ls s3://oncokb-deployment-data-270327054051
```

### 3.2 Upload SQL Database Dumps
```bash
# Upload OncoKB database
aws s3 cp ./databases/oncokb_v4_27.sql.gz \
  s3://oncokb-deployment-data-270327054051/sql/

# Upload Transcript database
aws s3 cp ./databases/oncokb_transcript_v4_27.sql.gz \
  s3://oncokb-deployment-data-270327054051/sql/

# Verify uploads
aws s3 ls s3://oncokb-deployment-data-270327054051/sql/
```

Expected:
```
2026-02-28 oncokb_v4_27.sql.gz
2026-02-28 oncokb_transcript_v4_27.sql.gz
```

### 3.3 Upload VEP Cache Files
```bash
# Upload GRCh37 cache (~14GB, takes 5-10 minutes)
aws s3 cp ./databases/gn-vep-data/98_GRCh37.tar \
  s3://oncokb-deployment-data-270327054051/gn-vep-data/

# Upload GRCh38 cache (~15GB, takes 5-10 minutes)
aws s3 cp ./databases/gn-vep-data/98_GRCh38.tar \
  s3://oncokb-deployment-data-270327054051/gn-vep-data/

# Verify uploads
aws s3 ls s3://oncokb-deployment-data-270327054051/gn-vep-data/
```

Expected:
```
2026-02-28 98_GRCh37.tar
2026-02-28 98_GRCh38.tar
```

### 3.4 Upload Docker Compose Configuration
```bash
# Upload compose file (used by ECS task definitions)
aws s3 cp docker/docker-compose.yml \
  s3://oncokb-deployment-data-270327054051/docker/

# Verify
aws s3 ls s3://oncokb-deployment-data-270327054051/docker/
```

### 3.5 Migrate Docker Images to ECR (Optional but Recommended)

**Why ECR?** Hosting images in ECR eliminates Docker Hub rate limiting and improves pull speeds within AWS.

**Note:** This is optional. You can skip this step and use Docker Hub images directly. However, for production deployments, ECR is recommended.

**Step 1: Create ECR repositories** (happens automatically with Terraform, but you can verify):
```bash
# After running terraform apply, check ECR repositories
aws ecr describe-repositories --region us-east-1 \
  --query 'repositories[?contains(repositoryName, `dev`)].repositoryName' --output table
```

Expected repositories:
- `dev/gn-mongo-grch37`
- `dev/gn-mongo-grch38`
- `dev/genome-nexus-vep`
- `dev/gn-spring-boot`
- `dev/oncokb-transcript`
- `dev/oncokb`

**Step 2: Authenticate Docker to ECR:**
```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 270327054051.dkr.ecr.us-east-1.amazonaws.com
```

**Step 3: Pull, tag, and push images:**

```bash
# Set your AWS account ID
export AWS_ACCOUNT_ID=270327054051
export AWS_REGION=us-east-1
export ENV=dev

# Genome Nexus MongoDB GRCh37
docker pull genomenexus/gn-mongo:0.32
docker tag genomenexus/gn-mongo:0.32 \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ENV/gn-mongo-grch37:0.32
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ENV/gn-mongo-grch37:0.32

# Genome Nexus MongoDB GRCh38
docker pull genomenexus/gn-mongo:0.32_grch38_ensembl95
docker tag genomenexus/gn-mongo:0.32_grch38_ensembl95 \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ENV/gn-mongo-grch38:0.32_grch38_ensembl95
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ENV/gn-mongo-grch38:0.32_grch38_ensembl95

# Genome Nexus VEP
docker pull genomenexus/genome-nexus-vep:v0.0.1
docker tag genomenexus/genome-nexus-vep:v0.0.1 \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ENV/genome-nexus-vep:v0.0.1
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ENV/genome-nexus-vep:v0.0.1

# Genome Nexus Spring Boot
docker pull genomenexus/gn-spring-boot:2.0.2
docker tag genomenexus/gn-spring-boot:2.0.2 \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ENV/gn-spring-boot:2.0.2
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ENV/gn-spring-boot:2.0.2

# OncoKB Transcript
docker pull mskcc/oncokb-transcript:0.9.4
docker tag mskcc/oncokb-transcript:0.9.4 \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ENV/oncokb-transcript:0.9.4
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ENV/oncokb-transcript:0.9.4

# OncoKB Main Application
docker pull mskcc/oncokb:4.3.0
docker tag mskcc/oncokb:4.3.0 \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ENV/oncokb:4.3.0
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ENV/oncokb:4.3.0
```

**Step 4: Update task definitions to use ECR images:**

Edit `terraform/modules/ecs_services/main.tf` and replace Docker Hub image URLs with ECR URLs:

```hcl
# Example: Change from
image = "genomenexus/gn-mongo:0.32"
# To
image = "270327054051.dkr.ecr.us-east-1.amazonaws.com/dev/gn-mongo-grch37:0.32"
```

**Step 5: Apply updated task definitions:**
```bash
cd terraform
pixi run dev-plan   # Review changes
pixi run dev-apply  # Apply
```

**Step 6: Force new deployment** to use ECR images:
```bash
# Update all services to use new task definitions
aws ecs update-service --cluster dev-oncokb-cluster --service dev-oncokb \
  --force-new-deployment --region us-east-1
aws ecs update-service --cluster dev-oncokb-cluster --service dev-oncokb-transcript \
  --force-new-deployment --region us-east-1
aws ecs update-service --cluster dev-oncokb-cluster --service dev-gn-grch37 \
  --force-new-deployment --region us-east-1
aws ecs update-service --cluster dev-oncokb-cluster --service dev-gn-grch38 \
  --force-new-deployment --region us-east-1
aws ecs update-service --cluster dev-oncokb-cluster --service dev-vep-grch37 \
  --force-new-deployment --region us-east-1
aws ecs update-service --cluster dev-oncokb-cluster --service dev-vep-grch38 \
  --force-new-deployment --region us-east-1
aws ecs update-service --cluster dev-oncokb-cluster --service dev-mongo-grch37 \
  --force-new-deployment --region us-east-1
aws ecs update-service --cluster dev-oncokb-cluster --service dev-mongo-grch38 \
  --force-new-deployment --region us-east-1
```

---

## Phase 4: Infrastructure Deployment

### 4.1 Initialize Terraform
```bash
# Initialize backend and download providers
pixi run tf-init

# Create/select dev workspace
pixi run tf-workspace-dev
```

Expected output:
```
Switched to workspace "dev".
```

### 4.2 Validate Configuration
```bash
# Format check
pixi run fmt-check

# Validate syntax
pixi run validate

# Run linter (optional but recommended)
pixi run lint
```

All checks should pass with no errors.

### 4.3 Review Deployment Plan
```bash
# Generate plan for dev environment
pixi run dev-plan
```

**Review the plan output carefully:**
- ✅ Check resource counts match expected (~50-60 resources)
- ✅ Verify no unexpected deletions/replacements
- ✅ Confirm RDS encryption is enabled
- ✅ Confirm EFS encryption is enabled (if fix was applied)
- ✅ Review security group rules

### 4.4 Deploy Infrastructure

**⚠️ IF YOU HAVE ALREADY DEPLOYED** (and haven't destroyed the previous deployment):

Since security group and ECR changes have been applied to the code, you need to update the existing deployment:

```bash
# Review what will change
pixi run dev-plan

# Apply only the necessary changes (should be minimal since security groups and ECR were already updated)
pixi run dev-apply
```

**Expected changes**: Security group rule updates, possibly ECR repository tags or task definition updates. Infrastructure should remain in place (no RDS/EFS recreation).

---

**⚠️ IF THIS IS A FRESH DEPLOYMENT**:

```bash
# Apply the full plan
pixi run dev-apply
```

**Deployment time**: ~15-20 minutes

Key milestones:
1. VPC resources (30 seconds)
2. EFS file system + mount targets (2 minutes)
3. RDS database instance (10-15 minutes) ⏱️
4. ECS cluster + services (2 minutes)
5. ALB + target groups (2 minutes)
6. Route53 records (30 seconds)

### 4.5 Save Deployment Outputs
```bash
cd terraform
terraform output > deployment-outputs.txt
cat deployment-outputs.txt
```

**Critical outputs to save:**
```
alb_dns_name = "internal-dev-oncokb-alb-1234567890.us-east-1.elb.amazonaws.com"
cluster_name = "dev-oncokb-cluster"
db_endpoint = "dev-oncokb.cacxtgkaufcx.us-east-1.rds.amazonaws.com:3306"
db_secret_arn = "arn:aws:secretsmanager:us-east-1:270327054051:secret:..."
efs_id = "fs-0abc1234def56789"
oncokb_url = "http://oncokb.cggt-dev.vrtx.com/api/v1/info"
```

---

## Phase 5: Verify Infrastructure

### 5.1 Check ECS Cluster
```bash
aws ecs describe-clusters --clusters dev-oncokb-cluster --region us-east-1 \
  --query 'clusters[0].[clusterName,status,runningTasksCount]'
```

Expected: `["dev-oncokb-cluster", "ACTIVE", 0]` (services start at 0 desired count)

### 5.2 Verify RDS Database
```bash
aws rds describe-db-instances --region us-east-1 \
  --query 'DBInstances[?DBInstanceIdentifier==`dev-oncokb`].[DBInstanceStatus,Endpoint.Address]'
```

Expected: `[["available", "dev-oncokb.cacxtgkaufcx.us-east-1.rds.amazonaws.com"]]`

### 5.3 Check EFS Mount Targets
```bash
aws efs describe-mount-targets --file-system-id $(terraform output -raw efs_id) --region us-east-1 \
  --query 'MountTargets[*].[MountTargetId,LifeCycleState,SubnetId]'
```

Expected: 3 mount targets in "available" state (one per AZ)

### 5.4 Verify Secrets Manager
```bash
 aws secretsmanager list-secrets --region us-east-1 \
     --query 'SecretList[?starts_with(Name, `oncokb/dev`)].[Name,ARN]' --output table

# all of oncokb 
 aws secretsmanager list-secrets --region us-east-1 \
     --query 'SecretList[?contains(Name, `oncokb`)].[Name,ARN]' --output table
```

Expected secrets:
- `oncokb/dev/db-credentials`

### 5.5 Check ALB Health
```bash
aws elbv2 describe-load-balancers --region us-east-1 \
  --query 'LoadBalancers[?starts_with(LoadBalancerName, `dev-oncokb`)].[LoadBalancerName,State.Code,Scheme]'
```

Expected: `[["dev-oncokb-alb", "active", "internal"]]`

---

## Phase 6: Initialize Application Data

**⚠️ IMPORTANT**: Services are deployed with `desired_count = 0` to avoid costs while idle. You must start services before initialization.

### 6.1 Start All Services

**⚠️ IF YOU UPDATED AN EXISTING DEPLOYMENT**:

Your services may already be running. Check their status first:

```bash
# List services
aws ecs list-services --cluster dev-oncokb-cluster --region us-east-1

# Check running counts
aws ecs describe-services --cluster dev-oncokb-cluster --region us-east-1 \
  --services $(aws ecs list-services --cluster dev-oncokb-cluster --region us-east-1 --query 'serviceArns[*]' --output text | xargs -n1 basename) \
  --query 'services[*].[serviceName,runningCount,desiredCount]' --output table
```

**If services are already running** (runningCount > 0), skip to Phase 6.2.

**If services are stopped** (runningCount = 0):
```bash
# Start all 8 Fargate services
./scripts/start-services.sh dev-oncokb-cluster us-east-1
```

**Wait ~90 seconds** for services to reach RUNNING state and verify:
```bash
aws ecs describe-services --cluster dev-oncokb-cluster --region us-east-1 \
  --services $(aws ecs list-services --cluster dev-oncokb-cluster --region us-east-1 --query 'serviceArns[*]' --output text | xargs -n1 basename) \
  --query 'services[*].[serviceName,runningCount,desiredCount]' --output table
```

Expected: All services show `runningCount = desiredCount = 1`

```bash
  aws ecs describe-services --cluster dev-oncokb-cluster --region us-east-1 --services dev-vep-grch38 dev-vep-grch37 dev-oncokb-transcript dev-oncokb dev-gn-grch37 dev-gn-grch38 --query 'services[*].[serviceName,status,deployments[0].rolloutState,events[0:3]]' --output json
```
### 6.2 Test Service Availability
```bash
# Test OncoKB API endpoint (from within VPC or via VPN)
curl -s http://oncokb.cggt-dev.vrtx.com/api/v1/info | jq

# Test GenomeNexus GRCh37
curl -s http://gn-grch37.cggt-dev.vrtx.com/version | jq

# Test GenomeNexus GRCh38
curl -s http://gn-grch38.cggt-dev.vrtx.com/version | jq
```

Expected: JSON responses with version information

### 6.3 Initialize VEP Cache (~15 minutes)

**⚠️ IF YOU UPDATED AN EXISTING DEPLOYMENT**:

Check if VEP cache is already initialized on EFS:

```bash
# Connect to a VEP task to check
TASK_ARN=$(aws ecs list-tasks --cluster dev-oncokb-cluster \
  --service-name dev-vep-grch37 --region us-east-1 \
  --query 'taskArns[0]' --output text)

aws ecs execute-command --cluster dev-oncokb-cluster \
  --task $TASK_ARN --container vep-grch37 \
  --command "/bin/bash" --interactive --region us-east-1

# Inside container, check if cache exists
ls -lh /mnt/efs/vep-cache/
```

**If VEP cache exists**, skip this step.

**If VEP cache is missing** or this is a fresh deployment:

**Connect to an ECS task** (requires AWS SSM Session Manager plugin):
```bash
# Get a running task ARN
TASK_ARN=$(aws ecs list-tasks --cluster dev-oncokb-cluster \
  --service-name dev-vep-grch37 --region us-east-1 \
  --query 'taskArns[0]' --output text)

# Execute interactive shell
aws ecs execute-command --cluster dev-oncokb-cluster \
  --task $TASK_ARN --container vep-grch37 \
  --command "/bin/bash" --interactive --region us-east-1
```

**Inside the container:**
```bash
# Initialize VEP cache from S3
# (This script extracts VEP caches to EFS mount)
/opt/oncokb/scripts/init-efs-vep-cache.sh

# Exit container
exit
```

**Expected output:**
```
Extracting 98_GRCh37.tar to /mnt/efs/vep-cache...
Extracting 98_GRCh38.tar to /mnt/efs/vep-cache...
VEP cache initialization complete.
```

### 6.4 Initialize RDS Databases (~30 minutes)

**⚠️ IF YOU UPDATED AN EXISTING DEPLOYMENT**:

Your RDS databases likely still contain data from the previous deployment. Verify first:

```bash
# Get database credentials
DB_SECRET=$(cd terraform && terraform output -raw db_secret_arn)
DB_HOST=$(cd terraform && terraform output -raw db_endpoint | cut -d: -f1)
DB_USER=$(aws secretsmanager get-secret-value --secret-id $DB_SECRET \
  --query 'SecretString' --output text | jq -r .username)
DB_PASS=$(aws secretsmanager get-secret-value --secret-id $DB_SECRET \
  --query 'SecretString' --output text | jq -r .password)

# Connect and check (from within VPC or via VPN)
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -e "SHOW DATABASES;"
```

**If databases exist** (oncokb, oncokb_transcript), skip this step unless you need to reimport data.

**If databases are empty** or this is a fresh deployment:

**Connect to OncoKB API task:**
```bash
TASK_ARN=$(aws ecs list-tasks --cluster dev-oncokb-cluster \
  --service-name dev-oncokb --region us-east-1 \
  --query 'taskArns[0]' --output text)

aws ecs execute-command --cluster dev-oncokb-cluster \
  --task $TASK_ARN --container oncokb \
  --command "/bin/bash" --interactive --region us-east-1
```

**Inside the container:**
```bash
# Import SQL dumps from S3 to RDS
/opt/oncokb/scripts/init-rds-databases.sh
```

**Expected output:**
```
Downloading oncokb_v4_27.sql.gz from S3...
Importing oncokb database... (20-25 minutes)
Downloading oncokb_transcript_v4_27.sql.gz from S3...
Importing oncokb_transcript database... (5 minutes)
Database initialization complete.
```

### 6.5 Verify Database Import
```bash
# Get database credentials from Secrets Manager
DB_SECRET=$(terraform output -raw db_secret_arn)
DB_HOST=$(terraform output -raw db_endpoint | cut -d: -f1)
DB_USER=$(aws secretsmanager get-secret-value --secret-id $DB_SECRET \
  --query 'SecretString' --output text | jq -r .username)
DB_PASS=$(aws secretsmanager get-secret-value --secret-id $DB_SECRET \
  --query 'SecretString' --output text | jq -r .password)

# Connect to RDS (from within VPC)
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS

# Verify tables
SHOW DATABASES;
USE oncokb;
SHOW TABLES;
SELECT COUNT(*) FROM gene;  -- Should return >20,000 genes
```

---

## Phase 7: Cost Management

### 7.1 Stop Services to Avoid Charges
```bash
# Stop all services (scale to 0)
./scripts/stop-services.sh dev-oncokb-cluster us-east-1
```

**Post-stop cost**: ~$75-80/month (RDS + EFS + ALB + CloudWatch)

### 7.2 Monitor Costs
```bash
# Check current month's Fargate costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://<(echo '{
    "Dimensions": {
      "Key": "SERVICE",
      "Values": ["Amazon Elastic Container Service"]
    }
  }') \
  --query 'ResultsByTime[*].[TimePeriod.Start,Total.BlendedCost.Amount]'
```

### 7.3 Set Up Budget Alerts (Recommended)
```bash
# Create $250/month budget with 80% alert
aws budgets create-budget \
  --account-id 270327054051 \
  --budget file://<(cat <<'EOF'
{
  "BudgetName": "oncokb-monthly-budget",
  "BudgetLimit": {
    "Amount": "250",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {
    "TagKeyValue": ["user:Project$oncokb"]
  }
}
EOF
) \
  --notifications-with-subscribers file://<(cat <<'EOF'
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "your-email@vrtx.com"
      }
    ]
  }
]
EOF
)
```

---

## Nextflow Integration

### Start Services Before Pipeline
```groovy
process startOncoKB {
    executor 'local'
    
    script:
    """
    for service in oncokb oncokb-transcript gn-grch37 gn-grch38 \
                   vep-grch37 vep-grch38 mongo-grch37 mongo-grch38; do
      aws ecs update-service --cluster dev-oncokb-cluster \
          --service dev-\${service} --desired-count 1 --region us-east-1
    done
    
    # Wait for services to become healthy
    sleep 90
    
    # Verify API availability
    curl -f http://oncokb.cggt-dev.vrtx.com/api/v1/info
    """
}
```

### Stop Services After Pipeline
```groovy
process stopOncoKB {
    executor 'local'
    
    script:
    """
    for service in oncokb oncokb-transcript gn-grch37 gn-grch38 \
                   vep-grch37 vep-grch38 mongo-grch37 mongo-grch38; do
      aws ecs update-service --cluster dev-oncokb-cluster \
          --service dev-\${service} --desired-count 0 --region us-east-1
    done
    """
}
```

---

## Production Deployment

### Differences from Dev
- **RDS instance**: `db.t3.medium` instead of `db.t3.small`
- **Multi-AZ RDS**: Enabled for high availability (recommended, add 2x cost)
- **Backup retention**: 7 days (recommended, currently 0)
- **Environment tag**: `prod` instead of `dev`

### Deployment Steps
```bash
# Select prod workspace
pixi run tf-workspace-prod

# Review prod plan
pixi run prod-plan

# Apply prod configuration
pixi run prod-apply
```

**⚠️ Production Checklist:**
- [ ] Enable RDS backups: Set `backup_retention_period = 7` in `environments/prod.tfvars`
- [ ] Enable RDS Multi-AZ: Set `multi_az = true` in `main.tf` (increases cost 2x)
- [ ] Enable EFS encryption: Set `encrypted = true` in `modules/efs/variables.tf`
- [ ] Configure HTTPS: Add ACM certificate + HTTPS listener to ALB
- [ ] Set up CloudWatch alarms for service health
- [ ] Configure AWS WAF for rate limiting (optional)

---

## Troubleshooting

### Services Won't Start
```bash
# Check service events
aws ecs describe-services --cluster dev-oncokb-cluster \
  --services dev-oncokb --region us-east-1 \
  --query 'services[0].events[:5]'

# Check task failures
aws ecs list-tasks --cluster dev-oncokb-cluster \
  --desired-status STOPPED --region us-east-1 | head -5
```

**Common causes:**
- Security groups blocking Fargate tasks (check VPC security group rules)
- Docker image pull failures (check CloudWatch logs)
- Insufficient CPU/memory (increase task definition limits)

### Database Connection Failures
```bash
# Test RDS connectivity from ECS task
aws ecs execute-command --cluster dev-oncokb-cluster \
  --task <TASK_ARN> --container oncokb \
  --command "nc -zv dev-oncokb.cacxtgkaufcx.us-east-1.rds.amazonaws.com 3306" \
  --interactive --region us-east-1
```

**Common causes:**
- Security group not allowing ECS tasks to RDS (port 3306)
- Database not in "available" state (check RDS console)
- Incorrect credentials in Secrets Manager

### EFS Mount Failures
```bash
# Check mount target status
aws efs describe-mount-targets --file-system-id $(terraform output -raw efs_id) \
  --query 'MountTargets[*].[LifeCycleState,SubnetId,IpAddress]'
```

**Common causes:**
- Mount targets not in all required subnets
- Security group blocking NFS (port 2049)
- EFS file system in "creating" state

### Health Check Failures
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn <TG_ARN> \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]'
```

**Common causes:**
- Service not responding on expected port (8080)
- Health check path incorrect (`/api/v1/info`)
- Service startup time exceeds health check grace period

### View CloudWatch Logs
```bash
# Tail logs for a specific service
aws logs tail /ecs/dev-oncokb --follow --region us-east-1

# Search for errors
aws logs filter-log-events --log-group-name /ecs/dev-oncokb \
  --filter-pattern "ERROR" --region us-east-1
```

---

## Maintenance

### Update Service Image Versions
```bash
# Edit task definition in terraform/modules/ecs_services/main.tf
# Change image tag, e.g., oncokb/oncokb-public-api:3.0 -> 3.1

# Apply changes
pixi run dev-plan
pixi run dev-apply

# Force new deployment (pull latest image)
aws ecs update-service --cluster dev-oncokb-cluster \
  --service dev-oncokb --force-new-deployment --region us-east-1
```

### Rotate Database Credentials
```bash
# Generate new password
NEW_PASS=$(openssl rand -base64 32)

# Update secret
aws secretsmanager update-secret --secret-id dev-oncokb-db-creds \
  --secret-string "{\"username\":\"admin\",\"password\":\"$NEW_PASS\"}" \
  --region us-east-1

# Update RDS password
aws rds modify-db-instance --db-instance-identifier dev-oncokb \
  --master-user-password "$NEW_PASS" --apply-immediately --region us-east-1

# Restart services to pick up new credentials
./scripts/stop-services.sh dev-oncokb-cluster us-east-1
./scripts/start-services.sh dev-oncokb-cluster us-east-1
```

### Scale Services Individually
```bash
# Scale a single service
aws ecs update-service --cluster dev-oncokb-cluster \
  --service dev-oncokb --desired-count 2 --region us-east-1

# Scale back to 0
aws ecs update-service --cluster dev-oncokb-cluster \
  --service dev-oncokb --desired-count 0 --region us-east-1
```

### Backup RDS Before Major Changes
```bash
# Create manual snapshot
aws rds create-db-snapshot --db-instance-identifier dev-oncokb \
  --db-snapshot-identifier dev-oncokb-manual-$(date +%Y%m%d-%H%M%S) \
  --region us-east-1

# Restore from snapshot (if needed)
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier dev-oncokb-restored \
  --db-snapshot-identifier dev-oncokb-manual-20260228-120000 \
  --region us-east-1
```

---

## Cleanup (Destroy Infrastructure)

### ⚠️ WARNING: This is DESTRUCTIVE and IRREVERSIBLE

```bash
# Stop all services first
./scripts/stop-services.sh dev-oncokb-cluster us-east-1

# Destroy dev environment
pixi run dev-destroy

# Confirm when prompted: type 'yes'
```

**Manual cleanup required:**
1. Delete S3 deployment bucket: `aws s3 rb s3://oncokb-deployment-data-270327054051 --force`
2. Delete S3 state bucket: `aws s3 rb s3://oncokb-tfstate-473e7965 --force`
3. Delete DynamoDB lock table: `aws dynamodb delete-table --table-name oncokb-terraform-locks`

---

## Support & Documentation

- **Terraform Docs**: [terraform/modules/README.md](modules/README.md)
- **Migration Guide**: [FARGATE_MIGRATION.md](FARGATE_MIGRATION.md)
- **OncoKB Docs**: https://docs.oncokb.org/
- **AWS ECS Fargate**: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html

### Useful Commands
```bash
# List all tasks in cluster
pixi run tf-workspace-list

# Show current state
cd terraform && terraform show

# View specific output
terraform output -raw alb_dns_name

# Refresh state (detect drift)
terraform refresh -var-file=environments/dev.tfvars

# Import existing resource
terraform import aws_ecs_cluster.this dev-oncokb-cluster
```

---

## Security Best Practices

✅ **Current Configuration:**
- RDS encrypted at rest
- S3 buckets block public access
- IAM roles follow least privilege
- Resources in private subnets
- Secrets in Secrets Manager (not code)

⚠️ **Recommended Improvements:**
- Enable EFS encryption (`encrypted = true`)
- Enable RDS backups (`backup_retention_period = 7`)
- Add HTTPS/TLS to ALB
- Enable RDS Multi-AZ for production
- Restrict EFS IAM policy from wildcard `*` to specific file system ARN
- Implement secret rotation automation
- Add AWS WAF for rate limiting
- Enable VPC Flow Logs for audit trail

---

**Last Updated**: 2026-02-28  
**Terraform Version**: 1.7+  
**AWS Provider**: 5.x
