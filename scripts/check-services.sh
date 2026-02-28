#!/bin/bash
# check-services.sh
# Displays current status of all OncoKB ECS services

REGION="us-east-1"
CLUSTER="dev-oncokb-cluster"

SERVICES=(
  "dev-oncokb"
  "dev-oncokb-transcript"
  "dev-gn-grch37"
  "dev-gn-grch38"
  "dev-vep-grch37"
  "dev-vep-grch38"
  "dev-mongo-grch37"
  "dev-mongo-grch38"
)

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  OncoKB ECS Services Status                                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

for SERVICE in "${SERVICES[@]}"; do
  aws ecs describe-services \
    --cluster $CLUSTER \
    --services $SERVICE \
    --region $REGION \
    --query 'services[0].{Service:serviceName,Running:runningCount,Desired:desiredCount,Status:status}' \
    --output table 2>/dev/null || echo "⚠️  $SERVICE not found"
done
