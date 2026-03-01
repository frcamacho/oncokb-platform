#!/bin/bash
# Run EFS VEP cache initialization as a one-off ECS Fargate task.
# This launches a container with the EFS volume mounted that downloads
# and extracts VEP 98 cache data, avoiding the need for local EFS access.
#
# Prerequisites:
#   - Terraform infrastructure already applied (pixi run dev-apply)
#   - Run inside pixi shell (for terraform + aws + jq)
#   - VEP cache tarballs uploaded to S3 deployment bucket
#   - VPC private subnets must have NAT Gateway (for Docker Hub pull)
#
# Usage:
#   pixi run init-efs
#   # or: ./scripts/run-init-efs-task.sh [--env dev] [--region us-east-1]

set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
REGION="${AWS_REGION:-us-east-1}"
DEPLOYMENT_BUCKET="${DEPLOYMENT_BUCKET:-oncokb-deployment-data-270327054051}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)    ENVIRONMENT="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --bucket) DEPLOYMENT_BUCKET="$2"; shift 2 ;;
    *)        echo "Unknown option: $1"; exit 1 ;;
  esac
done

for tool in aws terraform jq; do
  if ! command -v "$tool" &>/dev/null; then
    echo "ERROR: ${tool} not found. Run inside pixi shell."
    exit 1
  fi
done

echo "=== Launch EFS VEP Cache Init Task (ECS Fargate) ==="
echo "Environment: ${ENVIRONMENT}"
echo "Region:      ${REGION}"
echo "Bucket:      ${DEPLOYMENT_BUCKET}"
echo ""

# --- 1) Gather infrastructure values from terraform outputs ---
echo "Reading terraform outputs..."
CLUSTER=$(terraform output -raw ecs_cluster_name)
EFS_ID=$(terraform output -raw efs_id)
ECS_SG=$(terraform output -raw ecs_security_group_id)
LOG_GROUP=$(terraform output -raw cloudwatch_log_group)

# --- 2) Discover subnets + IAM roles from an existing ECS service ---
echo "Discovering VPC configuration from existing ECS service..."
SVC_JSON=$(aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "${ENVIRONMENT}-mongo-grch37" \
  --region "$REGION" \
  --output json)

SUBNETS=$(echo "$SVC_JSON" | jq -r '.services[0].networkConfiguration.awsvpcConfiguration.subnets | join(",")')

TASK_DEF_ARN=$(echo "$SVC_JSON" | jq -r '.services[0].taskDefinition')
TD_JSON=$(aws ecs describe-task-definition \
  --task-definition "$TASK_DEF_ARN" \
  --region "$REGION" \
  --output json)
EXEC_ROLE_ARN=$(echo "$TD_JSON" | jq -r '.taskDefinition.executionRoleArn')
TASK_ROLE_ARN=$(echo "$TD_JSON" | jq -r '.taskDefinition.taskRoleArn')

echo "  Cluster:   ${CLUSTER}"
echo "  EFS ID:    ${EFS_ID}"
echo "  Subnets:   ${SUBNETS}"
echo "  Security:  ${ECS_SG}"
echo "  ExecRole:  ${EXEC_ROLE_ARN}"
echo "  TaskRole:  ${TASK_ROLE_ARN}"
echo ""

# --- 3) Generate pre-signed S3 URLs (4h) so the container needs no S3 permissions ---
echo "Generating pre-signed S3 URLs..."
GRCH37_TAR_URL=$(aws s3 presign \
  "s3://${DEPLOYMENT_BUCKET}/gn-vep-data/98_GRCh37.tar" \
  --expires-in 14400 --region "$REGION")
GRCH38_TAR_URL=$(aws s3 presign \
  "s3://${DEPLOYMENT_BUCKET}/gn-vep-data/98_GRCh38.tar" \
  --expires-in 14400 --region "$REGION")
echo "  URLs generated (valid 4 hours)."
echo ""

# --- 4) Register one-off task definition ---
TASK_FAMILY="${ENVIRONMENT}-oncokb-init-efs"

# Container script: pre-signed URLs are passed via run-task overrides.
read -r -d '' CONTAINER_CMD << 'INITSCRIPT' || true
set -e
echo "=== OncoKB VEP 98 Cache Init Task ==="
echo "EFS mount: /mnt/efs/vep_cache"

echo "Installing required tools..."
dnf install -y -q tar gzip

if [ ! -d /mnt/efs/vep_cache ]; then
  echo "ERROR: /mnt/efs/vep_cache does not exist. EFS volume not mounted."
  exit 1
fi

cd /mnt/efs/vep_cache

echo ""
echo "Downloading VEP 98 GRCh37 cache from S3 (this may take 10-15 min)..."
curl -fSL -o 98_GRCh37.tar "$GRCH37_TAR_URL"
echo "  GRCh37 downloaded: $(ls -lh 98_GRCh37.tar | awk '{print $5}')"

echo ""
echo "Downloading VEP 98 GRCh38 cache from S3 (this may take 10-15 min)..."
curl -fSL -o 98_GRCh38.tar "$GRCH38_TAR_URL"
echo "  GRCh38 downloaded: $(ls -lh 98_GRCh38.tar | awk '{print $5}')"

echo ""
echo "Creating cache directories..."
mkdir -p grch37 grch38

echo "Extracting GRCh37 cache..."
tar -xf 98_GRCh37.tar -C grch37/
echo "  GRCh37 extracted."

echo "Extracting GRCh38 cache..."
tar -xf 98_GRCh38.tar -C grch38/
echo "  GRCh38 extracted."

echo ""
echo "Cleaning up archive files..."
rm -f 98_GRCh37.tar 98_GRCh38.tar

echo "Setting permissions..."
chown -R 1000:1000 grch37 grch38
chmod -R 755 grch37 grch38

echo ""
echo "=== Verification ==="
echo "GRCh37 cache:"
ls -lh grch37/ | head -10
echo ""
echo "GRCh38 cache:"
ls -lh grch38/ | head -10
echo ""
echo "Disk usage:"
du -sh grch37 grch38

echo ""
echo "=== VEP Cache Initialization Complete ==="
INITSCRIPT

echo "Registering task definition: ${TASK_FAMILY}..."

TASK_DEF=$(jq -n \
  --arg family "$TASK_FAMILY" \
  --arg exec_role "$EXEC_ROLE_ARN" \
  --arg task_role "$TASK_ROLE_ARN" \
  --arg cmd "$CONTAINER_CMD" \
  --arg efs_id "$EFS_ID" \
  --arg log_group "$LOG_GROUP" \
  --arg region "$REGION" \
  '{
    family: $family,
    networkMode: "awsvpc",
    requiresCompatibilities: ["FARGATE"],
    cpu: "1024",
    memory: "4096",
    executionRoleArn: $exec_role,
    taskRoleArn: $task_role,
    runtimePlatform: {
      cpuArchitecture: "X86_64",
      operatingSystemFamily: "LINUX"
    },
    volumes: [{
      name: "vep-cache",
      efsVolumeConfiguration: {
        fileSystemId: $efs_id,
        transitEncryption: "ENABLED"
      }
    }],
    containerDefinitions: [{
      name: "init-efs",
      image: "amazonlinux:2023",
      essential: true,
      entryPoint: ["bash", "-c"],
      command: [$cmd],
      mountPoints: [{
        sourceVolume: "vep-cache",
        containerPath: "/mnt/efs/vep_cache",
        readOnly: false
      }],
      logConfiguration: {
        logDriver: "awslogs",
        options: {
          "awslogs-group": $log_group,
          "awslogs-region": $region,
          "awslogs-stream-prefix": "init-efs"
        }
      }
    }]
  }')

aws ecs register-task-definition \
  --cli-input-json "$TASK_DEF" \
  --region "$REGION" >/dev/null
echo "  Registered."
echo ""

# --- 5) Launch the task (pre-signed URLs passed as runtime overrides) ---
echo "Launching Fargate task..."

OVERRIDES=$(jq -n \
  --arg grch37_url "$GRCH37_TAR_URL" \
  --arg grch38_url "$GRCH38_TAR_URL" \
  '{
    containerOverrides: [{
      name: "init-efs",
      environment: [
        {name: "GRCH37_TAR_URL", value: $grch37_url},
        {name: "GRCH38_TAR_URL", value: $grch38_url}
      ]
    }]
  }')

RUN_RESULT=$(aws ecs run-task \
  --cluster "$CLUSTER" \
  --task-definition "$TASK_FAMILY" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${ECS_SG}],assignPublicIp=DISABLED}" \
  --overrides "$OVERRIDES" \
  --region "$REGION")

TASK_ARN=$(echo "$RUN_RESULT" | jq -r '.tasks[0].taskArn // empty')
if [ -z "$TASK_ARN" ]; then
  echo "ERROR: Failed to launch task."
  echo "$RUN_RESULT" | jq '.failures'
  exit 1
fi

TASK_ID="${TASK_ARN##*/}"
LOG_STREAM="init-efs/init-efs/${TASK_ID}"

echo "  Task ID:  ${TASK_ID}"
echo "  Task ARN: ${TASK_ARN}"
echo ""
echo "CloudWatch Logs:"
echo "  https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#logsV2:log-groups/log-group/$(echo "${LOG_GROUP}" | sed 's|/|$252F|g')/log-events/$(echo "${LOG_STREAM}" | sed 's|/|$252F|g')"
echo ""

# --- 6) Poll until complete ---
echo "Waiting for task to complete (typically 15-30 minutes)..."
echo "  Ctrl+C to stop polling — the task keeps running in AWS."
echo ""

while true; do
  TASK_DESC=$(aws ecs describe-tasks \
    --cluster "$CLUSTER" \
    --tasks "$TASK_ARN" \
    --region "$REGION" \
    --query 'tasks[0]' \
    --output json)

  STATUS=$(echo "$TASK_DESC" | jq -r '.lastStatus')
  printf "  %s  %s\n" "$(date +%H:%M:%S)" "$STATUS"

  if [ "$STATUS" = "STOPPED" ]; then
    EXIT_CODE=$(echo "$TASK_DESC" | jq -r '.containers[0].exitCode // "unknown"')
    REASON=$(echo "$TASK_DESC" | jq -r '.stoppedReason // "none"')

    echo ""
    echo "Task stopped."
    echo "  Exit code: ${EXIT_CODE}"
    echo "  Reason:    ${REASON}"
    echo ""

    echo "=== Recent Logs ==="
    aws logs get-log-events \
      --log-group-name "$LOG_GROUP" \
      --log-stream-name "$LOG_STREAM" \
      --limit 30 \
      --region "$REGION" \
      --query 'events[].message' \
      --output text 2>/dev/null || echo "(Could not fetch logs — check CloudWatch console)"

    echo ""
    if [ "$EXIT_CODE" = "0" ]; then
      echo "=== EFS VEP Cache Initialization Successful ==="
      exit 0
    else
      echo "=== EFS VEP Cache Initialization FAILED (exit code ${EXIT_CODE}) ==="
      exit 1
    fi
  fi

  sleep 30
done
