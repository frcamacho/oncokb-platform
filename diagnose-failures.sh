#!/bin/bash

# Service Failure Diagnostic Script
# Investigates why services are failing to start or stay healthy

CLUSTER="dev-oncokb-cluster"
REGION="us-east-1"

FAILED_SERVICES=(
  "dev-oncokb-transcript"
  "dev-gn-grch37"
  "dev-gn-grch38"
)

UNHEALTHY_SERVICES=(
  "dev-mongo-grch37"
  "dev-mongo-grch38"
  "dev-oncokb"
)

echo "=========================================="
echo "Service Failure Diagnostics"
echo "=========================================="
echo ""

# Function to get stopped task details
get_stopped_task_reason() {
  local SERVICE=$1
  echo "[$SERVICE] Checking stopped tasks..."
  
  STOPPED_TASKS=$(aws ecs list-tasks \
    --cluster $CLUSTER \
    --region $REGION \
    --service-name $SERVICE \
    --desired-status STOPPED \
    --query 'taskArns[0:3]' \
    --output text 2>/dev/null)
  
  if [ -n "$STOPPED_TASKS" ]; then
    for TASK_ARN in $STOPPED_TASKS; do
      echo "  Task: $(basename $TASK_ARN)"
      aws ecs describe-tasks \
        --cluster $CLUSTER \
        --region $REGION \
        --tasks $TASK_ARN \
        --query 'tasks[0].[stoppedReason,stopCode,containers[0].[exitCode,reason]]' \
        --output text 2>/dev/null | sed 's/^/    /'
    done
  else
    echo "  No stopped tasks found"
  fi
  echo ""
}

# Function to get container logs
get_container_logs() {
  local SERVICE=$1
  local LINES=${2:-30}
  
  echo "[$SERVICE] Recent logs (last $LINES lines)..."
  
  LOG_STREAM=$(aws logs describe-log-streams \
    --log-group-name "/ecs/dev-oncokb-cluster/$SERVICE" \
    --region $REGION \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text 2>/dev/null)
  
  if [ "$LOG_STREAM" != "None" ] && [ -n "$LOG_STREAM" ]; then
    aws logs get-log-events \
      --log-group-name "/ecs/dev-oncokb-cluster/$SERVICE" \
      --log-stream-name "$LOG_STREAM" \
      --region $REGION \
      --limit $LINES \
      --query 'events[*].message' \
      --output text 2>/dev/null | tail -$LINES | sed 's/^/  /'
  else
    echo "  No log streams found"
  fi
  echo ""
}

# Function to check health check configuration
get_health_check_config() {
  local SERVICE=$1
  
  echo "[$SERVICE] Health check configuration..."
  
  TASK_DEF=$(aws ecs describe-services \
    --cluster $CLUSTER \
    --region $REGION \
    --services $SERVICE \
    --query 'services[0].taskDefinition' \
    --output text 2>/dev/null)
  
  if [ -n "$TASK_DEF" ]; then
    aws ecs describe-task-definition \
      --task-definition $TASK_DEF \
      --region $REGION \
      --query 'taskDefinition.containerDefinitions[0].healthCheck' \
      --output json 2>/dev/null | jq -r 'if . == null then "  No health check configured" else . end'
  fi
  echo ""
}

# Function to check task definition details
get_task_definition_info() {
  local SERVICE=$1
  
  echo "[$SERVICE] Task definition info..."
  
  TASK_DEF=$(aws ecs describe-services \
    --cluster $CLUSTER \
    --region $REGION \
    --services $SERVICE \
    --query 'services[0].taskDefinition' \
    --output text 2>/dev/null)
  
  if [ -n "$TASK_DEF" ]; then
    echo "  Task Definition: $TASK_DEF"
    aws ecs describe-task-definition \
      --task-definition $TASK_DEF \
      --region $REGION \
      --query 'taskDefinition.[cpu,memory,containerDefinitions[0].[image,essential,dependsOn]]' \
      --output text 2>/dev/null | sed 's/^/  /'
  fi
  echo ""
}

echo "============================================"
echo "1. FAILED SERVICES (0 running tasks)"
echo "============================================"
echo ""

for SERVICE in "${FAILED_SERVICES[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "SERVICE: $SERVICE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  get_stopped_task_reason "$SERVICE"
  get_container_logs "$SERVICE" 50
  get_task_definition_info "$SERVICE"
  echo ""
done

echo "============================================"
echo "2. UNHEALTHY SERVICES (running but unhealthy)"
echo "============================================"
echo ""

for SERVICE in "${UNHEALTHY_SERVICES[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "SERVICE: $SERVICE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  get_health_check_config "$SERVICE"
  get_container_logs "$SERVICE" 30
  
  # Check running task status
  echo "[$SERVICE] Running task details..."
  TASK_ARN=$(aws ecs list-tasks \
    --cluster $CLUSTER \
    --region $REGION \
    --service-name $SERVICE \
    --query 'taskArns[0]' \
    --output text 2>/dev/null)
  
  if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    aws ecs describe-tasks \
      --cluster $CLUSTER \
      --region $REGION \
      --tasks $TASK_ARN \
      --query 'tasks[0].[lastStatus,healthStatus,containers[0].[name,healthStatus,lastStatus]]' \
      --output text 2>/dev/null | sed 's/^/  /'
  fi
  echo ""
  echo ""
done

echo "============================================"
echo "3. SERVICE DEPENDENCIES CHECK"
echo "============================================"
echo ""

# Check if services depend on each other
echo "Checking service dependencies from task definitions..."
ALL_SERVICES=("${FAILED_SERVICES[@]}" "${UNHEALTHY_SERVICES[@]}")

for SERVICE in "${ALL_SERVICES[@]}"; do
  echo "[$SERVICE] Dependencies:"
  TASK_DEF=$(aws ecs describe-services \
    --cluster $CLUSTER \
    --region $REGION \
    --services $SERVICE \
    --query 'services[0].taskDefinition' \
    --output text 2>/dev/null)
  
  if [ -n "$TASK_DEF" ]; then
    aws ecs describe-task-definition \
      --task-definition $TASK_DEF \
      --region $REGION \
      --query 'taskDefinition.containerDefinitions[0].dependsOn' \
      --output json 2>/dev/null | jq -r 'if . == null then "  None" else . end'
  fi
  echo ""
done

echo "============================================"
echo "4. NETWORK CONNECTIVITY CHECK"
echo "============================================"
echo ""

echo "Service Connect Configuration:"
for SERVICE in "${ALL_SERVICES[@]}"; do
  echo "[$SERVICE]:"
  aws ecs describe-services \
    --cluster $CLUSTER \
    --region $REGION \
    --services $SERVICE \
    --query 'services[0].serviceConnectConfiguration.[enabled,namespace]' \
    --output text 2>/dev/null | sed 's/^/  /'
done

echo ""
echo "============================================"
echo "Diagnostics Complete"
echo "============================================"
