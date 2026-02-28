#!/bin/bash
# Stop all OncoKB Fargate services (scale to zero)
# Usage: ./stop-services.sh [cluster-name] [region]

set -e

CLUSTER="${1:-dev-oncokb-cluster}"
REGION="${2:-us-east-1}"

echo "🛑 Stopping OncoKB services on cluster: $CLUSTER"

services=(
  "oncokb"
  "oncokb-transcript"
  "gn-grch37"
  "gn-grch38"
  "vep-grch37"
  "vep-grch38"
  "mongo-grch37"
  "mongo-grch38"
)

for service in "${services[@]}"; do
  echo "  ↳ Stopping dev-$service..."
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "dev-$service" \
    --desired-count 0 \
    --region "$REGION" \
    --query 'service.[serviceName,desiredCount]' \
    --output text || echo "    ⚠️  Warning: Could not stop dev-$service"
done

echo ""
echo "⏳ Waiting 30 seconds for services to stop..."
sleep 30

echo ""
echo "📊 Checking service status..."
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services $(aws ecs list-services --cluster "$CLUSTER" --region "$REGION" --query 'serviceArns' --output text) \
  --region "$REGION" \
  --query 'services[].[serviceName,runningCount,desiredCount]' \
  --output table

echo ""
echo "✅ All services stopped!"
echo "💰 Cost reduced to baseline: ~$75/month"
echo "💡 Restart with: ./start-services.sh"
