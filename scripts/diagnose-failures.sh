#!/bin/bash
# Diagnose ECS service failures: stopped tasks, logs, health checks.
#
# Usage:
#   ./scripts/diagnose-failures.sh [options] [service-name ...]
#
# Options:
#   --cluster NAME    ECS cluster name  (default: $ENVIRONMENT-oncokb-cluster)
#   --region REGION   AWS region        (default: us-east-1)
#   --env ENV         Environment       (default: dev)
#
# Examples:
#   ./scripts/diagnose-failures.sh                              # check all services
#   ./scripts/diagnose-failures.sh oncokb-transcript gn-grch37  # specific services
#   ./scripts/diagnose-failures.sh --env prod oncokb            # prod environment

set -euo pipefail

REGION="us-east-1"
ENVIRONMENT="dev"
TARGET_SERVICES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) CLUSTER="$2"; shift 2 ;;
    --region)  REGION="$2"; shift 2 ;;
    --env)     ENVIRONMENT="$2"; shift 2 ;;
    -*)        echo "Unknown option: $1"; exit 1 ;;
    *)         TARGET_SERVICES+=("$1"); shift ;;
  esac
done

CLUSTER="${CLUSTER:-${ENVIRONMENT}-oncokb-cluster}"

if [ ${#TARGET_SERVICES[@]} -eq 0 ]; then
  TARGET_SERVICES=(oncokb oncokb-transcript gn-grch37 gn-grch38 vep-grch37 vep-grch38 mongo-grch37 mongo-grch38)
fi

echo "OncoKB Service Diagnostics"
echo "Cluster: ${CLUSTER}  Region: ${REGION}"
echo "=========================================="
echo ""

for service in "${TARGET_SERVICES[@]}"; do
  svc_name="${ENVIRONMENT}-${service}"
  echo "--- ${svc_name} ---"

  # Current status
  info=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$svc_name" \
    --region "$REGION" \
    --query 'services[0].[runningCount,desiredCount,deployments[0].rolloutState]' \
    --output text 2>/dev/null || echo "? ? ?")
  echo "  Status: ${info}"

  # Recent events
  echo "  Recent events:"
  aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$svc_name" \
    --region "$REGION" \
    --query 'services[0].events[0:3].[createdAt,message]' \
    --output text 2>/dev/null | sed 's/^/    /' || echo "    (none)"

  # Stopped tasks
  STOPPED_TASKS=$(aws ecs list-tasks \
    --cluster "$CLUSTER" \
    --service-name "$svc_name" \
    --desired-status STOPPED \
    --region "$REGION" \
    --query 'taskArns[0:2]' \
    --output text 2>/dev/null)

  if [ -n "$STOPPED_TASKS" ] && [ "$STOPPED_TASKS" != "None" ]; then
    echo "  Stopped tasks:"
    for task_arn in $STOPPED_TASKS; do
      aws ecs describe-tasks \
        --cluster "$CLUSTER" \
        --tasks "$task_arn" \
        --region "$REGION" \
        --query 'tasks[0].[stoppedReason,stopCode,containers[0].[exitCode,reason]]' \
        --output text 2>/dev/null | sed 's/^/    /'
    done
  fi

  # Recent logs
  LOG_GROUP="/ecs/oncokb/${ENVIRONMENT}"
  LOG_STREAM=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --log-stream-name-prefix "${service}" \
    --region "$REGION" \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text 2>/dev/null)

  if [ -n "$LOG_STREAM" ] && [ "$LOG_STREAM" != "None" ]; then
    echo "  Last 10 log lines:"
    aws logs get-log-events \
      --log-group-name "$LOG_GROUP" \
      --log-stream-name "$LOG_STREAM" \
      --region "$REGION" \
      --limit 10 \
      --query 'events[*].message' \
      --output text 2>/dev/null | sed 's/^/    /' || echo "    (no logs)"
  fi

  echo ""
done

echo "=========================================="
echo "Diagnostics complete."
