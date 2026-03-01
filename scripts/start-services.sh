#!/bin/bash
# Start all OncoKB Fargate services in dependency order.
# Starts RDS first if it is stopped, then tiers of ECS services.
#
# Usage:
#   ./scripts/start-services.sh [options]
#
# Options:
#   --cluster NAME    ECS cluster name  (default: $ENVIRONMENT-oncokb-cluster)
#   --region REGION   AWS region        (default: us-east-1)
#   --env ENV         Environment       (default: dev)
#
# Dependency chain:
#   Tier 0: RDS (must be available before any service)
#   Tier 1: mongo-grch37, mongo-grch38, vep-grch37, vep-grch38 (no deps)
#   Tier 2: gn-grch37, gn-grch38 (needs mongo+vep), oncokb-transcript (needs RDS)
#   Tier 3: oncokb (needs gn+transcript)

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

start_service() {
  local service="$1"
  local count="${2:-1}"
  local svc_name="${ENVIRONMENT}-${service}"
  echo "  Starting ${svc_name} (desired: ${count})..."
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$svc_name" \
    --desired-count "$count" \
    --region "$REGION" \
    --query 'service.[serviceName,desiredCount,runningCount]' \
    --output text || echo "  Warning: Could not start ${svc_name}"
}

wait_for_healthy() {
  local services=("$@")
  local max_wait=300
  local elapsed=0
  local interval=15

  echo "  Waiting for services to reach running state (up to ${max_wait}s)..."
  while [ $elapsed -lt $max_wait ]; do
    local all_healthy=true
    for svc in "${services[@]}"; do
      local svc_name="${ENVIRONMENT}-${svc}"
      local running
      running=$(aws ecs describe-services \
        --cluster "$CLUSTER" \
        --services "$svc_name" \
        --region "$REGION" \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null)
      if [ "$running" = "0" ] || [ "$running" = "None" ]; then
        all_healthy=false
        break
      fi
    done

    if $all_healthy; then
      echo "  All services in tier are running."
      return 0
    fi

    sleep "$interval"
    elapsed=$((elapsed + interval))
    echo "  ...waiting (${elapsed}s elapsed)"
  done

  echo "  Warning: Timed out waiting for services. Continuing..."
  return 0
}

echo "Starting OncoKB services on cluster: $CLUSTER (region: $REGION)"
echo ""

# === Tier 0: Ensure RDS is available ===
echo "=== Tier 0: RDS Database ==="
RDS_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS_IDENTIFIER" \
  --region "$REGION" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2>/dev/null || echo "not-found")

if [ "$RDS_STATUS" = "stopped" ]; then
  echo "  RDS is stopped. Starting ${RDS_IDENTIFIER}..."
  aws rds start-db-instance \
    --db-instance-identifier "$RDS_IDENTIFIER" \
    --region "$REGION" >/dev/null
  echo "  Waiting for RDS to become available (this may take 5-10 minutes)..."
  aws rds wait db-instance-available \
    --db-instance-identifier "$RDS_IDENTIFIER" \
    --region "$REGION"
  echo "  RDS is now available."
elif [ "$RDS_STATUS" = "available" ]; then
  echo "  RDS is already available."
else
  echo "  RDS status: ${RDS_STATUS}. Waiting for availability..."
  aws rds wait db-instance-available \
    --db-instance-identifier "$RDS_IDENTIFIER" \
    --region "$REGION" || echo "  Warning: RDS wait timed out (status: ${RDS_STATUS})"
fi
echo ""

# === Tier 1: Data stores and VEP ===
echo "=== Tier 1: Data stores and VEP (no dependencies) ==="
start_service "mongo-grch37" 1
start_service "mongo-grch38" 1
start_service "vep-grch37" 1
start_service "vep-grch38" 1
echo ""
wait_for_healthy "mongo-grch37" "mongo-grch38" "vep-grch37" "vep-grch38"
echo ""

# === Tier 2: Genome Nexus + Transcript ===
echo "=== Tier 2: Genome Nexus + Transcript (needs Tier 1 + RDS) ==="
start_service "gn-grch37" 1
start_service "gn-grch38" 1
start_service "oncokb-transcript" 1
echo ""
wait_for_healthy "gn-grch37" "gn-grch38" "oncokb-transcript"
echo ""

# === Tier 3: OncoKB API ===
echo "=== Tier 3: OncoKB API (needs Tier 2) ==="
start_service "oncokb" 1
echo ""
wait_for_healthy "oncokb"
echo ""

echo "=== Final status ==="
for svc in mongo-grch37 mongo-grch38 vep-grch37 vep-grch38 gn-grch37 gn-grch38 oncokb-transcript oncokb; do
  svc_name="${ENVIRONMENT}-${svc}"
  info=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$svc_name" \
    --region "$REGION" \
    --query 'services[0].[serviceName,runningCount,desiredCount]' \
    --output text 2>/dev/null)
  echo "  ${info}"
done

echo ""
echo "Services started. Test with:"
echo "  curl http://\$(terraform output -raw alb_dns_name)/api/v1/info"
