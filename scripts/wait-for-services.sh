#!/bin/bash

# Quick Service Health Test
# Run after deployment to verify services are healthy

CLUSTER="dev-oncokb-cluster"
REGION="us-east-1"

echo "Testing OncoKB Platform Services..."
echo ""

# Wait for services to stabilize
for i in {1..6}; do
    echo -n "⏳ Checking service status (attempt $i/6)..."
    
    STATUS=$(aws ecs describe-services \
        --cluster $CLUSTER \
        --region $REGION \
        --services dev-gn-grch37 dev-gn-grch38 dev-oncokb-transcript dev-oncokb \
        --query 'services[*].[serviceName,runningCount,desiredCount]' \
        --output text 2>/dev/null)
    
    RUNNING=$(echo "$STATUS" | awk '{s+=$2} END {print s}')
    DESIRED=$(echo "$STATUS" | awk '{s+=$3} END {print s}')
    
    echo " ($RUNNING/$DESIRED running)"
    
    if [ "$RUNNING" = "$DESIRED" ]; then
        echo "✓ All services running!"
        break
    fi
    
    if [ $i -lt 6 ]; then
        sleep 30
    fi
done

echo ""
echo "Detailed Status:"
./scripts/test-services.sh
