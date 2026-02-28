#!/bin/bash

# Configuration Inspection Script
# Validates actual deployed configuration vs terraform expectations

CLUSTER="dev-oncokb-cluster"
REGION="us-east-1"

echo "=========================================="
echo "Configuration Inspection"
echo "=========================================="
echo ""

echo "1. CloudWatch Log Groups Check"
echo "----------------------------------------"
aws logs describe-log-groups \
  --region $REGION \
  --log-group-name-prefix "/ecs/dev-oncokb-cluster" \
  --query 'logGroups[*].[logGroupName,storedBytes]' \
  --output table

echo ""
echo "2. Service Connect Namespace Check"
echo "----------------------------------------"
aws servicediscovery list-namespaces \
  --region $REGION \
  --query 'Namespaces[*].[Name,Id,Type]' \
  --output table

echo ""
echo "3. Task Definition Details (Logging & Dependencies)"
echo "----------------------------------------"

# Get current task definitions from running services
SERVICES=(
  "dev-oncokb-transcript"
  "dev-gn-grch37"
  "dev-gn-grch38"
  "dev-mongo-grch37"
  "dev-mongo-grch38"
  "dev-oncokb"
)

for SERVICE in "${SERVICES[@]}"; do
  echo ""
  echo "[$SERVICE]"
  
  TASK_DEF_ARN=$(aws ecs describe-services \
    --cluster $CLUSTER \
    --region $REGION \
    --services $SERVICE \
    --query 'services[0].taskDefinition' \
    --output text 2>/dev/null)
  
  if [ -n "$TASK_DEF_ARN" ] && [ "$TASK_DEF_ARN" != "None" ]; then
    echo "  Task Definition: $TASK_DEF_ARN"
    
    # Check log configuration
    echo "  Log Config:"
    aws ecs describe-task-definition \
      --task-definition $TASK_DEF_ARN \
      --region $REGION \
      --query 'taskDefinition.containerDefinitions[0].logConfiguration' \
      --output json 2>/dev/null | jq -r 'if . == null then "    Not configured" else . end' | sed 's/^/    /'
    
    # Check environment variables
    echo "  Environment Variables:"
    aws ecs describe-task-definition \
      --task-definition $TASK_DEF_ARN \
      --region $REGION \
      --query 'taskDefinition.containerDefinitions[0].environment[*].[name,value]' \
      --output text 2>/dev/null | sed 's/^/    /' | head -10
    
    # Check secrets
    echo "  Secrets:"
    aws ecs describe-task-definition \
      --task-definition $TASK_DEF_ARN \
      --region $REGION \
      --query 'taskDefinition.containerDefinitions[0].secrets[*].name' \
      --output text 2>/dev/null | sed 's/^/    /' || echo "    None"
  else
    echo "  Could not retrieve task definition"
  fi
done

echo ""
echo ""
echo "4. Check Secrets Manager Access"
echo "----------------------------------------"
echo "Checking if RDS secret exists and is accessible..."
SECRET_ARN=$(aws ecs describe-task-definition \
  --task-definition dev-oncokb-transcript:5 \
  --region $REGION \
  --query 'taskDefinition.containerDefinitions[0].secrets[0].valueFrom' \
  --output text 2>/dev/null | cut -d: -f1-7)

if [ -n "$SECRET_ARN" ]; then
  echo "Secret ARN: $SECRET_ARN"
  aws secretsmanager describe-secret \
    --secret-id "$SECRET_ARN" \
    --region $REGION \
    --query '[Name,Description,LastAccessedDate]' \
    --output text 2>/dev/null | sed 's/^/  /' || echo "  ERROR: Cannot access secret"
fi

echo ""
echo "5. Check IAM Task Execution Role Permissions"
echo "----------------------------------------"
EXEC_ROLE=$(aws ecs describe-task-definition \
  --task-definition dev-oncokb-transcript:5 \
  --region $REGION \
  --query 'taskDefinition.executionRoleArn' \
  --output text 2>/dev/null)

if [ -n "$EXEC_ROLE" ]; then
  echo "Execution Role: $EXEC_ROLE"
  ROLE_NAME=$(echo $EXEC_ROLE | awk -F'/' '{print $NF}')
  echo "Attached Policies:"
  aws iam list-attached-role-policies \
    --role-name "$ROLE_NAME" \
    --region $REGION \
    --query 'AttachedPolicies[*].PolicyName' \
    --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/  /' || echo "  Could not list policies"
fi

echo ""
echo "6. Recent Task Failures with Details"
echo "----------------------------------------"
for SERVICE in dev-oncokb-transcript dev-gn-grch37 dev-gn-grch38; do
  echo ""
  echo "[$SERVICE] - Last stopped task:"
  
  TASK_ARN=$(aws ecs list-tasks \
    --cluster $CLUSTER \
    --region $REGION \
    --service-name $SERVICE \
    --desired-status STOPPED \
    --query 'taskArns[0]' \
    --output text 2>/dev/null)
  
  if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
    aws ecs describe-tasks \
      --cluster $CLUSTER \
      --region $REGION \
      --tasks $TASK_ARN \
      --query 'tasks[0].[stoppedAt,stoppedReason,stopCode,containers[0].[name,exitCode,reason]]' \
      --output json 2>/dev/null | jq . | sed 's/^/  /'
  fi
done

echo ""
echo "=========================================="
echo "Configuration Inspection Complete"
echo "=========================================="
