#!/bin/bash
# Initialize RDS MySQL databases with OncoKB data
# Run from a host with: AWS CLI, mysql client, and network access to RDS (VPC/VPN).
# Do NOT run inside the OncoKB container (it has no mysql/aws cli).

set -e

DEPLOYMENT_BUCKET="${DEPLOYMENT_BUCKET:-oncokb-deployment-data-270327054051}"
WORK_DIR="${WORK_DIR:-/tmp/oncokb-init}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "=== OncoKB RDS Database Initialization ==="

# 1) Load from .env if present (e.g. when run from a prepared host)
if [ -f /opt/oncokb/.env ]; then
  echo "Loading /opt/oncokb/.env"
  set -a
  source /opt/oncokb/.env
  set +a
fi

# 2) If RDS credentials not set, fetch from AWS Secrets Manager
if [ -z "${RDS_ENDPOINT}" ] || [ -z "${RDS_USERNAME}" ] || [ -z "${RDS_PASSWORD}" ]; then
  if [ -n "${DB_SECRET_ARN}" ] || [ -n "${ONCOKB_DB_SECRET_ARN}" ]; then
    SECRET_ARN="${DB_SECRET_ARN:-$ONCOKB_DB_SECRET_ARN}"
    echo "Fetching credentials from Secrets Manager: ${SECRET_ARN}"
    SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "${SECRET_ARN}" --region "${AWS_REGION}" --query SecretString --output text)
    RDS_USERNAME=$(echo "${SECRET_JSON}" | jq -r .username)
    RDS_PASSWORD=$(echo "${SECRET_JSON}" | jq -r .password)
    RDS_HOST=$(echo "${SECRET_JSON}" | jq -r .host)
    RDS_PORT=$(echo "${SECRET_JSON}" | jq -r '.port // 3306')
    RDS_ENDPOINT="${RDS_HOST}:${RDS_PORT}"
  fi
fi

# 3) Require credentials and tools
if [ -z "${RDS_ENDPOINT}" ] || [ -z "${RDS_USERNAME}" ] || [ -z "${RDS_PASSWORD}" ]; then
  echo "ERROR: RDS credentials not set. Either:"
  echo "  - Export DB_SECRET_ARN (or ONCOKB_DB_SECRET_ARN) and AWS_REGION to pull from Secrets Manager, or"
  echo "  - Export RDS_ENDPOINT, RDS_USERNAME, RDS_PASSWORD (or use /opt/oncokb/.env)"
  echo "Example:"
  echo "  export DB_SECRET_ARN=\$(terraform output -raw db_secret_arn)"
  echo "  export AWS_REGION=us-east-1"
  echo "  ./scripts/init-rds-databases.sh"
  exit 1
fi

RDS_HOST=$(echo "${RDS_ENDPOINT}" | cut -d: -f1)
echo "RDS Host: ${RDS_HOST}"
echo "RDS User: ${RDS_USERNAME}"

if ! command -v mysql &>/dev/null; then
  echo "ERROR: mysql client not found. Install it (e.g. brew install mysql-client, or apt install mysql-client)"
  exit 1
fi
if ! command -v aws &>/dev/null; then
  echo "ERROR: AWS CLI not found. Install it and configure credentials."
  exit 1
fi

# Create working directory
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# Download SQL dumps from S3
echo ""
echo "Downloading SQL dumps from S3..."
aws s3 cp "s3://${DEPLOYMENT_BUCKET}/sql/oncokb_v4_27.sql.gz" . --no-progress
aws s3 cp "s3://${DEPLOYMENT_BUCKET}/sql/oncokb_transcript_v4_27.sql.gz" . --no-progress

echo "Decompressing..."
gunzip -f oncokb_v4_27.sql.gz oncokb_transcript_v4_27.sql.gz

# Create databases and load data (use MYSQL_PWD to avoid password in argv)
export MYSQL_PWD="${RDS_PASSWORD}"

echo ""
echo "Creating databases..."
mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -P "${RDS_PORT:-3306}" <<EOF
CREATE DATABASE IF NOT EXISTS oncokb;
CREATE DATABASE IF NOT EXISTS oncokb_transcript;
SHOW DATABASES;
EOF

echo ""
echo "Loading oncokb database (15-25 minutes)..."
mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -P "${RDS_PORT:-3306}" oncokb < oncokb_v4_27.sql

echo ""
echo "Loading oncokb_transcript database (5-10 minutes)..."
mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -P "${RDS_PORT:-3306}" oncokb_transcript < oncokb_transcript_v4_27.sql

echo ""
echo "=== Verification ==="
mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -P "${RDS_PORT:-3306}" oncokb -e "SHOW TABLES;" | wc -l
mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -P "${RDS_PORT:-3306}" oncokb -e "SELECT COUNT(*) AS gene_count FROM gene;"
mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -P "${RDS_PORT:-3306}" oncokb_transcript -e "SHOW TABLES;" | wc -l

unset MYSQL_PWD

# Clean up
echo ""
echo "Cleaning up..."
rm -f oncokb_v4_27.sql oncokb_transcript_v4_27.sql
cd /
rm -rf "${WORK_DIR}"

echo ""
echo "=== RDS Database Initialization Complete ==="
echo "Next: start/restart ECS services and test the API (e.g. curl ALB_DNS/api/v1/info)"
