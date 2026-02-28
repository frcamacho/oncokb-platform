#!/bin/bash

# Service Health Check Script for dev-oncokb-cluster
# Checks service availability and health endpoints

CLUSTER="dev-oncokb-cluster"
REGION="us-east-1"

echo "=========================================="
echo "ECS Service Health Check"
echo "=========================================="
echo ""

# Get all services
SERVICES=(
  "dev-vep-grch38"
  "dev-vep-grch37"
  "dev-oncokb-transcript"
  "dev-oncokb"
  "dev-mongo-grch37"
  "dev-mongo-grch38"
  "dev-gn-grch37"
  "dev-gn-grch38"
)

echo "1. Service Status Check"
echo "----------------------------------------"
for SERVICE in "${SERVICES[@]}"; do
  echo -n "Checking $SERVICE... "
  
  SERVICE_INFO=$(aws ecs describe-services \
    --cluster $CLUSTER \
    --region $REGION \
    --services $SERVICE \
    --query 'services[0].[runningCount,desiredCount,deployments[0].rolloutState]' \
    --output text 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    RUNNING=$(echo $SERVICE_INFO | awk '{print $1}')
    DESIRED=$(echo $SERVICE_INFO | awk '{print $2}')
    STATE=$(echo $SERVICE_INFO | awk '{print $3}')
    
    if [ "$RUNNING" = "$DESIRED" ] && [ "$RUNNING" != "0" ]; then
      echo "✓ OK ($RUNNING/$DESIRED) - $STATE"
    elif [ "$RUNNING" = "0" ]; then
      echo "✗ FAILED ($RUNNING/$DESIRED) - Service not running"
    else
      echo "⚠ DEGRADED ($RUNNING/$DESIRED) - $STATE"
    fi
  else
    echo "✗ ERROR - Could not query service"
  fi
done

echo ""
echo "2. Recent Service Events (Last 3 per service)"
echo "----------------------------------------"
for SERVICE in "${SERVICES[@]}"; do
  echo "$SERVICE:"
  aws ecs describe-services \
    --cluster $CLUSTER \
    --region $REGION \
    --services $SERVICE \
    --query 'services[0].events[0:3].[createdAt,message]' \
    --output text 2>/dev/null | sed 's/^/  /' || echo "  Could not fetch events"
  echo ""
done

echo "3. Task Health Check (for running services)"
echo "----------------------------------------"
for SERVICE in "${SERVICES[@]}"; do
  TASK_ARN=$(aws ecs list-tasks \
    --cluster $CLUSTER \
    --region $REGION \
    --service-name $SERVICE \
    --query 'taskArns[0]' \
    --output text 2>/dev/null)
  
  if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    echo "$SERVICE task:"
    aws ecs describe-tasks \
      --cluster $CLUSTER \
      --region $REGION \
      --tasks $TASK_ARN \
      --query 'tasks[0].[lastStatus,healthStatus,containers[0].lastStatus]' \
      --output text 2>/dev/null | sed 's/^/  Status: /' || echo "  Could not fetch task details"
  fi
done

echo ""
echo "4. CloudWatch Logs Check (Last 20 lines)"
echo "----------------------------------------"
echo "Recent errors from services:"
aws logs filter-log-events \
  --log-group-name "/ecs/dev-oncokb-cluster" \
  --region $REGION \
  --start-time $(($(date +%s) - 600))000 \
  --filter-pattern "ERROR" \
  --query 'events[0:20].[logStreamName,message]' \
  --output text 2>/dev/null | head -20 || echo "No recent errors or could not access logs"

echo ""
echo "=========================================="
echo "Health Check Complete"
echo "=========================================="
