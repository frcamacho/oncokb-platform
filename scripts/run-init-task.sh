#!/bin/bash
# Run RDS database initialization as a one-off ECS Fargate task.
# This launches a container inside the VPC that can reach the private RDS instance,
# avoiding the need for VPN or bastion hosts.
#
# Prerequisites:
#   - Terraform infrastructure already applied (pixi run dev-apply)
#   - Run inside pixi shell (for terraform + aws + jq)
#   - VPC private subnets must have NAT Gateway (for Docker Hub pull + package install)
#
# Usage:
#   pixi run init-rds
#   # or: ./scripts/run-init-task.sh [--env dev] [--region us-east-1]

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

echo "=== Launch RDS Init Task (ECS Fargate) ==="
echo "Environment: ${ENVIRONMENT}"
echo "Region:      ${REGION}"
echo ""

# --- 1) Gather infrastructure values from terraform outputs ---
echo "Reading terraform outputs..."
CLUSTER=$(terraform output -raw ecs_cluster_name)
DB_SECRET_ARN=$(terraform output -raw db_secret_arn)
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
echo "  Subnets:   ${SUBNETS}"
echo "  Security:  ${ECS_SG}"
echo "  ExecRole:  ${EXEC_ROLE_ARN}"
echo "  TaskRole:  ${TASK_ROLE_ARN}"
echo "  Secret:    ${DB_SECRET_ARN}"
echo ""

# --- 3) Generate pre-signed S3 URLs (2h) so the container needs no S3 permissions ---
echo "Generating pre-signed S3 URLs..."
ONCOKB_SQL_URL=$(aws s3 presign \
  "s3://${DEPLOYMENT_BUCKET}/sql/oncokb_v4_27.sql.gz" \
  --expires-in 7200 --region "$REGION")
TRANSCRIPT_SQL_URL=$(aws s3 presign \
  "s3://${DEPLOYMENT_BUCKET}/sql/oncokb_transcript_v4_27.sql.gz" \
  --expires-in 7200 --region "$REGION")
echo "  URLs generated (valid 2 hours)."
echo ""

# --- 4) Register one-off task definition ---
TASK_FAMILY="${ENVIRONMENT}-oncokb-init-rds"

# Container script: DB creds are injected by ECS from Secrets Manager as env vars.
# Pre-signed URLs are passed via run-task overrides. No aws/jq needed inside container.
read -r -d '' CONTAINER_CMD << 'INITSCRIPT' || true
set -e
echo "=== OncoKB RDS Init Task ==="
echo "RDS Host: ${RDS_HOST}:${RDS_PORT}"

echo "Installing curl..."
microdnf install -y curl gzip 2>/dev/null \
  || { apt-get update -qq && apt-get install -y -qq --no-install-recommends curl gzip >/dev/null 2>&1; }

cd /tmp

echo ""
echo "Downloading oncokb SQL dump..."
curl -fsSL -o oncokb.sql.gz "$ONCOKB_SQL_URL"
echo "Downloading oncokb_transcript SQL dump..."
curl -fsSL -o transcript.sql.gz "$TRANSCRIPT_SQL_URL"

echo "Decompressing..."
gunzip -f oncokb.sql.gz transcript.sql.gz
ls -lh /tmp/*.sql

export MYSQL_PWD="$RDS_PASSWORD"

echo ""
echo "Switching authentication plugin to mysql_native_password..."
mysql -h "$RDS_HOST" -u "$RDS_USERNAME" -P "$RDS_PORT" -e \
  "ALTER USER '$RDS_USERNAME'@'%' IDENTIFIED WITH mysql_native_password BY '$RDS_PASSWORD';"

echo ""
echo "Creating databases..."
mysql -h "$RDS_HOST" -u "$RDS_USERNAME" -P "$RDS_PORT" -e \
  "CREATE DATABASE IF NOT EXISTS oncokb; CREATE DATABASE IF NOT EXISTS oncokb_transcript; SHOW DATABASES;"

echo ""
echo "Loading oncokb database (15-25 min)..."
mysql -h "$RDS_HOST" -u "$RDS_USERNAME" -P "$RDS_PORT" oncokb < /tmp/oncokb.sql
echo "  oncokb loaded."

echo ""
echo "Loading oncokb_transcript database (5-10 min)..."
mysql -h "$RDS_HOST" -u "$RDS_USERNAME" -P "$RDS_PORT" oncokb_transcript < /tmp/transcript.sql
echo "  oncokb_transcript loaded."

echo ""
echo "=== Verification ==="
echo -n "oncokb tables: "
mysql -h "$RDS_HOST" -u "$RDS_USERNAME" -P "$RDS_PORT" oncokb -N -e \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='oncokb';"
mysql -h "$RDS_HOST" -u "$RDS_USERNAME" -P "$RDS_PORT" oncokb -e \
  "SELECT COUNT(*) AS gene_count FROM gene;"
echo -n "oncokb_transcript tables: "
mysql -h "$RDS_HOST" -u "$RDS_USERNAME" -P "$RDS_PORT" oncokb_transcript -N -e \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='oncokb_transcript';"
echo -n "checking info table verification: "
mysql -h "$RDS_HOST" -u "$RDS_USERNAME" -P "$RDS_PORT" oncokb -N -e \
  "SELECT data_version, data_version_date FROM info;"

echo ""
echo "=== RDS Init Complete ==="
INITSCRIPT

echo "Registering task definition: ${TASK_FAMILY}..."

# Build the JSON with jq to handle all escaping correctly
TASK_DEF=$(jq -n \
  --arg family "$TASK_FAMILY" \
  --arg exec_role "$EXEC_ROLE_ARN" \
  --arg task_role "$TASK_ROLE_ARN" \
  --arg cmd "$CONTAINER_CMD" \
  --arg secret_arn "$DB_SECRET_ARN" \
  --arg log_group "$LOG_GROUP" \
  --arg region "$REGION" \
  '{
    family: $family,
    networkMode: "awsvpc",
    requiresCompatibilities: ["FARGATE"],
    cpu: "1024",
    memory: "2048",
    executionRoleArn: $exec_role,
    taskRoleArn: $task_role,
    runtimePlatform: {
      cpuArchitecture: "X86_64",
      operatingSystemFamily: "LINUX"
    },
    containerDefinitions: [{
      name: "init-rds",
      image: "mysql:8.0",
      essential: true,
      entryPoint: ["bash", "-c"],
      command: [$cmd],
      secrets: [
        {name: "RDS_PASSWORD", valueFrom: ($secret_arn + ":password::")},
        {name: "RDS_USERNAME", valueFrom: ($secret_arn + ":username::")},
        {name: "RDS_HOST",     valueFrom: ($secret_arn + ":host::")},
        {name: "RDS_PORT",     valueFrom: ($secret_arn + ":port::")}
      ],
      logConfiguration: {
        logDriver: "awslogs",
        options: {
          "awslogs-group": $log_group,
          "awslogs-region": $region,
          "awslogs-stream-prefix": "init-rds"
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
  --arg sql_url "$ONCOKB_SQL_URL" \
  --arg tx_url "$TRANSCRIPT_SQL_URL" \
  '{
    containerOverrides: [{
      name: "init-rds",
      environment: [
        {name: "ONCOKB_SQL_URL", value: $sql_url},
        {name: "TRANSCRIPT_SQL_URL", value: $tx_url}
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
LOG_STREAM="init-rds/init-rds/${TASK_ID}"

echo "  Task ID:  ${TASK_ID}"
echo "  Task ARN: ${TASK_ARN}"
echo ""
echo "CloudWatch Logs:"
echo "  https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#logsV2:log-groups/log-group/$(echo "${LOG_GROUP}" | sed 's|/|$252F|g')/log-events/$(echo "${LOG_STREAM}" | sed 's|/|$252F|g')"
echo ""

# --- 6) Poll until complete ---
echo "Waiting for task to complete (typically 20-40 minutes)..."
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
      echo "=== RDS Initialization Successful ==="
      exit 0
    else
      echo "=== RDS Initialization FAILED (exit code ${EXIT_CODE}) ==="
      exit 1
    fi
  fi

  sleep 30
done
