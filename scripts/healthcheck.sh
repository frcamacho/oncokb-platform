#!/bin/bash
# OncoKB Platform Health Check
# Monitors all services and reports status

set -e

ONCOKB_DIR="${ONCOKB_DIR:-/opt/oncokb}"

echo "=== OncoKB Platform Health Check ==="
echo "Date: $(date)"
echo ""

# Load environment variables
if [ -f "${ONCOKB_DIR}/.env" ]; then
    source "${ONCOKB_DIR}/.env"
fi

# Check Docker Compose services
echo "[1/6] Docker Container Status"
echo "----------------------------"
cd "${ONCOKB_DIR}"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"

UNHEALTHY=$(docker compose ps | grep -v "Up" | grep -v "NAME" | wc -l)
if [ "${UNHEALTHY}" -gt 0 ]; then
    echo "⚠️  ALERT: ${UNHEALTHY} unhealthy container(s) detected!"
else
    echo "✅ OK: All containers running"
fi

# Check OncoKB API
echo ""
echo "[2/6] OncoKB API"
echo "----------------------------"
if curl -sf http://localhost:8080/api/v1/info > /dev/null 2>&1; then
    VERSION=$(curl -s http://localhost:8080/api/v1/info | jq -r '.version' 2>/dev/null || echo "unknown")
    echo "✅ OK: OncoKB API responding (version: ${VERSION})"
else
    echo "❌ ALERT: OncoKB API is down or not responding"
fi

# Check OncoKB Transcript API
echo ""
echo "[3/6] OncoKB Transcript API"
echo "----------------------------"
if curl -sf http://localhost:9090/actuator/health > /dev/null 2>&1; then
    echo "✅ OK: OncoKB Transcript API responding"
else
    echo "❌ ALERT: OncoKB Transcript API is down or not responding"
fi

# Check Genome Nexus APIs
echo ""
echo "[4/6] Genome Nexus APIs"
echo "----------------------------"
if curl -sf http://localhost:8888/health > /dev/null 2>&1; then
    echo "✅ OK: Genome Nexus GRCh37 responding"
else
    echo "❌ ALERT: Genome Nexus GRCh37 is down"
fi

if curl -sf http://localhost:8889/health > /dev/null 2>&1; then
    echo "✅ OK: Genome Nexus GRCh38 responding"
else
    echo "❌ ALERT: Genome Nexus GRCh38 is down"
fi

# Check RDS connectivity
echo ""
echo "[5/6] RDS MySQL Database"
echo "----------------------------"
if [ -n "${RDS_ENDPOINT}" ] && [ -n "${RDS_USERNAME}" ] && [ -n "${RDS_PASSWORD}" ]; then
    RDS_HOST=$(echo "${RDS_ENDPOINT}" | cut -d: -f1)
    if mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -p"${RDS_PASSWORD}" -e "SELECT 1" > /dev/null 2>&1; then
        echo "✅ OK: RDS MySQL is accessible"
    else
        echo "❌ ALERT: RDS MySQL connection failed"
    fi
else
    echo "⚠️  SKIP: RDS credentials not found in environment"
fi

# Check disk space
echo ""
echo "[6/6] Disk Space"
echo "----------------------------"
ROOT_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "${ROOT_USAGE}" -gt 80 ]; then
    echo "⚠️  ALERT: Root disk is ${ROOT_USAGE}% full (threshold: 80%)"
else
    echo "✅ OK: Root disk usage: ${ROOT_USAGE}%"
fi

if mountpoint -q /mnt/efs/vep_cache 2>/dev/null; then
    EFS_USAGE=$(df -h /mnt/efs/vep_cache | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "${EFS_USAGE}" -gt 80 ]; then
        echo "⚠️  ALERT: EFS is ${EFS_USAGE}% full (threshold: 80%)"
    else
        echo "✅ OK: EFS usage: ${EFS_USAGE}%"
    fi
else
    echo "⚠️  SKIP: EFS not mounted at /mnt/efs/vep_cache"
fi

# Memory usage
echo ""
echo "Memory Usage:"
free -h | awk 'NR==2 {print "  Used: " $3 " / Total: " $2 " (" int($3/$2*100) "%)"}'

# Container resource usage
echo ""
echo "Container Resource Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -n 10

echo ""
echo "=== End Health Check ==="
