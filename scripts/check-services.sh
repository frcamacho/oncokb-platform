#!/bin/bash
# Display status of all OncoKB ECS services and RDS.
#
# Usage:
#   ./scripts/check-services.sh [options]
#
# Options:
#   --cluster NAME    ECS cluster name  (default: $ENVIRONMENT-oncokb-cluster)
#   --region REGION   AWS region        (default: us-east-1)
#   --env ENV         Environment       (default: dev)

set -euo pipefail

REGION="us-east-1"
ENVIRONMENT="dev"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) CLUSTER="$2"; shift 2 ;;
    --region)  REGION="$2"; shift 2 ;;
    --env)     ENVIRONMENT="$2"; shift 2 ;;
    *)         echo "Unknown option: $1"; exit 1 ;;
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

echo "OncoKB Platform Status  (cluster: ${CLUSTER}, region: ${REGION})"
echo "================================================================"
echo ""

# RDS status
RDS_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS_IDENTIFIER" \
  --region "$REGION" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2>/dev/null || echo "not-found")
printf "  %-28s %s\n" "RDS (${RDS_IDENTIFIER}):" "${RDS_STATUS}"
echo ""

# ECS services
printf "  %-28s %s\n" "SERVICE" "RUNNING/DESIRED"
printf "  %-28s %s\n" "-------" "---------------"
for service in "${SERVICES[@]}"; do
  svc_name="${ENVIRONMENT}-${service}"
  info=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$svc_name" \
    --region "$REGION" \
    --query 'services[0].[runningCount,desiredCount]' \
    --output text 2>/dev/null || echo "? ?")
  running=$(echo "$info" | awk '{print $1}')
  desired=$(echo "$info" | awk '{print $2}')
  printf "  %-28s %s/%s\n" "${svc_name}" "${running}" "${desired}"
done

echo ""
echo "================================================================"
