#!/bin/bash
# Stop all OncoKB Fargate services (scale to zero) and optionally stop the RDS instance.
#
# Usage:
#   ./scripts/stop-services.sh [options]
#
# Options:
#   --cluster NAME    ECS cluster name  (default: $ENVIRONMENT-oncokb-cluster)
#   --region REGION   AWS region        (default: us-east-1)
#   --env ENV         Environment       (default: dev)
#   --stop-rds        Also stop the RDS instance (use when idle > 7 days to save cost)

set -euo pipefail

REGION="us-east-1"
ENVIRONMENT="dev"
STOP_RDS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)  CLUSTER="$2"; shift 2 ;;
    --region)   REGION="$2"; shift 2 ;;
    --env)      ENVIRONMENT="$2"; shift 2 ;;
    --stop-rds) STOP_RDS=true; shift ;;
    *)          echo "Unknown option: $1"; exit 1 ;;
  esac
done

CLUSTER="${CLUSTER:-${ENVIRONMENT}-oncokb-cluster}"
RDS_IDENTIFIER="${ENVIRONMENT}-oncokb"

SERVICES=(
  "oncokb"
  "oncokb-transcript"
  "gn-grch37"
  "gn-grch38"
  "vep-grch37"
  "vep-grch38"
  "mongo-grch37"
  "mongo-grch38"
)

echo "Stopping OncoKB services on cluster: $CLUSTER (region: $REGION)"
echo ""

for service in "${SERVICES[@]}"; do
  svc_name="${ENVIRONMENT}-${service}"
  echo "  Stopping ${svc_name}..."
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$svc_name" \
    --desired-count 0 \
    --region "$REGION" \
    --query 'service.[serviceName,desiredCount]' \
    --output text 2>/dev/null || echo "  Warning: Could not stop ${svc_name}"
done

echo ""
echo "Waiting 30 seconds for tasks to drain..."
sleep 30

echo ""
echo "Service status:"
for service in "${SERVICES[@]}"; do
  svc_name="${ENVIRONMENT}-${service}"
  running=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$svc_name" \
    --region "$REGION" \
    --query 'services[0].runningCount' \
    --output text 2>/dev/null || echo "?")
  echo "  ${svc_name}: ${running} running"
done

if $STOP_RDS; then
  echo ""
  echo "=== Stopping RDS instance: ${RDS_IDENTIFIER} ==="
  echo "Note: RDS can be stopped for up to 7 days. After 7 days AWS auto-starts it."
  echo "To keep it stopped longer, re-run this script or set up a Lambda to re-stop it."

  RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_IDENTIFIER" \
    --region "$REGION" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "not-found")

  if [ "$RDS_STATUS" = "available" ]; then
    aws rds stop-db-instance \
      --db-instance-identifier "$RDS_IDENTIFIER" \
      --region "$REGION" >/dev/null
    echo "RDS stop initiated. It will take a few minutes to fully stop."
    echo ""
    echo "IMPORTANT: AWS will auto-restart the instance after 7 days."
    echo "To handle extended shutdown (>7 days), deploy the EventBridge rule:"
    echo "  1. An EventBridge rule triggers on 'RDS-EVENT-0154' (instance started)"
    echo "  2. A Lambda function checks if the tag 'keep-stopped=true' is set"
    echo "  3. If tagged, the Lambda immediately re-stops the instance"
    echo ""
    echo "To tag the instance for extended stop:"
    echo "  aws rds add-tags-to-resource \\"
    echo "    --resource-name arn:aws:rds:${REGION}:\$(aws sts get-caller-identity --query Account --output text):db:${RDS_IDENTIFIER} \\"
    echo "    --tags Key=keep-stopped,Value=true --region ${REGION}"
  elif [ "$RDS_STATUS" = "stopped" ]; then
    echo "RDS is already stopped."
  else
    echo "RDS status: ${RDS_STATUS} (cannot stop in this state)"
  fi
fi

echo ""
echo "All ECS services stopped."
if $STOP_RDS; then
  echo "Baseline cost: ~\$35/month (ECS + RDS stopped)"
else
  echo "Baseline cost: ~\$75/month (ECS stopped, RDS running)"
fi
echo "Restart with: ./scripts/start-services.sh --env ${ENVIRONMENT}"
