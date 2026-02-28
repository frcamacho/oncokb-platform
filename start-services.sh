#!/bin/bash
# Start all OncoKB Fargate services
# Usage: ./start-services.sh [cluster-name] [region]

set -e

CLUSTER="${1:-dev-oncokb-cluster}"
REGION="${2:-us-east-1}"

echo "🚀 Starting OncoKB services on cluster: $CLUSTER"

# Start all services
services=(
  "oncokb:2"
  "oncokb-transcript:1"
  "gn-grch37:1"
  "gn-grch38:1"
  "vep-grch37:1"
  "vep-grch38:1"
  "mongo-grch37:1"
  "mongo-grch38:1"
)

for service_def in "${services[@]}"; do
  service="${service_def%%:*}"
  count="${service_def#*:}"
  
  echo "  ↳ Starting dev-$service (desired count: $count)..."
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "dev-$service" \
    --desired-count "$count" \
    --region "$REGION" \
    --query 'service.[serviceName,desiredCount,runningCount]' \
    --output text || echo "    ⚠️  Warning: Could not start dev-$service"
done

echo ""
echo "⏳ Waiting 90 seconds for services to start..."
sleep 90

echo ""
echo "📊 Checking service status..."
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services $(aws ecs list-services --cluster "$CLUSTER" --region "$REGION" --query 'serviceArns' --output text) \
  --region "$REGION" \
  --query 'services[].[serviceName,runningCount,desiredCount]' \
  --output table

echo ""
echo "✅ Services started! Endpoint: http://oncokb.cggt-dev.vrtx.com"
echo "💡 Tip: Test with: curl http://oncokb.cggt-dev.vrtx.com/api/v1/info"
